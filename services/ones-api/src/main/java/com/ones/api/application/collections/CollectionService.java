package com.ones.api.application.collections;

import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.Map;
import java.util.Locale;
import java.util.stream.Collectors;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Autowired;

import com.ones.api.application.collections.ports.CollectionMembersRepository;
import com.ones.api.application.collections.ports.CollectionDeletionQueue;
import com.ones.api.application.collections.ports.CollectionsRepository;
import com.ones.api.application.invitations.email.InvitationActionTokenService;
import com.ones.api.application.invitations.email.InvitationEmailService;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.collections.Collection;
import com.ones.api.domain.collections.CollectionInvitation;
import com.ones.api.domain.collections.CollectionMember;
import com.ones.api.domain.collections.CollectionPolicy;
import com.ones.api.domain.collections.CollectionType;
import com.ones.api.domain.users.User;

public class CollectionService {
    private static final String LIFE_PURPOSE = "LIFE";

    private final CollectionsRepository repository;
    private final CollectionMembersRepository membersRepository;
    private final UsersRepository usersRepository;
    private final CollectionJoinTokenService joinTokenService;
    private final InvitationEmailService invitationEmailService;
    private final Clock clock;
    private CollectionDeletionQueue deletionQueue;

    public CollectionService(
            CollectionsRepository repository,
            CollectionMembersRepository membersRepository,
            UsersRepository usersRepository,
            CollectionJoinTokenService joinTokenService,
            InvitationEmailService invitationEmailService,
            Clock clock
    ) {
        this.repository = repository;
        this.membersRepository = membersRepository;
        this.usersRepository = usersRepository;
        this.joinTokenService = joinTokenService;
        this.invitationEmailService = invitationEmailService;
        this.clock = clock;
    }

    public Collection create(
            String ownerId,
            String name,
            String description,
            String type,
            String coverKey,
            List<String> inviteeEmails,
            String inviterName
    ) {
        CollectionType collectionType = CollectionType.from(type);
        List<String> invitees = normalizeEmails(inviteeEmails);
        if (collectionType == CollectionType.PRIVATE && !invitees.isEmpty()) {
            throw new IllegalArgumentException("Private collections cannot have invitees");
        }
        if (collectionType == CollectionType.COUPLE && invitees.size() != 1) {
            throw new IllegalArgumentException("A couple collection requires exactly one partner email");
        }
        if (invitees.size() > 50) throw new IllegalArgumentException("Invite at most 50 people per request");
        Instant now = Instant.now(clock);
        Collection created = repository.save(new Collection(
                UUID.randomUUID().toString(), ownerId, name.trim(), normalize(description),
                collectionType, normalize(coverKey), null, now, now,
                false, null, false, null
        ));
        if (!invitees.isEmpty()) invite(ownerId, inviterName, created.id(), invitees);
        return created;
    }

    public Collection ensureLife(String ownerId) {
        if (ownerId == null || ownerId.isBlank()) throw new IllegalArgumentException("Missing ownerId");
        String id = UUID.nameUUIDFromBytes(("ones:life:" + ownerId).getBytes(StandardCharsets.UTF_8)).toString();
        var existing = repository.findById(id);
        if (existing.isPresent()) return existing.get();

        User user = usersRepository.findById(ownerId).orElse(null);
        String preferredName = user == null ? null : user.getPreferredName();
        String name = preferredName == null || preferredName.isBlank()
                ? "Línea de Vida"
                : "Línea de Vida " + preferredName.trim();
        Instant now = Instant.now(clock);
        Collection life = new Collection(
                id, ownerId, name, null, CollectionType.PRIVATE, null, LIFE_PURPOSE,
                now, now, false, null, false, null
        );
        repository.saveIfAbsent(life);
        return repository.findById(id).orElse(life);
    }

    public List<Collection> list(String ownerId, int limit) {
        int pageSize = Math.min(Math.max(limit, 1), 100);
        LinkedHashSet<String> ids = new LinkedHashSet<>();
        List<Collection> owned = repository.listByOwnerId(ownerId, pageSize);
        owned.forEach(collection -> ids.add(collection.id()));
        membersRepository.listByUser(ownerId, pageSize).forEach(member -> ids.add(member.collectionId()));
        if (ids.isEmpty()) return List.of();
        Map<String, Collection> byId = repository.findByIds(new ArrayList<>(ids)).stream()
                .collect(Collectors.toMap(Collection::id, collection -> collection));
        return ids.stream().map(byId::get).filter(java.util.Objects::nonNull)
                .filter(collection -> !collection.deleting()).limit(pageSize).toList();
    }

    @Autowired(required = false)
    public void setDeletionQueue(CollectionDeletionQueue deletionQueue) {
        this.deletionQueue = deletionQueue;
    }

    public void delete(String requesterId, String collectionId) {
        Collection collection = repository.findById(collectionId)
                .orElseThrow(() -> new CollectionNotFoundException(collectionId));
        if (!collection.ownerId().equals(requesterId)) {
            throw new CollectionForbiddenException(collectionId);
        }
        if (collection.isLifeCollection()) {
            throw new CollectionConflictException("Life Collection cannot be deleted");
        }
        if (!repository.markDeleting(collectionId, requesterId)) {
            throw new CollectionConflictException("Collection deletion could not be started");
        }
        if (deletionQueue == null) {
            throw new IllegalStateException("Collection deletion queue is not configured");
        }
        deletionQueue.enqueue(collectionId);
    }

    public void finalizeDeletion(String collectionId) {
        Collection collection = repository.findById(collectionId)
                .filter(Collection::deleting)
                .orElse(null);
        if (collection == null) return;
        membersRepository.deleteByCollectionId(collectionId);
        repository.deleteById(collectionId);
    }

    public void ensureActiveForInternalWork(String collectionId) {
        repository.findById(collectionId)
                .filter(collection -> !collection.deleting())
                .orElseThrow(() -> new CollectionNotFoundException(collectionId));
    }

    public Collection get(String requesterId, String id) {
        Collection collection = repository.findById(id)
                .orElseThrow(() -> new CollectionNotFoundException(id));
        if (collection.deleting()) throw new CollectionNotFoundException(id);
        boolean isMember = membersRepository.find(id, userKey(requesterId))
                .map(CollectionMember::accepted)
                .orElse(false);
        if (!collection.ownerId().equals(requesterId) && !isMember) {
            throw new CollectionForbiddenException(id);
        }
        return collection;
    }

    public Collection update(String requesterId, String id, String name, String description, String coverKey) {
        Collection existing = get(requesterId, id);
        Collection updated = existing.update(name, description, normalize(coverKey), Instant.now(clock));
        return repository.save(updated);
    }

    public List<CollectionMember> invite(
            String requesterId,
            String inviterName,
            String collectionId,
            List<String> inviteeEmails
    ) {
        Collection collection = get(requesterId, collectionId);
        if (!CollectionPolicy.allowsMembers(collection.type())) {
            throw new IllegalArgumentException("Private collections cannot have invitees");
        }
        List<String> emails = normalizeEmails(inviteeEmails);
        if (emails.isEmpty() || emails.size() > 50) {
            throw new IllegalArgumentException("Provide between 1 and 50 invitee emails");
        }
        if (collection.type() == CollectionType.COUPLE && emails.size() != 1) {
            throw new IllegalArgumentException("A couple collection accepts one partner at a time");
        }

        List<CollectionMember> result = new ArrayList<>();
        for (String email : emails) {
            var previous = membersRepository.find(collectionId, emailKey(email));
            if (previous.isPresent() && previous.get().status() != CollectionMember.Status.REJECTED) {
                result.add(previous.get());
                continue;
            }
            previous.ifPresent(member -> membersRepository.remove(collection, member));
            Instant now = Instant.now(clock);
            CollectionMember pending = new CollectionMember(
                    collectionId, emailKey(email), null, email, CollectionMember.Status.PENDING,
                    requesterId, now, now
            );
            if (!membersRepository.add(collection, pending)) {
                var concurrentInvite = membersRepository.find(collectionId, emailKey(email));
                if (concurrentInvite.isPresent()
                        && concurrentInvite.get().status() != CollectionMember.Status.REJECTED) {
                    result.add(concurrentInvite.get());
                    continue;
                }
                throw new CollectionConflictException("Collection membership limit reached or invitation already exists");
            }
            invitationEmailService.sendCollectionInvitation(collectionId, collection.name(), email, inviterName);
            result.add(pending);
        }
        return List.copyOf(result);
    }

    public CollectionMembersRepository.PageResult<CollectionInvitation> listIncomingInvitations(
            String inviteeEmail,
            int limit,
            String nextToken
    ) {
        String email = normalizeEmail(inviteeEmail);
        if (email.isBlank()) {
            return new CollectionMembersRepository.PageResult<>(List.of(), null);
        }

        var page = membersRepository.pagePendingByInviteeEmail(email, limit, nextToken);
        List<String> collectionIds = page.items().stream()
                .map(CollectionMember::collectionId)
                .distinct()
                .toList();
        Map<String, Collection> collectionsById = repository.findByIds(collectionIds).stream()
                .filter(collection -> !collection.deleting())
                .collect(Collectors.toMap(Collection::id, collection -> collection));

        List<CollectionInvitation> invitations = page.items().stream()
                .filter(member -> member.status() == CollectionMember.Status.PENDING)
                .map(member -> collectionsById.get(member.collectionId()) == null
                        ? null
                        : new CollectionInvitation(
                                member.collectionId(),
                                collectionsById.get(member.collectionId()).name(),
                                member.invitedByUserId(),
                                member.createdAt()))
                .filter(java.util.Objects::nonNull)
                .toList();
        return new CollectionMembersRepository.PageResult<>(invitations, page.nextToken());
    }

    public CollectionMember respondToInvitation(
            String collectionId,
            String inviteeEmail,
            String userId,
            InvitationActionTokenService.Action action
    ) {
        String normalizedEmail = normalizeEmail(inviteeEmail);
        Collection collection = repository.findById(collectionId)
                .filter(c -> !c.deleting())
                .orElseThrow(() -> new CollectionNotFoundException(collectionId));
        CollectionMember pending = membersRepository.find(
                        collectionId, emailKey(normalizedEmail))
                .filter(member -> member.status() == CollectionMember.Status.PENDING)
                .orElseThrow(() -> new CollectionNotFoundException(collectionId));
        if (action == InvitationActionTokenService.Action.accept) {
            if (!membersRepository.acceptInvitation(collection, pending, userId, Instant.now(clock))) {
                throw new CollectionConflictException("Invitation has already been resolved");
            }
            return membersRepository.find(collectionId, userKey(userId))
                    .orElseThrow(() -> new CollectionConflictException("Membership could not be confirmed"));
        }

        CollectionMember rejected = new CollectionMember(
                pending.collectionId(), pending.memberKey(), null, pending.email(),
                CollectionMember.Status.REJECTED, pending.invitedByUserId(),
                pending.createdAt(), Instant.now(clock)
        );
        if (!membersRepository.transition(collection, pending, rejected)) {
            throw new CollectionConflictException("Invitation has already been resolved");
        }
        return rejected;
    }

    public List<CollectionMember> listMembers(String requesterId, String collectionId) {
        return listMembersPage(requesterId, collectionId, 200, null).items();
    }

    public CollectionMembersRepository.PageResult<CollectionMember> listMembersPage(
            String requesterId,
            String collectionId,
            int limit,
            String nextToken
    ) {
        get(requesterId, collectionId);
        var page = membersRepository.pageByCollection(collectionId, limit, nextToken);
        return new CollectionMembersRepository.PageResult<>(
                page.items().stream()
                .filter(member -> member.status() != CollectionMember.Status.REJECTED)
                .toList(),
                page.nextToken()
        );
    }

    public void leave(String requesterId, String collectionId) {
        Collection collection = get(requesterId, collectionId);
        if (collection.ownerId().equals(requesterId)) {
            throw new CollectionConflictException("The owner must transfer ownership or delete the collection before leaving");
        }
        CollectionMember member = membersRepository.find(collectionId, userKey(requesterId))
                .filter(CollectionMember::accepted)
                .orElseThrow(() -> new CollectionNotFoundException(collectionId));
        membersRepository.remove(collection, member);
    }

    public void removeMember(String requesterId, String collectionId, String memberKey) {
        Collection collection = get(requesterId, collectionId);
        if (!collection.ownerId().equals(requesterId)) {
            throw new CollectionForbiddenException(collectionId);
        }
        CollectionMember member = membersRepository.find(collectionId, memberKey)
                .orElseThrow(() -> new CollectionNotFoundException(collectionId));
        if (requesterId.equals(member.userId())) {
            throw new CollectionConflictException("The owner cannot remove themselves");
        }
        membersRepository.remove(collection, member);
    }

    public void transferOwnership(String requesterId, String collectionId, String newOwnerId) {
        Collection collection = get(requesterId, collectionId);
        if (!collection.ownerId().equals(requesterId)) {
            throw new CollectionForbiddenException(collectionId);
        }
        if (collection.isLifeCollection()) {
            throw new CollectionConflictException("Life Collection ownership cannot be transferred");
        }
        if (requesterId.equals(newOwnerId)) return;
        membersRepository.find(collectionId, userKey(newOwnerId))
                .filter(CollectionMember::accepted)
                .orElseThrow(() -> new CollectionConflictException("The new owner must be an accepted member"));
        Instant now = Instant.now(clock);
        CollectionMember formerOwner = new CollectionMember(
                collectionId, userKey(requesterId), requesterId, null,
                CollectionMember.Status.ACCEPTED, requesterId, now, now
        );
        if (!membersRepository.transferOwnership(collection, newOwnerId, formerOwner)) {
            throw new CollectionConflictException("Ownership changed concurrently");
        }
    }

    public String rotateJoinQr(String requesterId, String collectionId) {
        Collection collection = get(requesterId, collectionId);
        if (!CollectionPolicy.allowsQrJoin(collection.type()) || collection.isLifeCollection()) {
            throw new IllegalArgumentException("This collection cannot be joined by QR");
        }
        String token = joinTokenService.create();
        repository.save(collection.withJoinQr(true, joinTokenService.hash(token), Instant.now(clock)));
        return token;
    }

    public String setJoinQrEnabled(String requesterId, String collectionId, boolean enabled) {
        if (enabled) {
            return rotateJoinQr(requesterId, collectionId);
        }
        Collection collection = get(requesterId, collectionId);
        repository.save(collection.withJoinQr(false, null, Instant.now(clock)));
        return null;
    }

    public Collection joinByQr(String userId, String email, String collectionId, String token) {
        Collection collection = repository.findById(collectionId)
                .filter(c -> !c.deleting())
                .orElseThrow(() -> new CollectionNotFoundException(collectionId));
        if (!collection.joinEnabled() || !CollectionPolicy.allowsQrJoin(collection.type())
                || !joinTokenService.matches(collection.joinTokenHash(), token)) {
            throw new CollectionNotFoundException(collectionId);
        }
        var existing = membersRepository.find(collectionId, userKey(userId));
        if (existing.filter(CollectionMember::accepted).isPresent()) return collection;
        var pending = membersRepository.find(collectionId, emailKey(email))
                .filter(member -> member.status() == CollectionMember.Status.PENDING);
        if (pending.isPresent()) {
            if (!membersRepository.acceptInvitation(collection, pending.get(), userId, Instant.now(clock))) {
                throw new CollectionConflictException("Collection membership limit reached");
            }
            return collection;
        }

        Instant now = Instant.now(clock);
        CollectionMember member = new CollectionMember(
                collectionId, userKey(userId), userId, email, CollectionMember.Status.ACCEPTED,
                null, now, now
        );
        if (!membersRepository.add(collection, member)) {
            if (membersRepository.find(collectionId, userKey(userId))
                    .filter(CollectionMember::accepted).isPresent()) return collection;
            throw new CollectionConflictException("Collection membership limit reached");
        }
        return collection;
    }

    private static String normalize(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    private static String normalizeEmail(String email) {
        return email == null ? "" : email.trim().toLowerCase(Locale.ROOT);
    }

    private static List<String> normalizeEmails(List<String> values) {
        if (values == null) return List.of();
        return values.stream().filter(value -> value != null && !value.isBlank())
                .map(value -> value.trim().toLowerCase(java.util.Locale.ROOT))
                .distinct().toList();
    }

    private static String emailKey(String email) { return "EMAIL#" + email; }
    private static String userKey(String userId) { return "USER#" + userId; }
}
