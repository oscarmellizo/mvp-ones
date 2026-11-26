package com.ones.api.adapters.inbound.rest.collections;

import java.net.URI;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.collections.CollectionService;
import com.ones.api.application.collections.CollectionJoinRateLimitException;
import com.ones.api.application.collections.CollectionJoinRateLimiter;
import com.ones.api.application.invitations.email.InvitationActionTokenService;
import com.ones.api.adapters.inbound.rest.AuthClaims;
import com.ones.api.domain.collections.Collection;
import com.ones.api.domain.collections.CollectionMember;

@RestController
@RequestMapping("/v1/collections")
public class CollectionsController {
    private final CollectionService collectionService;
    private final InvitationActionTokenService invitationTokenService;
    private final CollectionJoinRateLimiter joinRateLimiter;
    private final String appBaseUrl;

    public CollectionsController(
            CollectionService collectionService,
            InvitationActionTokenService invitationTokenService,
            CollectionJoinRateLimiter joinRateLimiter,
            @Value("${ones.app.base-url:}") String appBaseUrl
    ) {
        this.collectionService = collectionService;
        this.invitationTokenService = invitationTokenService;
        this.joinRateLimiter = joinRateLimiter;
        this.appBaseUrl = appBaseUrl;
    }

    @GetMapping
    public List<CollectionResponse> list(
            Authentication authentication,
            @RequestParam(defaultValue = "100") int limit
    ) {
        return collectionService.list(authentication.getName(), limit).stream()
                .map(CollectionsController::toResponse)
                .toList();
    }

    @PostMapping
    public ResponseEntity<CollectionResponse> create(
            Authentication authentication,
            @Valid @RequestBody CreateCollectionRequest request
    ) {
        Collection collection = collectionService.create(
                authentication.getName(), request.name(), request.description(),
                request.type(), request.coverKey(), request.inviteeEmails(),
                AuthClaims.preferredName(authentication)
        );
        return ResponseEntity.created(URI.create("/v1/collections/" + collection.id()))
                .body(toResponse(collection));
    }

    @PostMapping("/ensure-life")
    public CollectionResponse ensureLife(Authentication authentication) {
        return toResponse(collectionService.ensureLife(authentication.getName()));
    }

    @GetMapping("/{id}")
    public CollectionResponse get(Authentication authentication, @PathVariable String id) {
        return toResponse(collectionService.get(authentication.getName(), id));
    }

    @PutMapping("/{id}")
    public CollectionResponse update(
            Authentication authentication,
            @PathVariable String id,
            @Valid @RequestBody UpdateCollectionRequest request
    ) {
        return toResponse(collectionService.update(
                authentication.getName(), id, request.name(), request.description(), request.coverKey()
        ));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(
            Authentication authentication,
            @PathVariable("id") String id
    ) {
        collectionService.delete(authentication.getName(), id);
        return ResponseEntity.accepted().build();
    }

    @GetMapping("/{id}/members")
    public CollectionMembersPageResponse members(
            Authentication authentication,
            @PathVariable String id,
            @RequestParam(defaultValue = "50") @Min(1) @Max(200) int limit,
            @RequestParam(required = false) String nextToken
    ) {
        var page = collectionService.listMembersPage(
                authentication.getName(), id, limit, nextToken);
        return new CollectionMembersPageResponse(
                page.items().stream().map(CollectionsController::toMemberResponse).toList(),
                page.nextToken()
        );
    }

    @PostMapping("/{id}/invitees")
    public List<CollectionMemberResponse> invite(
            Authentication authentication,
            @PathVariable String id,
            @Valid @RequestBody InviteCollectionMembersRequest request
    ) {
        return collectionService.invite(
                        authentication.getName(), AuthClaims.preferredName(authentication), id, request.inviteeEmails())
                .stream().map(CollectionsController::toMemberResponse).toList();
    }

    @PostMapping("/invitations/respond")
    public CollectionMemberResponse respondToInvitation(
            Authentication authentication,
            @Valid @RequestBody RespondToCollectionInvitationRequest request
    ) {
        InvitationActionTokenService.Decoded decoded = invitationTokenService.decodeAndValidate(request.token());
        if (!decoded.eventId().startsWith("collection:")) {
            throw new IllegalArgumentException("Token is not a collection invitation");
        }
        String email = AuthClaims.requireEmail(authentication);
        if (!email.equalsIgnoreCase(decoded.inviteeEmail())) {
            throw new com.ones.api.application.collections.CollectionForbiddenException("invitation");
        }
        String collectionId = decoded.eventId().substring("collection:".length());
        return toMemberResponse(collectionService.respondToInvitation(
                collectionId, email, authentication.getName(), decoded.action()
        ));
    }

    @PostMapping("/{id}/members/leave")
    public ResponseEntity<Void> leave(Authentication authentication, @PathVariable String id) {
        collectionService.leave(authentication.getName(), id);
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/{id}/members/{userId}")
    public ResponseEntity<Void> removeMember(
            Authentication authentication,
            @PathVariable String id,
            @PathVariable String memberKey
    ) {
        collectionService.removeMember(authentication.getName(), id, memberKey);
        return ResponseEntity.noContent().build();
    }

    @PutMapping("/{id}/owner")
    public ResponseEntity<Void> transferOwnership(
            Authentication authentication,
            @PathVariable String id,
            @Valid @RequestBody TransferOwnershipRequest request
    ) {
        collectionService.transferOwnership(authentication.getName(), id, request.newOwnerId());
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/join-qr/rotate")
    public JoinQrResponse rotateJoinQr(Authentication authentication, @PathVariable String id) {
        return joinQrResponse(id, collectionService.rotateJoinQr(authentication.getName(), id));
    }

    @PutMapping("/{id}/join-qr")
    public JoinQrResponse setJoinQr(
            Authentication authentication,
            @PathVariable String id,
            @Valid @RequestBody JoinQrRequest request
    ) {
        String token = collectionService.setJoinQrEnabled(authentication.getName(), id, request.enabled());
        return request.enabled() ? joinQrResponse(id, token) : new JoinQrResponse(false, null);
    }

    @PostMapping("/join-qr/join")
    public CollectionResponse joinByQr(
            Authentication authentication,
            @Valid @RequestBody JoinByQrRequest request
    ) {
        if (!joinRateLimiter.tryAcquire(authentication.getName())) {
            throw new CollectionJoinRateLimitException();
        }
        return toResponse(collectionService.joinByQr(
                authentication.getName(), AuthClaims.requireEmail(authentication),
                request.collectionId(), request.token()
        ));
    }

    private JoinQrResponse joinQrResponse(String id, String token) {
        String base = appBaseUrl == null ? "" : appBaseUrl.trim();
        while (base.endsWith("/")) base = base.substring(0, base.length() - 1);
        String url = (base.isBlank() ? "ones://collections/join" : base + "/collections/join")
                + "?collectionId=" + URLEncoder.encode(id, StandardCharsets.UTF_8)
                + "&token=" + URLEncoder.encode(token, StandardCharsets.UTF_8);
        return new JoinQrResponse(true, url);
    }

    private static CollectionResponse toResponse(Collection collection) {
        return new CollectionResponse(
                collection.id(), collection.ownerId(), collection.name(), collection.description(),
                collection.type().name(), collection.coverKey(), collection.purpose(),
                collection.createdAt().toString(), collection.updatedAt().toString(),
                collection.joinEnabled()
        );
    }

    private static CollectionMemberResponse toMemberResponse(CollectionMember member) {
        return new CollectionMemberResponse(
                member.memberKey(), member.userId(), member.email(), member.status().name(),
                member.invitedByUserId(), member.createdAt().toString()
        );
    }

    public record CreateCollectionRequest(
            @NotBlank @Size(max = 100) String name,
            @Size(max = 500) String description,
            @NotBlank String type,
            String coverKey,
            List<@Email String> inviteeEmails
    ) {}

    public record UpdateCollectionRequest(
            @NotBlank @Size(max = 100) String name,
            @Size(max = 500) String description,
            String coverKey
    ) {}

    public record CollectionResponse(
            String id,
            String ownerId,
            String name,
            String description,
            String type,
            String coverKey,
            String purpose,
            String createdAt,
            String updatedAt,
            boolean joinEnabled
    ) {}

    public record InviteCollectionMembersRequest(List<@Email String> inviteeEmails) {}
    public record RespondToCollectionInvitationRequest(@NotBlank String token) {}
    public record JoinQrRequest(boolean enabled) {}
    public record TransferOwnershipRequest(@NotBlank String newOwnerId) {}
    public record JoinByQrRequest(@NotBlank String collectionId, @NotBlank String token) {}
    public record JoinQrResponse(boolean enabled, String url) {}
    public record CollectionMemberResponse(
            String memberKey, String userId, String email, String status,
            String invitedByUserId, String createdAt
    ) {}
    public record CollectionMembersPageResponse(
            List<CollectionMemberResponse> items,
            String nextToken
    ) {}
}
