package com.ones.api.application.photos;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.ones.api.application.photos.ports.PhotoShortLinksRepository;
import com.ones.api.application.photos.ports.PhotoShortLinksRepository.PhotoShortLink;
import com.ones.api.application.photos.ports.PhotosRepository;
import com.ones.api.domain.photos.Photo;

@Service
public class PhotoShortLinksService {

    private final PhotoShortLinksRepository photoShortLinksRepository;
    private final PhotosRepository photosRepository;
    private final ObjectStoragePresigner objectStoragePresigner;
    private final CloudFrontSignedUrlService cloudFrontSignedUrlService;
    private final Clock clock;

    private final String photosBucket;
    private final long ttlDays;

    private final SecureRandom secureRandom = new SecureRandom();

    public PhotoShortLinksService(
            PhotoShortLinksRepository photoShortLinksRepository,
            PhotosRepository photosRepository,
            ObjectStoragePresigner objectStoragePresigner,
            CloudFrontSignedUrlService cloudFrontSignedUrlService,
            Clock clock,
            @Value("${ones.s3.events.photos.bucket}") String photosBucket,
            @Value("${ones.photos.social-share-ttl-days:7}") long ttlDays
    ) {
        this.photoShortLinksRepository = photoShortLinksRepository;
        this.photosRepository = photosRepository;
        this.objectStoragePresigner = objectStoragePresigner;
        this.cloudFrontSignedUrlService = cloudFrontSignedUrlService;
        this.clock = clock;
        this.photosBucket = photosBucket;
        this.ttlDays = ttlDays;
    }

    public PhotoShortLink create(String eventId, String photoId, String variant) {
        Instant now = Instant.now(clock);
        Instant expiresAt = now.plus(Duration.ofDays(Math.max(1, ttlDays)));

        String resolvedVariant = (variant == null || variant.isBlank()) ? "medium" : variant.trim().toLowerCase();
        String code = newCode();

        PhotoShortLink link = new PhotoShortLink(code, eventId, photoId, resolvedVariant, now, expiresAt);
        return photoShortLinksRepository.create(link);
    }

    public Optional<Resolved> resolve(String code) {
        if (code == null || code.isBlank()) {
            return Optional.empty();
        }

        PhotoShortLink link = photoShortLinksRepository.findByCode(code.trim()).orElse(null);
        if (link == null || link.expiresAt() == null) {
            return Optional.empty();
        }

        Instant now = Instant.now(clock);
        if (link.expiresAt().isBefore(now)) {
            return Optional.empty();
        }

        Photo p = photosRepository.findById(link.photoId()).orElse(null);
        if (p == null || p.getEventId() == null || !p.getEventId().equals(link.eventId())) {
            return Optional.empty();
        }

        String key = pickVariantKey(p, link.variant());
        if (key == null || key.isBlank()) {
            return Optional.empty();
        }

        String url = signedUrl(key.trim());
        if (url == null || url.isBlank()) {
            return Optional.empty();
        }

        return Optional.of(new Resolved(link, url));
    }

    private String signedUrl(String key) {
        CloudFrontSignedUrlService.SignedUrlResult res = cloudFrontSignedUrlService.signForSocialShare(key);
        if (res.url() != null && !res.url().isBlank()) {
            return res.url();
        }
        return objectStoragePresigner.presignGet(photosBucket, key, Duration.ofMinutes(120)).toString();
    }

    private static String pickVariantKey(Photo p, String variant) {
        String resolvedVariant = (variant == null || variant.isBlank()) ? "medium" : variant.trim().toLowerCase();
        return switch (resolvedVariant) {
            case "small" -> p.getS3KeySmall();
            case "original" -> p.getS3KeyOriginal();
            case "medium" -> p.getS3KeyMedium();
            default -> p.getS3KeyMedium();
        };
    }

    private String newCode() {
        byte[] bytes = new byte[12];
        secureRandom.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    public record Resolved(PhotoShortLink link, String imageUrl) {
    }
}
