package com.ones.api.application.photos;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.ones.api.application.events.GetEventUseCase;
import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.application.events.ports.ObjectStorage;
import com.ones.api.application.events.ports.ObjectStoragePresigner;
import com.ones.api.application.photos.ports.PhotosRepository;
import com.ones.api.application.photos.ports.PhotoLikesRepository;
import com.ones.api.application.users.ports.PreferredNamesCacheRepository;
import com.ones.api.application.users.GetUserByIdUseCase;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.invitations.Invitation;
import com.ones.api.domain.photos.Photo;
import com.ones.api.domain.users.User;

@Service
public class PhotosService {

    private static final Logger log = LoggerFactory.getLogger(PhotosService.class);

    private final PhotosRepository photosRepository;
    private final PhotoLikesRepository photoLikesRepository;
    private final GetEventUseCase getEventUseCase;
    private final EventsRepository eventsRepository;
    private final com.ones.api.application.invitations.ports.InvitationsRepository invitationsRepository;
    private final GetUserByIdUseCase getUserByIdUseCase;
    private final PreferredNamesCacheRepository preferredNamesCacheRepository;
    private final ObjectStoragePresigner objectStoragePresigner;
    private final ObjectStorage objectStorage;
    private final CloudFrontSignedUrlService cloudFrontSignedUrlService;
    private final ShortPhotoShareLinkService shortPhotoShareLinkService;
    private final Clock clock;

    private final String photosBucket;
    private final long putPresignTtlMinutes;
    private final boolean debugList;

    public PhotosService(
            PhotosRepository photosRepository,
            PhotoLikesRepository photoLikesRepository,
            GetEventUseCase getEventUseCase,
            EventsRepository eventsRepository,
            com.ones.api.application.invitations.ports.InvitationsRepository invitationsRepository,
            GetUserByIdUseCase getUserByIdUseCase,
            PreferredNamesCacheRepository preferredNamesCacheRepository,
            ObjectStoragePresigner objectStoragePresigner,
            ObjectStorage objectStorage,
            CloudFrontSignedUrlService cloudFrontSignedUrlService,
            ShortPhotoShareLinkService shortPhotoShareLinkService,
            Clock clock,
            @Value("${ones.s3.events.photos.bucket}") String photosBucket,
            @Value("${ones.s3.events.photos.put-presign-ttl-minutes:15}") long putPresignTtlMinutes,
            @Value("${ones.photos.debug-list:false}") boolean debugList
    ) {
        this.photosRepository = photosRepository;
        this.photoLikesRepository = photoLikesRepository;
        this.getEventUseCase = getEventUseCase;
        this.eventsRepository = eventsRepository;
        this.invitationsRepository = invitationsRepository;
        this.getUserByIdUseCase = getUserByIdUseCase;
        this.preferredNamesCacheRepository = preferredNamesCacheRepository;
        this.objectStoragePresigner = objectStoragePresigner;
        this.objectStorage = objectStorage;
        this.cloudFrontSignedUrlService = cloudFrontSignedUrlService;
        this.shortPhotoShareLinkService = shortPhotoShareLinkService;
        this.clock = clock;
        this.photosBucket = photosBucket;
        this.putPresignTtlMinutes = putPresignTtlMinutes;
        this.debugList = debugList;
    }

    public PresignPutResult presignPut(
            String requesterUserId,
            String requesterEmail,
            String eventId,
            String photoId,
            String contentType
    ) {
        require(eventId, "eventId");
        require(photoId, "photoId");

        Event event = getEventUseCase.execute(requesterUserId, requesterEmail, eventId);

        String guestId = requesterUserId;
        String key = originalKey(event.getEventId(), guestId, photoId);

        Instant now = Instant.now(clock);
        Instant expiresAt = now.plus(Duration.ofMinutes(putPresignTtlMinutes));

        String resolvedContentType = (contentType == null || contentType.isBlank()) ? "image/jpeg" : contentType.trim();

        String putUrl = objectStoragePresigner
                .presignPut(photosBucket, key, Duration.ofMinutes(putPresignTtlMinutes), resolvedContentType)
                .toString();

        return new PresignPutResult(photoId, putUrl, key, expiresAt);
    }

    public Photo complete(
            String requesterUserId,
            String requesterEmail,
            String eventId,
            String photoId,
            Instant createdAt,
            String s3KeyOriginal
    ) {
        require(eventId, "eventId");
        require(photoId, "photoId");
        require(s3KeyOriginal, "s3KeyOriginal");

        Event event = getEventUseCase.execute(requesterUserId, requesterEmail, eventId);

        Instant now = Instant.now(clock);
        Instant resolvedCreatedAt = createdAt != null ? createdAt : now;

        String ownerName = resolvePreferredName(requesterUserId, requesterEmail);

        Photo photo = new Photo(
                photoId,
                event.getEventId(),
                requesterUserId,
                resolvedCreatedAt,
                now,
                "uploaded",
                s3KeyOriginal,
                null,
                null,
                ownerName,
                null,
                null
        );

        return photosRepository.upsert(photo);
    }

    public ListPage list(
            String requesterUserId,
            String requesterEmail,
            String eventId,
            int limit,
            String nextToken,
            String scope
    ) {
        return list(requesterUserId, requesterEmail, eventId, limit, nextToken, scope, null, null);
    }

    public ListPage list(
            String requesterUserId,
            String requesterEmail,
            String eventId,
            int limit,
            String nextToken,
            String scope,
            String filter,
            List<String> guestIds
    ) {
        require(eventId, "eventId");

        Event event = getEventUseCase.execute(requesterUserId, requesterEmail, eventId);

        String resolvedFilter = filter != null ? filter.trim().toLowerCase() : "";
        List<String> normalizedGuestIds = normalizeGuestIds(guestIds);

        boolean useV2 = !resolvedFilter.isBlank() || !normalizedGuestIds.isEmpty();

        if (useV2) {
            validateGuestIdsAreParticipants(event, normalizedGuestIds);
            return listV2(requesterUserId, requesterEmail, eventId, limit, nextToken, resolvedFilter, normalizedGuestIds);
        }

        String resolvedScope = scope != null ? scope.trim().toLowerCase() : "";

        int resolvedLimit = limit <= 0 ? 9 : Math.min(limit, 50);

        boolean guestOnly = "guest".equals(resolvedScope);
        boolean sharedOnly = "shared".equals(resolvedScope);

        List<ListItem> out = new ArrayList<>(resolvedLimit);
        String cursor = nextToken;
        String outNextToken = null;

        while (out.size() < resolvedLimit) {
            int remaining = resolvedLimit - out.size();
            PhotosRepository.PageResult<Photo> page = photosRepository.listByEventId(eventId, remaining, cursor);

            Set<String> nameUserIds = new HashSet<>();
            List<Photo> selected = new ArrayList<>(remaining);

            for (Photo p : page.items()) {
                boolean isShared = isShared(p);

                if (!isShared && (p.getGuestId() == null || !p.getGuestId().equals(requesterUserId))) {
                    continue;
                }

                if (sharedOnly && !isShared) {
                    continue;
                }

                if (guestOnly) {
                    if (p.getGuestId() == null || !p.getGuestId().equals(requesterUserId)) {
                        continue;
                    }
                    if (isShared) {
                        continue;
                    }
                }

                if (p.getGuestId() != null && !p.getGuestId().isBlank()) {
                    nameUserIds.add(p.getGuestId().trim());
                }
                if (p.getSharedByUserId() != null && !p.getSharedByUserId().isBlank()) {
                    nameUserIds.add(p.getSharedByUserId().trim());
                }

                selected.add(p);

                if (selected.size() >= remaining) break;
            }

            if (!selected.isEmpty()) {
                Map<String, String> resolvedNames = resolvePreferredNames(nameUserIds);
                Set<String> selectedPhotoIds = new HashSet<>();
                for (Photo p : selected) {
                    if (p != null && p.getPhotoId() != null && !p.getPhotoId().isBlank()) {
                        selectedPhotoIds.add(p.getPhotoId().trim());
                    }
                }
                Set<String> likedByMe = photoLikesRepository.likedPhotoIds(requesterUserId, selectedPhotoIds);
                for (Photo p : selected) {
                    boolean isShared = isShared(p);

                    String originalKey = p.getS3KeyOriginal();
                    if ((originalKey == null || originalKey.isBlank())
                            && p.getEventId() != null && !p.getEventId().isBlank()
                            && p.getGuestId() != null && !p.getGuestId().isBlank()
                            && p.getPhotoId() != null && !p.getPhotoId().isBlank()
                            && !isShared) {
                        originalKey = originalKey(p.getEventId(), p.getGuestId(), p.getPhotoId());
                    }

                    String mediumKey = p.getS3KeyMedium();
                    if ((mediumKey == null || mediumKey.isBlank()) && originalKey != null && !originalKey.isBlank()) {
                        mediumKey = variantKeyFromOriginal(originalKey, "_m");
                    }

                    String smallKey = p.getS3KeySmall();
                    if ((smallKey == null || smallKey.isBlank()) && originalKey != null && !originalKey.isBlank()) {
                        smallKey = variantKeyFromOriginal(originalKey, "_s");
                    }

                    String status = p.getStatus() != null ? p.getStatus().trim().toLowerCase() : "";
                    boolean isReady = "ready".equals(status);

                    String originalUrl = signedCdnUrlIfAny(originalKey);
                    String mediumUrl = isReady ? signedCdnUrlIfAny(mediumKey) : null;
                    String smallUrl = isReady ? signedCdnUrlIfAny(smallKey) : null;

                    if (debugList) {
                        log.info(
                                "[PhotosService.list] eventId={} scope={} requesterUserId={} photoId={} guestId={} shared={} status={} originalKey={} smallKey={} mediumKey={} smallUrl={} mediumUrl={}",
                                eventId,
                                resolvedScope,
                                requesterUserId,
                                p.getPhotoId(),
                                p.getGuestId(),
                                isShared,
                                p.getStatus(),
                                originalKey,
                                smallKey,
                                mediumKey,
                                (smallUrl != null && !smallUrl.isBlank()),
                                (mediumUrl != null && !mediumUrl.isBlank())
                        );
                    }

                    String ownerName = resolvedNames.get(p.getGuestId());
                    if (ownerName == null || ownerName.isBlank()) {
                        ownerName = p.getOwnerName();
                    }

                    String sharedByName = resolvedNames.get(p.getSharedByUserId());
                    if (sharedByName == null || sharedByName.isBlank()) {
                        sharedByName = p.getSharedByName();
                    }

                    out.add(new ListItem(
                            p.getPhotoId(),
                            p.getGuestId(),
                            p.getCreatedAt(),
                            p.getUploadedAt(),
                            p.getStatus(),
                            originalUrl,
                            mediumUrl,
                            smallUrl,
                            isShared,
                            ownerName,
                            p.getSharedByUserId(),
                            sharedByName,
                            likedByMe.contains(p.getPhotoId() != null ? p.getPhotoId().trim() : "")
                    ));
                }
            }

            if (page.nextToken() == null || page.nextToken().isBlank()) {
                outNextToken = null;
                break;
            }

            cursor = page.nextToken();
            outNextToken = cursor;
        }

        return new ListPage(out, outNextToken);
    }

    private ListPage listV2(
            String requesterUserId,
            String requesterEmail,
            String eventId,
            int limit,
            String nextToken,
            String filter,
            List<String> guestIds
    ) {
        String resolvedFilter = filter != null ? filter.trim().toLowerCase() : "";

        Set<String> guestIdSet = guestIds != null && !guestIds.isEmpty() ? new HashSet<>(guestIds) : Set.of();

        int resolvedLimit = limit <= 0 ? 9 : Math.min(limit, 50);

        boolean mineOnly = "mine".equals(resolvedFilter);
        boolean sharedByMeOnly = "shared_by_me".equals(resolvedFilter);

        List<ListItem> out = new ArrayList<>(resolvedLimit);
        String cursor = nextToken;
        String outNextToken = null;

        while (out.size() < resolvedLimit) {
            int remaining = resolvedLimit - out.size();
            PhotosRepository.PageResult<Photo> page = photosRepository.listByEventId(eventId, remaining, cursor);

            Set<String> nameUserIds = new HashSet<>();
            List<Photo> selected = new ArrayList<>(remaining);

            for (Photo p : page.items()) {
                boolean isShared = isShared(p);

                if (!isShared && (p.getGuestId() == null || !p.getGuestId().equals(requesterUserId))) {
                    continue;
                }

                if (mineOnly) {
                    if (p.getGuestId() == null || !p.getGuestId().equals(requesterUserId)) {
                        continue;
                    }
                }

                if (sharedByMeOnly) {
                    if (p.getSharedByUserId() == null || !p.getSharedByUserId().equals(requesterUserId)) {
                        continue;
                    }
                }

                if (!mineOnly && !sharedByMeOnly && !guestIds.isEmpty()) {
                    String gid = p.getGuestId();
                    if (gid == null || gid.isBlank() || !guestIdSet.contains(gid)) {
                        continue;
                    }
                }

                if (p.getGuestId() != null && !p.getGuestId().isBlank()) {
                    nameUserIds.add(p.getGuestId().trim());
                }
                if (p.getSharedByUserId() != null && !p.getSharedByUserId().isBlank()) {
                    nameUserIds.add(p.getSharedByUserId().trim());
                }

                selected.add(p);
                if (selected.size() >= remaining) break;
            }

            if (!selected.isEmpty()) {
                Map<String, String> resolvedNames = resolvePreferredNames(nameUserIds);
                Set<String> selectedPhotoIds = new HashSet<>();
                for (Photo p : selected) {
                    if (p != null && p.getPhotoId() != null && !p.getPhotoId().isBlank()) {
                        selectedPhotoIds.add(p.getPhotoId().trim());
                    }
                }
                Set<String> likedByMe = photoLikesRepository.likedPhotoIds(requesterUserId, selectedPhotoIds);
                for (Photo p : selected) {
                    boolean isShared = isShared(p);

                    String originalKey = p.getS3KeyOriginal();
                    if ((originalKey == null || originalKey.isBlank())
                            && p.getEventId() != null && !p.getEventId().isBlank()
                            && p.getGuestId() != null && !p.getGuestId().isBlank()
                            && p.getPhotoId() != null && !p.getPhotoId().isBlank()
                            && !isShared) {
                        originalKey = originalKey(p.getEventId(), p.getGuestId(), p.getPhotoId());
                    }

                    String mediumKey = p.getS3KeyMedium();
                    if ((mediumKey == null || mediumKey.isBlank()) && originalKey != null && !originalKey.isBlank()) {
                        mediumKey = variantKeyFromOriginal(originalKey, "_m");
                    }

                    String smallKey = p.getS3KeySmall();
                    if ((smallKey == null || smallKey.isBlank()) && originalKey != null && !originalKey.isBlank()) {
                        smallKey = variantKeyFromOriginal(originalKey, "_s");
                    }

                    String status = p.getStatus() != null ? p.getStatus().trim().toLowerCase() : "";
                    boolean isReady = "ready".equals(status);

                    String originalUrl = signedCdnUrlIfAny(originalKey);
                    String mediumUrl = isReady ? signedCdnUrlIfAny(mediumKey) : null;
                    String smallUrl = isReady ? signedCdnUrlIfAny(smallKey) : null;

                    if (debugList) {
                        log.info(
                                "[PhotosService.listV2] eventId={} filter={} requesterUserId={} guestIdsCount={} photoId={} guestId={} shared={} status={} originalKey={} smallKey={} mediumKey={} smallUrl={} mediumUrl={}",
                                eventId,
                                resolvedFilter,
                                requesterUserId,
                                guestIds.size(),
                                p.getPhotoId(),
                                p.getGuestId(),
                                isShared,
                                p.getStatus(),
                                originalKey,
                                smallKey,
                                mediumKey,
                                (smallUrl != null && !smallUrl.isBlank()),
                                (mediumUrl != null && !mediumUrl.isBlank())
                        );
                    }

                    String ownerName = resolvedNames.get(p.getGuestId());
                    if (ownerName == null || ownerName.isBlank()) {
                        ownerName = p.getOwnerName();
                    }

                    String sharedByName = resolvedNames.get(p.getSharedByUserId());
                    if (sharedByName == null || sharedByName.isBlank()) {
                        sharedByName = p.getSharedByName();
                    }

                    out.add(new ListItem(
                            p.getPhotoId(),
                            p.getGuestId(),
                            p.getCreatedAt(),
                            p.getUploadedAt(),
                            p.getStatus(),
                            originalUrl,
                            mediumUrl,
                            smallUrl,
                            isShared,
                            ownerName,
                            p.getSharedByUserId(),
                            sharedByName,
                            likedByMe.contains(p.getPhotoId() != null ? p.getPhotoId().trim() : "")
                    ));
                }
            }

            if (page.nextToken() == null || page.nextToken().isBlank()) {
                outNextToken = null;
                break;
            }

            cursor = page.nextToken();
            outNextToken = cursor;
        }

        return new ListPage(out, outNextToken);
    }

    private static List<String> normalizeGuestIds(List<String> guestIds) {
        if (guestIds == null || guestIds.isEmpty()) {
            return List.of();
        }
        List<String> out = new ArrayList<>();
        Set<String> seen = new HashSet<>();
        for (String raw : guestIds) {
            if (raw == null) continue;
            String normalized = raw.trim();
            if (normalized.isBlank()) continue;

            // support both multi-value (?guestIds=u1&guestIds=u2) and comma-separated (?guestIds=u1,u2)
            String[] parts = normalized.split(",");
            for (String part : parts) {
                String v = part != null ? part.trim() : "";
                if (v.isBlank()) continue;
                if (seen.add(v)) {
                    out.add(v);
                }
            }
        }
        return out;
    }

    private void validateGuestIdsAreParticipants(Event event, List<String> guestIds) {
        if (guestIds == null || guestIds.isEmpty()) {
            return;
        }

        String ownerId = event.getOwnerId();
        Set<String> allowed = new HashSet<>();
        if (ownerId != null && !ownerId.isBlank()) {
            allowed.add(ownerId);
        }

        // Best-effort: repository supports limit but not pagination. For MVP, we cap.
        List<Invitation> invs = invitationsRepository.listByEventId(event.getEventId(), 500);
        for (Invitation inv : invs) {
            if (inv.getStatus() == Invitation.Status.accepted
                    && inv.getInviteeUserId() != null
                    && !inv.getInviteeUserId().isBlank()) {
                allowed.add(inv.getInviteeUserId().trim());
            }
        }

        for (String guestId : guestIds) {
            if (!allowed.contains(guestId)) {
                throw new IllegalArgumentException("Invalid guestId for event: " + guestId);
            }
        }
    }

    public List<Photo> sharePhotos(
            String requesterUserId,
            String requesterEmail,
            String eventId,
            List<String> photoIds
    ) {
        require(eventId, "eventId");
        getEventUseCase.execute(requesterUserId, requesterEmail, eventId);

        if (photoIds == null || photoIds.isEmpty()) {
            return List.of();
        }

        String sharedByName = resolvePreferredName(requesterUserId, requesterEmail);

        List<Photo> updated = new ArrayList<>(photoIds.size());
        for (String rawId : photoIds) {
            if (rawId == null || rawId.isBlank()) {
                continue;
            }
            String photoId = rawId.trim();

            Photo existing = photosRepository.findById(photoId).orElse(null);
            if (existing == null) {
                continue;
            }

            if (existing.getEventId() == null || !existing.getEventId().equals(eventId)) {
                continue;
            }

            Event event = eventsRepository.findById(eventId.trim()).orElse(null);
            if (event == null) {
                continue;
            }

            boolean isOwner = requesterUserId != null && requesterUserId.equals(event.getOwnerId());
            boolean isPhotoOwner = requesterUserId != null && requesterUserId.equals(existing.getGuestId());
            if (!isOwner && !isPhotoOwner) {
                continue;
            }

            if (isShared(existing)) {
                String ownerName = existing.getOwnerName();
                if (ownerName == null || ownerName.isBlank()) {
                    ownerName = resolvePreferredName(existing.getGuestId(), null);
                }

                String nextSharedByUserId = existing.getSharedByUserId();
                if (nextSharedByUserId == null || nextSharedByUserId.isBlank()) {
                    nextSharedByUserId = requesterUserId;
                }

                String nextSharedByName = existing.getSharedByName();
                if (nextSharedByName == null || nextSharedByName.isBlank()) {
                    nextSharedByName = sharedByName;
                }

                boolean needsBackfill = (existing.getOwnerName() == null || existing.getOwnerName().isBlank())
                        || (existing.getSharedByUserId() == null || existing.getSharedByUserId().isBlank())
                        || (existing.getSharedByName() == null || existing.getSharedByName().isBlank());

                if (!needsBackfill) {
                    updated.add(existing);
                    continue;
                }

                Photo next = new Photo(
                        existing.getPhotoId(),
                        existing.getEventId(),
                        existing.getGuestId(),
                        existing.getCreatedAt(),
                        existing.getUploadedAt(),
                        existing.getStatus(),
                        existing.getS3KeyOriginal(),
                        existing.getS3KeyMedium(),
                        existing.getS3KeySmall(),
                        ownerName,
                        nextSharedByUserId,
                        nextSharedByName
                );

                updated.add(photosRepository.upsert(next));
                continue;
            }

            String ownerName = existing.getOwnerName();
            if (ownerName == null || ownerName.isBlank()) {
                ownerName = resolvePreferredName(existing.getGuestId(), null);
            }

            String nextOriginal = sharedKey(eventId, photoId, "");
            String nextMedium = sharedKey(eventId, photoId, "_m");
            String nextSmall = sharedKey(eventId, photoId, "_s");

            String sourceOriginal = existing.getS3KeyOriginal();
            String sourceMedium = existing.getS3KeyMedium();
            String sourceSmall = existing.getS3KeySmall();

            if ((sourceMedium == null || sourceMedium.isBlank()) && sourceOriginal != null && !sourceOriginal.isBlank()) {
                sourceMedium = variantKeyFromOriginal(sourceOriginal, "_m");
            }
            if ((sourceSmall == null || sourceSmall.isBlank()) && sourceOriginal != null && !sourceOriginal.isBlank()) {
                sourceSmall = variantKeyFromOriginal(sourceOriginal, "_s");
            }

            moveIfPresent(sourceOriginal, nextOriginal);
            moveIfPresent(sourceMedium, nextMedium);
            moveIfPresent(sourceSmall, nextSmall);

            Photo next = new Photo(
                    existing.getPhotoId(),
                    existing.getEventId(),
                    existing.getGuestId(),
                    existing.getCreatedAt(),
                    existing.getUploadedAt(),
                    existing.getStatus(),
                    nextOriginal,
                    nextMedium,
                    nextSmall,
                    ownerName,
                    requesterUserId,
                    sharedByName
            );

            updated.add(photosRepository.upsert(next));
        }

        return updated;
    }

    public List<Photo> unsharePhotos(
            String requesterUserId,
            String requesterEmail,
            String eventId,
            List<String> photoIds
    ) {
        require(eventId, "eventId");
        getEventUseCase.execute(requesterUserId, requesterEmail, eventId);

        if (photoIds == null || photoIds.isEmpty()) {
            return List.of();
        }

        List<Photo> updated = new ArrayList<>(photoIds.size());
        for (String rawId : photoIds) {
            if (rawId == null || rawId.isBlank()) {
                continue;
            }
            String photoId = rawId.trim();

            Photo existing = photosRepository.findById(photoId).orElse(null);
            if (existing == null) {
                continue;
            }

            if (existing.getEventId() == null || !existing.getEventId().equals(eventId)) {
                continue;
            }

            Event event = eventsRepository.findById(eventId.trim()).orElse(null);
            if (event == null) {
                continue;
            }

            boolean isOwner = requesterUserId != null && requesterUserId.equals(event.getOwnerId());
            boolean isPhotoOwner = requesterUserId != null && requesterUserId.equals(existing.getGuestId());
            if (!isOwner && !isPhotoOwner) {
                continue;
            }

            if (!isShared(existing)) {
                if (existing.getSharedByUserId() != null || existing.getSharedByName() != null) {
                    Photo next = new Photo(
                            existing.getPhotoId(),
                            existing.getEventId(),
                            existing.getGuestId(),
                            existing.getCreatedAt(),
                            existing.getUploadedAt(),
                            existing.getStatus(),
                            existing.getS3KeyOriginal(),
                            existing.getS3KeyMedium(),
                            existing.getS3KeySmall(),
                            existing.getOwnerName(),
                            null,
                            null
                    );
                    updated.add(photosRepository.upsert(next));
                } else {
                    updated.add(existing);
                }
                continue;
            }

            String guestId = existing.getGuestId();
            if (guestId == null || guestId.isBlank()) {
                continue;
            }

            String ownerName = existing.getOwnerName();
            if (ownerName == null || ownerName.isBlank()) {
                ownerName = resolvePreferredName(guestId, null);
            }

            String destOriginal = originalKey(eventId, guestId, photoId);
            String destMedium = variantKeyFromOriginal(destOriginal, "_m");
            String destSmall = variantKeyFromOriginal(destOriginal, "_s");

            String sourceOriginal = existing.getS3KeyOriginal();
            String sourceMedium = existing.getS3KeyMedium();
            String sourceSmall = existing.getS3KeySmall();

            if ((sourceOriginal == null || sourceOriginal.isBlank()) || !isSharedKey(sourceOriginal)) {
                sourceOriginal = sharedKey(eventId, photoId, "");
            }
            if ((sourceMedium == null || sourceMedium.isBlank()) || !isSharedKey(sourceMedium)) {
                sourceMedium = sharedKey(eventId, photoId, "_m");
            }
            if ((sourceSmall == null || sourceSmall.isBlank()) || !isSharedKey(sourceSmall)) {
                sourceSmall = sharedKey(eventId, photoId, "_s");
            }

            moveIfPresent(sourceOriginal, destOriginal);
            moveIfPresent(sourceMedium, destMedium);
            moveIfPresent(sourceSmall, destSmall);

            Photo next = new Photo(
                    existing.getPhotoId(),
                    existing.getEventId(),
                    existing.getGuestId(),
                    existing.getCreatedAt(),
                    existing.getUploadedAt(),
                    existing.getStatus(),
                    destOriginal,
                    destMedium,
                    destSmall,
                    ownerName,
                    null,
                    null
            );

            updated.add(photosRepository.upsert(next));
        }

        return updated;
    }

    public Photo markReady(
            String requesterUserId,
            String requesterEmail,
            String eventId,
            String photoId,
            String s3KeyMedium,
            String s3KeySmall
    ) {
        require(eventId, "eventId");
        require(photoId, "photoId");

        getEventUseCase.execute(requesterUserId, requesterEmail, eventId);

        Photo existing = photosRepository.findById(photoId).orElse(null);
        if (existing == null) {
            Instant now = Instant.now(clock);
            String ownerName = resolvePreferredName(requesterUserId, requesterEmail);
            Photo created = new Photo(
                    photoId,
                    eventId,
                    requesterUserId,
                    now,
                    now,
                    "ready",
                    null,
                    s3KeyMedium,
                    s3KeySmall,
                    ownerName,
                    null,
                    null
            );
            return photosRepository.upsert(created);
        }

        String ownerName = existing.getOwnerName();
        if (ownerName == null || ownerName.isBlank()) {
            ownerName = resolvePreferredName(existing.getGuestId(), null);
        }

        Photo updated = new Photo(
                existing.getPhotoId(),
                existing.getEventId(),
                existing.getGuestId(),
                existing.getCreatedAt(),
                existing.getUploadedAt(),
                "ready",
                existing.getS3KeyOriginal(),
                s3KeyMedium != null && !s3KeyMedium.isBlank() ? s3KeyMedium.trim() : existing.getS3KeyMedium(),
                s3KeySmall != null && !s3KeySmall.isBlank() ? s3KeySmall.trim() : existing.getS3KeySmall(),
                ownerName,
                existing.getSharedByUserId(),
                existing.getSharedByName()
        );

        return photosRepository.upsert(updated);
    }

    public SocialShareLink createSocialShareLink(
            String requesterUserId,
            String requesterEmail,
            String eventId,
            String photoId,
            String variant
    ) {
        require(eventId, "eventId");
        require(photoId, "photoId");

        getEventUseCase.execute(requesterUserId, requesterEmail, eventId);

        Photo p = photosRepository.findById(photoId.trim()).orElse(null);
        if (p == null || p.getEventId() == null || !p.getEventId().equals(eventId)) {
            throw new IllegalArgumentException("Missing photo");
        }

        String originalKey = p.getS3KeyOriginal();
        if ((originalKey == null || originalKey.isBlank())
                && p.getEventId() != null && !p.getEventId().isBlank()
                && p.getGuestId() != null && !p.getGuestId().isBlank()
                && p.getPhotoId() != null && !p.getPhotoId().isBlank()
                && !isShared(p)) {
            originalKey = originalKey(p.getEventId(), p.getGuestId(), p.getPhotoId());
        }

        String mediumKey = p.getS3KeyMedium();
        if ((mediumKey == null || mediumKey.isBlank()) && originalKey != null && !originalKey.isBlank()) {
            mediumKey = variantKeyFromOriginal(originalKey, "_m");
        }

        String smallKey = p.getS3KeySmall();
        if ((smallKey == null || smallKey.isBlank()) && originalKey != null && !originalKey.isBlank()) {
            smallKey = variantKeyFromOriginal(originalKey, "_s");
        }

        String resolvedVariant = (variant == null || variant.isBlank()) ? "medium" : variant.trim().toLowerCase();
        String key = switch (resolvedVariant) {
            case "small" -> smallKey;
            case "original" -> originalKey;
            case "medium" -> mediumKey;
            default -> mediumKey;
        };

        // Persist a shortlink and return app-domain URL for sharing.
        // The viewer will load the photo via APIs, so we don't expose long signed URLs.
        ShortPhotoShareLinkService.SocialShareLink res = shortPhotoShareLinkService.create(eventId, photoId, resolvedVariant);
        return new SocialShareLink(res.url(), res.expiresAt());
    }

    public Photo markReadyInternal(String eventId, String photoId, String s3KeyMedium, String s3KeySmall) {
        require(eventId, "eventId");
        require(photoId, "photoId");

        Event event = eventsRepository.findById(eventId.trim()).orElse(null);
        if (event == null) {
            throw new IllegalArgumentException("Missing event");
        }

        Photo existing = photosRepository.findById(photoId).orElse(null);
        Instant now = Instant.now(clock);

        if (existing == null) {
            Photo created = new Photo(
                    photoId,
                    event.getEventId(),
                    "internal",
                    now,
                    now,
                    "ready",
                    null,
                    s3KeyMedium,
                    s3KeySmall,
                    null,
                    null,
                    null
            );
            return photosRepository.upsert(created);
        }

        String ownerName = existing.getOwnerName();
        if (ownerName == null || ownerName.isBlank()) {
            ownerName = resolvePreferredName(existing.getGuestId(), null);
        }

        Photo updated = new Photo(
                existing.getPhotoId(),
                existing.getEventId(),
                existing.getGuestId(),
                existing.getCreatedAt(),
                existing.getUploadedAt(),
                "ready",
                existing.getS3KeyOriginal(),
                s3KeyMedium != null && !s3KeyMedium.isBlank() ? s3KeyMedium.trim() : existing.getS3KeyMedium(),
                s3KeySmall != null && !s3KeySmall.isBlank() ? s3KeySmall.trim() : existing.getS3KeySmall(),
                ownerName,
                existing.getSharedByUserId(),
                existing.getSharedByName()
        );

        return photosRepository.upsert(updated);
    }

    private String signedCdnUrlIfAny(String key) {
        if (key == null || key.isBlank()) {
            return null;
        }
        CloudFrontSignedUrlService.SignedUrlResult res = cloudFrontSignedUrlService.signForParticipants(key.trim());
        if (res.url() != null && !res.url().isBlank()) {
            return res.url();
        }
        return objectStoragePresigner.presignGet(photosBucket, key.trim(), Duration.ofMinutes(120)).toString();
    }

    public record SocialShareLink(String url, Instant expiresAt) {
    }

    private static String originalKey(String eventId, String guestId, String photoId) {
        return "eventos/" + eventId + "/guests/" + guestId + "/private/" + photoId + ".jpg";
    }

    private static String sharedBaseKey(String eventId, String photoId) {
        return "eventos/" + eventId + "/shared/" + photoId;
    }

    private static boolean isShared(Photo p) {
        if (p == null) {
            return false;
        }
        return isSharedKey(p.getS3KeyOriginal()) || isSharedKey(p.getS3KeyMedium()) || isSharedKey(p.getS3KeySmall());
    }

    private static boolean isSharedKey(String key) {
        if (key == null || key.isBlank()) {
            return false;
        }
        return key.contains("/shared/");
    }

    private static String sharedKey(String eventId, String photoId, String suffix) {
        if (eventId == null || eventId.isBlank() || photoId == null || photoId.isBlank()) {
            return null;
        }
        String sfx = suffix != null ? suffix : "";
        return sharedBaseKey(eventId.trim(), photoId.trim()) + sfx + ".jpg";
    }

    private static String variantKeyFromOriginal(String originalKey, String suffix) {
        if (originalKey == null || originalKey.isBlank()) {
            return null;
        }
        String key = originalKey.trim();
        String sfx = suffix != null ? suffix : "";
        if (key.endsWith(".jpg")) {
            return key.substring(0, key.length() - 4) + sfx + ".jpg";
        }
        if (key.endsWith(".jpeg")) {
            return key.substring(0, key.length() - 5) + sfx + ".jpeg";
        }
        return key + sfx;
    }

    private void moveIfPresent(String sourceKey, String destinationKey) {
        if (sourceKey == null || sourceKey.isBlank() || destinationKey == null || destinationKey.isBlank()) {
            return;
        }
        String src = sourceKey.trim();
        String dst = destinationKey.trim();
        if (src.equals(dst)) {
            return;
        }
        objectStorage.copy(photosBucket, src, photosBucket, dst);
        try {
            objectStorage.delete(photosBucket, src);
        } catch (Exception ignored) {
        }
    }

    private static void require(String s, String name) {
        if (s == null || s.isBlank()) {
            throw new IllegalArgumentException("Missing " + name);
        }
    }

    private String resolvePreferredName(String userId, String fallbackEmail) {
        if (userId == null || userId.isBlank()) return fallbackEmail;

        Map<String, String> resolved = resolvePreferredNames(Set.of(userId.trim()));
        String name = resolved.get(userId.trim());
        return (name == null || name.isBlank()) ? fallbackEmail : name;
    }

    private Map<String, String> resolvePreferredNames(Set<String> userIds) {
        Map<String, PreferredNamesCacheRepository.CachedPreferredName> cached = preferredNamesCacheRepository.getMany(userIds);
        Instant now = Instant.now(clock);
        Map<String, String> out = new java.util.HashMap<>();

        Set<String> misses = new java.util.HashSet<>();
        for (String raw : userIds) {
            if (raw == null || raw.isBlank()) continue;
            String id = raw.trim();
            PreferredNamesCacheRepository.CachedPreferredName c = cached.get(id);
            if (c == null || c.expiresAt() == null || now.isAfter(c.expiresAt())) {
                misses.add(id);
                continue;
            }
            if (c.preferredName() != null && !c.preferredName().isBlank()) {
                out.put(id, c.preferredName().trim());
            }
        }

        if (misses.isEmpty()) {
            return out;
        }

        Instant expiresAt = now.plus(30, ChronoUnit.DAYS);
        for (String id : misses) {
            try {
                User u = getUserByIdUseCase.execute(id).orElse(null);
                if (u == null) continue;
                String name = computeDisplayName(u);
                if (name == null || name.isBlank()) continue;
                out.put(id, name);
                preferredNamesCacheRepository.put(id, name, expiresAt, now);
            } catch (Exception ignored) {
            }
        }

        return out;
    }

    private static String computeDisplayName(User u) {
        if (u == null) return null;
        if (u.getPreferredName() != null && !u.getPreferredName().isBlank()) return u.getPreferredName().trim();
        if (u.getGivenName() != null && !u.getGivenName().isBlank()) return u.getGivenName().trim();
        if (u.getName() != null && !u.getName().isBlank()) return u.getName().trim();
        if (u.getEmail() != null && !u.getEmail().isBlank()) return u.getEmail().trim();
        return null;
    }

    public record PresignPutResult(String photoId, String putUrl, String s3KeyOriginal, Instant expiresAt) {
    }

    public record ListPage(List<ListItem> items, String nextToken) {
    }

    public record ListItem(
            String photoId,
            String guestId,
            Instant createdAt,
            Instant uploadedAt,
            String status,
            String originalUrl,
            String mediumUrl,
            String smallUrl,
            boolean shared,
            String ownerName,
            String sharedByUserId,
            String sharedByName,
            boolean likedByMe
    ) {
    }
}
