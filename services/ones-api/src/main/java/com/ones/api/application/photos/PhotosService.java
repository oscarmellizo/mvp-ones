package com.ones.api.application.photos;

import java.io.IOException;
import java.io.InputStream;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.Optional;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.ones.api.application.events.GetEventUseCase;
import com.ones.api.application.events.EventNotFoundException;
import com.ones.api.application.events.ports.ObjectNotFoundException;
import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.application.events.ports.ObjectStorage;
import com.ones.api.application.events.ports.ObjectStoragePresigner;
import com.ones.api.application.photos.ports.PhotosRepository;
import com.ones.api.application.photos.ports.PhotoLikesRepository;
import com.ones.api.application.photos.ports.PhotoProcessingQueue;
import com.ones.api.application.photos.ports.PhotoDateResolutionQueue;
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
    private final PhotoProcessingQueue photoProcessingQueue;
    private PhotoDateResolutionQueue photoDateResolutionQueue;
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
            PhotoProcessingQueue photoProcessingQueue,
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
        this.photoProcessingQueue = photoProcessingQueue;
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
        return complete(
                requesterUserId,
                requesterEmail,
                eventId,
                photoId,
                createdAt,
                s3KeyOriginal,
                null,
                null,
                null,
                null,
                null
        );
    }

    @Autowired(required = false)
    public void setPhotoDateResolutionQueue(PhotoDateResolutionQueue queue) {
        this.photoDateResolutionQueue = queue;
    }

    public Photo complete(
            String requesterUserId,
            String requesterEmail,
            String eventId,
            String photoId,
            Instant createdAt,
            String s3KeyOriginal,
            String originalFilename,
            Instant metadataCreatedAt,
            Instant filenameCreatedAt,
            Integer deviceUtcOffsetMinutes,
            String createdAtSource
    ) {
        require(eventId, "eventId");
        require(photoId, "photoId");
        require(s3KeyOriginal, "s3KeyOriginal");

        Event event = getEventUseCase.execute(requesterUserId, requesterEmail, eventId);
        String expectedKey = originalKey(event.getEventId(), requesterUserId, photoId);
        if (!expectedKey.equals(s3KeyOriginal.trim())) {
            throw new IllegalArgumentException("Invalid photo upload key");
        }

        Instant now = Instant.now(clock);
        Instant safeMetadataCreatedAt = validCaptureDate(metadataCreatedAt, now);
        Instant safeFilenameCreatedAt = validCaptureDate(filenameCreatedAt, now);
        Instant safeClientCreatedAt = validCaptureDate(createdAt, now);
        Instant resolvedCreatedAt = earlier(safeMetadataCreatedAt, safeFilenameCreatedAt);
        if (resolvedCreatedAt == null) {
            resolvedCreatedAt = safeClientCreatedAt != null ? safeClientCreatedAt : now;
        }
        String resolvedSource = resolveDateSource(
                safeMetadataCreatedAt,
                safeFilenameCreatedAt,
                createdAtSource,
                safeClientCreatedAt
        );

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
                requesterUserId,
                ownerName,
                true
        );

        Photo completed = photosRepository.completeUpload(photo);
        String safeFilename = sanitizeOriginalFilename(originalFilename);
        boolean shouldResolveFilename = safeFilename != null && safeFilenameCreatedAt == null;
        if (photoDateResolutionQueue != null && photoDateResolutionQueue.isConfigured()) {
            if (shouldResolveFilename) {
                boolean pending = photosRepository.markDateResolutionPending(
                        completed.getEventId(),
                        completed.getPhotoId(),
                        resolvedSource
                );
                if (pending) {
                    try {
                        photoDateResolutionQueue.enqueue(new PhotoDateResolutionQueue.Job(
                                completed.getEventId(),
                                completed.getPhotoId(),
                                safeFilename,
                                safeMetadataCreatedAt == null ? null : safeMetadataCreatedAt.toString(),
                                normalizeOffset(deviceUtcOffsetMinutes)
                        ));
                    } catch (RuntimeException e) {
                        log.warn(
                                "photo_date_resolution_enqueue_failed eventId={} photoId={} error={}",
                                completed.getEventId(),
                                completed.getPhotoId(),
                                e.getClass().getSimpleName()
                        );
                    }
                }
            } else {
                photosRepository.markDateResolutionNotNeeded(
                        completed.getEventId(),
                        completed.getPhotoId(),
                        resolvedSource
                );
            }
        }

        if ("uploaded".equalsIgnoreCase(completed.getStatus())) {
            try {
                photoProcessingQueue.enqueue(new PhotoProcessingQueue.Job(
                        completed.getEventId(),
                        completed.getPhotoId(),
                        completed.getS3KeyOriginal(),
                        false,
                        UUID.randomUUID().toString()
                ));
            } catch (RuntimeException e) {
                log.warn(
                        "photo_processing_enqueue_failed eventId={} photoId={} error={}",
                        completed.getEventId(),
                        completed.getPhotoId(),
                        e.getClass().getSimpleName()
                );
            }
        }
        return completed;
    }

    public boolean applyPhotoDateResolutionInternal(
            String eventId,
            String photoId,
            Instant resolvedCreatedAt,
            String status,
            String source
    ) {
        require(eventId, "eventId");
        require(photoId, "photoId");
        String resolvedStatus = status == null ? "" : status.trim().toLowerCase();
        if ("no_date".equals(resolvedStatus)) {
            return photosRepository.completeDateResolution(
                    eventId,
                    photoId,
                    null,
                    "no_date",
                    "upload_fallback"
            );
        }
        if (!"resolved".equals(resolvedStatus) || resolvedCreatedAt == null) {
            throw new IllegalArgumentException("Invalid photo date resolution");
        }
        Instant now = Instant.now(clock);
        if (resolvedCreatedAt.isBefore(Instant.parse("1900-01-01T00:00:00Z"))
                || resolvedCreatedAt.isAfter(now.plus(Duration.ofDays(1)))) {
            throw new IllegalArgumentException("Resolved photo date is outside the accepted range");
        }
        String resolvedSource = "metadata".equalsIgnoreCase(source) ? "metadata" : "filename_ai";
        return photosRepository.completeDateResolution(
                eventId,
                photoId,
                resolvedCreatedAt,
                "resolved",
                resolvedSource
        );
    }

    private Instant earlier(Instant first, Instant second) {
        if (first == null) return second;
        if (second == null) return first;
        return first.isBefore(second) ? first : second;
    }

    private Instant validCaptureDate(Instant candidate, Instant now) {
        if (candidate == null
                || candidate.isBefore(Instant.parse("1900-01-01T00:00:00Z"))
                || candidate.isAfter(now.plus(Duration.ofDays(1)))) {
            return null;
        }
        return candidate;
    }

    private String resolveDateSource(
            Instant metadataDate,
            Instant filenameDate,
            String requestSource,
            Instant createdAt
    ) {
        if (metadataDate != null && filenameDate != null) {
            return metadataDate.isBefore(filenameDate) ? "metadata" : "filename";
        }
        if (metadataDate != null) return "metadata";
        if (filenameDate != null) return "filename";
        if (requestSource != null && Set.of("metadata", "filename", "file_modified", "upload_time")
                .contains(requestSource.trim().toLowerCase())) {
            return requestSource.trim().toLowerCase();
        }
        return createdAt == null ? "upload_time" : "client";
    }

    private String sanitizeOriginalFilename(String filename) {
        if (filename == null || filename.isBlank()) return null;
        String basename = filename.replace('\\', '/');
        basename = basename.substring(basename.lastIndexOf('/') + 1)
                .replaceAll("[\\p{Cntrl}]", "")
                .trim();
        if (basename.isEmpty()) return null;
        return basename.length() <= 255 ? basename : basename.substring(0, 255);
    }

    private Integer normalizeOffset(Integer offset) {
        return offset == null || offset < -840 || offset > 840 ? 0 : offset;
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
                if (p.getEventId() == null || !p.getEventId().equals(eventId)) {
                    continue;
                }

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
                            likedByMe.contains(p.getPhotoId() != null ? p.getPhotoId().trim() : ""),
                            p.getProcessingAttempts(),
                            p.getProcessingErrorCode(),
                            "failed".equalsIgnoreCase(p.getStatus())
                                    && isProcessingErrorRetryable(p.getProcessingErrorCode())
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
                if (p.getEventId() == null || !p.getEventId().equals(eventId)) {
                    continue;
                }

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
                            likedByMe.contains(p.getPhotoId() != null ? p.getPhotoId().trim() : ""),
                            p.getProcessingAttempts(),
                            p.getProcessingErrorCode(),
                            "failed".equalsIgnoreCase(p.getStatus())
                                    && isProcessingErrorRetryable(p.getProcessingErrorCode())
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
                        nextSharedByName,
                        existing.isShared(),
                        existing.getProcessingAttempts(),
                        existing.getProcessingErrorCode(),
                        existing.getProcessingLeaseUntilEpoch(),
                        existing.getProcessingRetryAtEpoch()
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
                    sharedByName,
                    true,
                    existing.getProcessingAttempts(),
                    existing.getProcessingErrorCode(),
                    existing.getProcessingLeaseUntilEpoch(),
                    existing.getProcessingRetryAtEpoch()
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
                            null,
                            false,
                            existing.getProcessingAttempts(),
                            existing.getProcessingErrorCode(),
                            existing.getProcessingLeaseUntilEpoch(),
                            existing.getProcessingRetryAtEpoch()
                    );
                    updated.add(photosRepository.upsert(next));
                } else {
                    updated.add(existing);
                }
                continue;
            }

            if (!isSharedKey(existing.getS3KeyOriginal())
                    && !isSharedKey(existing.getS3KeyMedium())
                    && !isSharedKey(existing.getS3KeySmall())) {
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
                        null,
                        false,
                        existing.getProcessingAttempts(),
                        existing.getProcessingErrorCode(),
                        existing.getProcessingLeaseUntilEpoch(),
                        existing.getProcessingRetryAtEpoch()
                );
                updated.add(photosRepository.upsert(next));
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
                    null,
                    false,
                    existing.getProcessingAttempts(),
                    existing.getProcessingErrorCode(),
                    existing.getProcessingLeaseUntilEpoch(),
                    existing.getProcessingRetryAtEpoch()
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
                    null,
                    false
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
                existing.getSharedByName(),
                existing.isShared(),
                existing.getProcessingAttempts(),
                null,
                null,
                null
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

    public Photo markReadyInternal(
            String eventId,
            String photoId,
            String s3KeyOriginal,
            String s3KeyMedium,
            String s3KeySmall
    ) {
        require(eventId, "eventId");
        require(photoId, "photoId");
        require(s3KeyOriginal, "s3KeyOriginal");
        if (!matchesOriginalKey(eventId, photoId, s3KeyOriginal)) {
            throw new IllegalArgumentException("Invalid photo upload key");
        }

        boolean collectionOwner = eventId.trim().startsWith("COLLECTION#");
        Event event = collectionOwner ? null : eventsRepository.findById(eventId.trim()).orElse(null);
        if (!collectionOwner && event == null) {
            throw new IllegalArgumentException("Missing event");
        }

        Instant now = Instant.now(clock);
        return photosRepository.markReadyInternal(
                eventId.trim(),
                photoId,
                s3KeyOriginal.trim(),
                s3KeyMedium,
                s3KeySmall,
                now
        );
    }

    public PhotosRepository.ProcessingClaim claimProcessingInternal(
            String eventId,
            String photoId,
            String s3KeyOriginal,
            boolean manualRetry
    ) {
        require(eventId, "eventId");
        require(photoId, "photoId");
        require(s3KeyOriginal, "s3KeyOriginal");

        if (!matchesOriginalKey(eventId, photoId, s3KeyOriginal)) {
            return new PhotosRepository.ProcessingClaim(
                    PhotosRepository.ProcessingClaimStatus.CONFLICT,
                    null
            );
        }
        if (!eventId.trim().startsWith("COLLECTION#")
                && eventsRepository.findById(eventId.trim()).isEmpty()) {
            return new PhotosRepository.ProcessingClaim(
                    PhotosRepository.ProcessingClaimStatus.NOT_FOUND,
                    null
            );
        }

        Instant now = Instant.now(clock);
        return photosRepository.claimProcessing(
                eventId.trim(),
                photoId.trim(),
                s3KeyOriginal.trim(),
                manualRetry,
                now,
                now.plus(Duration.ofMinutes(3))
        );
    }

    public Optional<Photo> markProcessingRetryingInternal(
            String eventId,
            String photoId,
            String s3KeyOriginal,
            String errorCode,
            Instant retryAt
    ) {
        require(eventId, "eventId");
        require(photoId, "photoId");
        require(s3KeyOriginal, "s3KeyOriginal");
        if (!matchesOriginalKey(eventId, photoId, s3KeyOriginal)) {
            return Optional.empty();
        }
        Optional<Photo> updated = photosRepository.markProcessingRetrying(
                eventId.trim(),
                photoId.trim(),
                s3KeyOriginal.trim(),
                safeProcessingErrorCode(errorCode),
                retryAt != null ? retryAt : Instant.now(clock)
        );
        updated.filter(photo -> "retrying".equalsIgnoreCase(photo.getStatus()))
                .ifPresent(photo -> log.warn(
                        "photo_processing_retry eventId={} photoId={} attempt={} errorCode={}",
                        eventId,
                        photoId,
                        photo.getProcessingAttempts(),
                        photo.getProcessingErrorCode()
                ));
        return updated;
    }

    public Optional<Photo> markProcessingFailedInternal(
            String eventId,
            String photoId,
            String s3KeyOriginal,
            String errorCode
    ) {
        require(eventId, "eventId");
        require(photoId, "photoId");
        require(s3KeyOriginal, "s3KeyOriginal");
        if (!matchesOriginalKey(eventId, photoId, s3KeyOriginal)) {
            return Optional.empty();
        }
        Optional<Photo> updated = photosRepository.markProcessingFailed(
                eventId.trim(),
                photoId.trim(),
                s3KeyOriginal.trim(),
                safeProcessingErrorCode(errorCode)
        );
        updated.filter(photo -> "failed".equalsIgnoreCase(photo.getStatus()))
                .ifPresent(photo -> log.warn(
                        "photo_processing_failed eventId={} photoId={} attempt={} errorCode={}",
                        eventId,
                        photoId,
                        photo.getProcessingAttempts(),
                        photo.getProcessingErrorCode()
                ));
        return updated;
    }

    public PhotoRecoveryResult recoverOrphanedPhotoInternal(
            String eventId,
            String photoId,
            String s3KeyOriginal,
            Instant createdAt
    ) {
        require(eventId, "eventId");
        require(photoId, "photoId");
        require(s3KeyOriginal, "s3KeyOriginal");
        if (createdAt == null) {
            throw new IllegalArgumentException("createdAt is required");
        }

        String resolvedEventId = eventId.trim();
        String resolvedPhotoId = photoId.trim();
        String resolvedKey = s3KeyOriginal.trim();
        if (!matchesOriginalKey(resolvedEventId, resolvedPhotoId, resolvedKey)) {
            throw new IllegalArgumentException("Invalid original photo key");
        }
        if (eventsRepository.findById(resolvedEventId).isEmpty()) {
            throw new EventNotFoundException(resolvedEventId);
        }

        String guestId = resolvedKey.split("/")[3];
        Photo existing = photosRepository.findById(resolvedPhotoId).orElse(null);
        if (existing != null) {
            if (!resolvedEventId.equals(existing.getEventId())
                    || !guestId.equals(existing.getGuestId())
                    || !resolvedKey.equals(existing.getS3KeyOriginal())) {
                throw new IllegalArgumentException("Photo recovery conflicts with an existing photo");
            }
            if ("ready".equalsIgnoreCase(existing.getStatus())) {
                return new PhotoRecoveryResult(existing, false);
            }
        }

        try (InputStream ignored = objectStorage.open(photosBucket, resolvedKey)) {
            // Opening the object verifies it exists without buffering the image in the API.
        } catch (IOException e) {
            throw new IllegalStateException("Could not verify the original photo object", e);
        } catch (ObjectNotFoundException e) {
            throw e;
        }

        Instant now = Instant.now(clock);
        Photo candidate = new Photo(
                resolvedPhotoId,
                resolvedEventId,
                guestId,
                createdAt,
                now,
                "uploaded",
                resolvedKey,
                null,
                null,
                null,
                guestId,
                null,
                true
        );
        Photo recovered = photosRepository.completeUpload(candidate);
        boolean manualRetry = "failed".equalsIgnoreCase(recovered.getStatus());
        if (!"ready".equalsIgnoreCase(recovered.getStatus())) {
            photoProcessingQueue.enqueue(new PhotoProcessingQueue.Job(
                    resolvedEventId,
                    resolvedPhotoId,
                    resolvedKey,
                    manualRetry,
                    UUID.randomUUID().toString()
            ));
            log.info(
                    "photo_recovery_queued eventId={} photoId={} priorStatus={} manualRetry={}",
                    resolvedEventId,
                    resolvedPhotoId,
                    existing != null ? existing.getStatus() : "missing",
                    manualRetry
            );
            return new PhotoRecoveryResult(recovered, true);
        }
        return new PhotoRecoveryResult(recovered, false);
    }

    public RetryProcessingResult retryFailedProcessing(
            String requesterUserId,
            String requesterEmail,
            String eventId,
            String photoId
    ) {
        require(eventId, "eventId");
        require(photoId, "photoId");
        getEventUseCase.execute(requesterUserId, requesterEmail, eventId);

        Photo photo = photosRepository.findById(photoId.trim())
                .orElseThrow(() -> new PhotoNotFoundException(photoId));
        if (!eventId.equals(photo.getEventId())) {
            throw new PhotoNotFoundException(photoId);
        }
        if (!requesterUserId.equals(photo.getGuestId())) {
            throw new PhotoNotOwnedException(photoId);
        }
        if (!"failed".equalsIgnoreCase(photo.getStatus())
                || !isProcessingErrorRetryable(photo.getProcessingErrorCode())) {
            throw new IllegalArgumentException("Photo processing is not retryable");
        }
        require(photo.getS3KeyOriginal(), "s3KeyOriginal");

        photoProcessingQueue.enqueue(new PhotoProcessingQueue.Job(
                eventId,
                photo.getPhotoId(),
                photo.getS3KeyOriginal(),
                true,
                UUID.randomUUID().toString()
        ));
        photosRepository.markRetryRequested(eventId, photo.getPhotoId());
        return new RetryProcessingResult(photo.getPhotoId(), "retrying");
    }

    private static boolean matchesOriginalKey(String eventId, String photoId, String key) {
        if (key == null || key.isBlank()) return false;
        String[] parts = key.trim().split("/");
        if (eventId != null && eventId.startsWith("COLLECTION#")) {
            String[] ownerParts = eventId.split("#", 3);
            if (ownerParts.length != 3) return false;
            String collectionId = ownerParts[1];
            String expectedPartition = com.ones.api.domain.photos.PhotoOwner
                    .collection(collectionId).storagePartitionId(photoId);
            return expectedPartition.equals(eventId.trim())
                    && parts.length == 6
                    && "colecciones".equals(parts[0])
                    && collectionId.equals(parts[1])
                    && "guests".equals(parts[2])
                    && !parts[3].isBlank()
                    && "private".equals(parts[4])
                    && (photoId.trim() + ".jpg").equals(parts[5]);
        }
        return parts.length == 6
                && "eventos".equals(parts[0])
                && eventId.trim().equals(parts[1])
                && "guests".equals(parts[2])
                && !parts[3].isBlank()
                && "private".equals(parts[4])
                && (photoId.trim() + ".jpg").equals(parts[5]);
    }

    private static String safeProcessingErrorCode(String raw) {
        if (raw == null || raw.isBlank()) return "processing_failed";
        String code = raw.trim().toLowerCase();
        return Set.of(
                "invalid_image",
                "source_missing",
                "invalid_key",
                "s3_unavailable",
                "backend_unavailable",
                "throttled",
                "processing_timeout",
                "retry_exhausted",
                "processing_failed"
        ).contains(code) ? code : "processing_failed";
    }

    private static boolean isProcessingErrorRetryable(String errorCode) {
        return !"invalid_image".equals(errorCode)
                && !"source_missing".equals(errorCode)
                && !"invalid_key".equals(errorCode);
    }

    public void deletePhotos(
            String requesterUserId,
            String requesterEmail,
            String eventId,
            List<String> photoIds
    ) {
        require(eventId, "eventId");
        if (photoIds == null || photoIds.isEmpty()) {
            throw new IllegalArgumentException("photoIds must not be empty");
        }
        if (photoIds.size() > 50) {
            throw new IllegalArgumentException("Cannot delete more than 50 photos at once");
        }

        getEventUseCase.execute(requesterUserId, requesterEmail, eventId);

        List<Photo> resolved = new ArrayList<>(photoIds.size());
        for (String rawId : photoIds) {
            if (rawId == null || rawId.isBlank()) continue;
            String photoId = rawId.trim();
            Photo photo = photosRepository.findById(photoId)
                    .orElseThrow(() -> new PhotoNotFoundException(photoId));
            if (!requesterUserId.equals(photo.getGuestId())) {
                throw new PhotoNotOwnedException(photoId);
            }
            if (isShared(photo)) {
                throw new PhotoSharedException(photoId);
            }
            resolved.add(photo);
        }

        for (Photo photo : resolved) {
            String keyOrig = photo.getS3KeyOriginal();
            String keyMedium = photo.getS3KeyMedium();
            String keySmall = photo.getS3KeySmall();
            if ((keyMedium == null || keyMedium.isBlank()) && keyOrig != null && !keyOrig.isBlank()) {
                keyMedium = variantKeyFromOriginal(keyOrig, "_m");
            }
            if ((keySmall == null || keySmall.isBlank()) && keyOrig != null && !keyOrig.isBlank()) {
                keySmall = variantKeyFromOriginal(keyOrig, "_s");
            }
            deleteS3KeyBestEffort(keyOrig);
            deleteS3KeyBestEffort(keyMedium);
            deleteS3KeyBestEffort(keySmall);

            try {
                photoLikesRepository.deleteAllByPhotoId(photo.getPhotoId());
            } catch (Exception e) {
                log.warn("[PhotosService.deletePhotos] failed to delete likes for photoId={} err={}",
                        photo.getPhotoId(), e.toString());
            }

            photosRepository.deleteById(photo.getPhotoId());
        }
    }

    private void deleteS3KeyBestEffort(String key) {
        if (key == null || key.isBlank()) return;
        try {
            objectStorage.delete(photosBucket, key.trim());
        } catch (Exception e) {
            log.warn("[PhotosService.deletePhotos] S3 delete best-effort failed key={} err={}", key, e.toString());
        }
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

    public record RetryProcessingResult(String photoId, String status) {
    }

    public record PhotoRecoveryResult(Photo photo, boolean processingQueued) {
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
        return p.isShared()
                || isSharedKey(p.getS3KeyOriginal())
                || isSharedKey(p.getS3KeyMedium())
                || isSharedKey(p.getS3KeySmall());
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
            boolean likedByMe,
            int processingAttempts,
            String processingErrorCode,
            boolean processingRetryable
    ) {
    }
}
