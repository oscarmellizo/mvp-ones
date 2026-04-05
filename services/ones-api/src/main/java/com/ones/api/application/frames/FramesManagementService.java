package com.ones.api.application.frames;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;

import com.ones.api.adapters.inbound.rest.AuthClaims;
import com.ones.api.application.events.ports.ObjectStoragePresigner;
import com.ones.api.application.frames.ports.FramesRepository;
import com.ones.api.domain.frames.Frame;

@Service
public class FramesManagementService {

    private final FramesRepository repository;
    private final ObjectStoragePresigner presigner;
    private final Clock clock;

    private final String assetsBucket;
    private final long putPresignTtlMinutes;
    private final long getPresignTtlMinutes;

    public FramesManagementService(
            FramesRepository repository,
            ObjectStoragePresigner presigner,
            Clock clock,
            @Value("${ones.s3.events.covers.final-bucket}") String assetsBucket,
            @Value("${ones.s3.frames.put-presign-ttl-minutes:15}") long putPresignTtlMinutes,
            @Value("${ones.s3.frames.get-presign-ttl-minutes:15}") long getPresignTtlMinutes
    ) {
        this.repository = repository;
        this.presigner = presigner;
        this.clock = clock;
        this.assetsBucket = assetsBucket;
        this.putPresignTtlMinutes = putPresignTtlMinutes;
        this.getPresignTtlMinutes = getPresignTtlMinutes;
    }

    public FramesRepository.ListResult list(String status, int limit, String nextToken) {
        return repository.list(status, limit, nextToken);
    }

    public Frame upsert(Authentication authentication, String frameId, String name, Frame.Status status, Integer sortOrder) {
        if (name == null || name.isBlank()) {
            throw new IllegalArgumentException("name is required");
        }

        Instant now = Instant.now(clock);
        String actor = resolveActor(authentication);

        String id = (frameId == null || frameId.isBlank()) ? UUID.randomUUID().toString() : frameId.trim();

        Frame existing = repository.findById(id).orElse(null);
        Instant createdAt = existing != null && existing.getCreatedAt() != null ? existing.getCreatedAt() : now;
        String createdBy = existing != null ? existing.getCreatedBy() : actor;
        String verticalAssetKey = existing != null ? existing.getVerticalAssetKey() : null;
        String horizontalAssetKey = existing != null ? existing.getHorizontalAssetKey() : null;

        Frame toSave = new Frame(
                id,
                name.trim(),
                status != null ? status : Frame.Status.inactive,
                sortOrder,
                verticalAssetKey,
                horizontalAssetKey,
                createdAt,
                now,
                createdBy,
                actor
        );

        return repository.upsert(toSave);
    }

    public void delete(String frameId) {
        repository.deleteById(frameId);
    }

    public PresignPutAssetResult presignPutAsset(Authentication authentication, String frameId, String contentType, String variant) {
        if (frameId == null || frameId.isBlank()) {
            throw new IllegalArgumentException("frameId is required");
        }

        Frame existing = repository.findById(frameId.trim()).orElseThrow(() -> new FrameNotFoundException(frameId));

        String actor = resolveActor(authentication);
        Instant now = Instant.now(clock);

        String ct = (contentType == null || contentType.isBlank()) ? "image/png" : contentType.trim();
        String ext = extensionForContentType(ct);
        String key = assetKey(existing.getFrameId(), variant, ext);

        String putUrl = presigner.presignPut(
                assetsBucket,
                key,
                Duration.ofMinutes(putPresignTtlMinutes),
                ct
        ).toString();

        Frame updated = new Frame(
                existing.getFrameId(),
                existing.getName(),
                existing.getStatus(),
                existing.getSortOrder(),
                "vertical".equalsIgnoreCase(variant) ? key : existing.getVerticalAssetKey(),
                "horizontal".equalsIgnoreCase(variant) ? key : existing.getHorizontalAssetKey(),
                existing.getCreatedAt(),
                now,
                existing.getCreatedBy(),
                actor
        );
        repository.upsert(updated);

        Instant expiresAt = now.plus(Duration.ofMinutes(putPresignTtlMinutes));
        return new PresignPutAssetResult(putUrl, key, expiresAt);
    }

    public PresignedGetAssetResult presignGetAsset(String frameId, String variant) {
        if (frameId == null || frameId.isBlank()) {
            throw new IllegalArgumentException("frameId is required");
        }

        Frame existing = repository.findById(frameId.trim()).orElseThrow(() -> new FrameNotFoundException(frameId));
        String assetKey = null;
        if ("vertical".equalsIgnoreCase(variant)) {
            assetKey = existing.getVerticalAssetKey();
        } else if ("horizontal".equalsIgnoreCase(variant)) {
            assetKey = existing.getHorizontalAssetKey();
        }
        if (assetKey == null || assetKey.isBlank()) {
            throw new FrameAssetNotFoundException(frameId);
        }

        Instant now = Instant.now(clock);
        String url = presigner.presignGet(
                assetsBucket,
                assetKey,
                Duration.ofMinutes(getPresignTtlMinutes)
        ).toString();

        Instant expiresAt = now.plus(Duration.ofMinutes(getPresignTtlMinutes));
        return new PresignedGetAssetResult(url, expiresAt);
    }

    private static String assetKey(String frameId, String variant, String extension) {
        String ext = (extension == null || extension.isBlank()) ? "png" : extension.trim().toLowerCase();
        String v = (variant == null || variant.isBlank()) ? "vertical" : variant.trim().toLowerCase();
        return "frames/" + frameId + "/" + v + "." + ext;
    }

    private static String extensionForContentType(String contentType) {
        String ct = contentType != null ? contentType.trim().toLowerCase() : "";
        if (ct.contains("png")) return "png";
        if (ct.contains("jpeg")) return "jpg";
        if (ct.contains("jpg")) return "jpg";
        return "png";
    }

    private static String resolveActor(Authentication authentication) {
        String actor;
        try {
            actor = AuthClaims.requireEmail(authentication);
        } catch (Exception ignored) {
            actor = authentication != null ? authentication.getName() : "unknown";
        }
        return actor;
    }

    public record PresignPutAssetResult(String putUrl, String assetKey, Instant expiresAt) {
    }

    public record PresignedGetAssetResult(String url, Instant expiresAt) {
    }
}
