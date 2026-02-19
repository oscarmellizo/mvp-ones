package com.ones.api.application.events;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.ones.api.adapters.outbound.dynamodb.DynamoCoverPreviewItem;
import com.ones.api.adapters.outbound.dynamodb.DynamoCoverReservationItem;
import com.ones.api.adapters.outbound.dynamodb.DynamoDbCoverPreviewsRepository;
import com.ones.api.adapters.outbound.dynamodb.DynamoDbCoverReservationsRepository;
import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.domain.events.Event;

import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.CopyObjectRequest;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;
import software.amazon.awssdk.services.secretsmanager.SecretsManagerClient;
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueRequest;

@Service
public class EventCoversService {

    private final EventsRepository eventsRepository;
    private final DynamoDbCoverPreviewsRepository previewsRepository;
    private final DynamoDbCoverReservationsRepository reservationsRepository;
    private final OpenAiImagesClient openAiImagesClient;
    private final SecretsManagerClient secretsManagerClient;
    private final S3Client s3Client;
    private final S3Presigner s3Presigner;
    private final Clock clock;

    private final String openAiApiKeySecretName;
    private final String openAiImageSize;
    private final String tempBucket;
    private final String finalBucket;
    private final long previewPresignTtlMinutes;
    private final long finalPresignTtlMinutes;
    private final long reservationTtlMinutes;

    public EventCoversService(
            EventsRepository eventsRepository,
            DynamoDbCoverPreviewsRepository previewsRepository,
            DynamoDbCoverReservationsRepository reservationsRepository,
            OpenAiImagesClient openAiImagesClient,
            SecretsManagerClient secretsManagerClient,
            S3Client s3Client,
            S3Presigner s3Presigner,
            Clock clock,
            @Value("${ones.ai.openai.api-key-secret-name}") String openAiApiKeySecretName,
            @Value("${ones.ai.openai.image-size:512x512}") String openAiImageSize,
            @Value("${ones.s3.events.covers.temp-bucket}") String tempBucket,
            @Value("${ones.s3.events.covers.final-bucket}") String finalBucket,
            @Value("${ones.s3.events.covers.preview-presign-ttl-minutes:15}") long previewPresignTtlMinutes,
            @Value("${ones.s3.events.covers.final-presign-ttl-minutes:15}") long finalPresignTtlMinutes,
            @Value("${ones.s3.events.covers.reservation-ttl-minutes:30}") long reservationTtlMinutes
    ) {
        this.eventsRepository = eventsRepository;
        this.previewsRepository = previewsRepository;
        this.reservationsRepository = reservationsRepository;
        this.openAiImagesClient = openAiImagesClient;
        this.secretsManagerClient = secretsManagerClient;
        this.s3Client = s3Client;
        this.s3Presigner = s3Presigner;
        this.clock = clock;
        this.openAiApiKeySecretName = openAiApiKeySecretName;
        this.openAiImageSize = openAiImageSize;
        this.tempBucket = tempBucket;
        this.finalBucket = finalBucket;
        this.previewPresignTtlMinutes = previewPresignTtlMinutes;
        this.finalPresignTtlMinutes = finalPresignTtlMinutes;
        this.reservationTtlMinutes = reservationTtlMinutes;
    }

    public GenerateCoverResult generatePreview(
            String ownerId,
            String eventName,
            String categoryLabel,
            String eventTypeLabel,
            String location,
            String size
    ) {
        String coverId = UUID.randomUUID().toString();
        Instant now = Instant.now(clock);

        String prompt = buildPrompt(eventName, categoryLabel, eventTypeLabel, location);
        String resolvedSize = (size == null || size.isBlank()) ? openAiImageSize : size.trim();

        String apiKey = loadOpenAiApiKey();
        byte[] png = openAiImagesClient.generatePng(apiKey, prompt, resolvedSize);

        String key = tempKey(ownerId, coverId);
        PutObjectRequest put = PutObjectRequest.builder()
                .bucket(tempBucket)
                .key(key)
                .contentType("image/png")
                .build();
        s3Client.putObject(put, RequestBody.fromBytes(png));

        previewsRepository.save(coverId, ownerId, now, tempBucket, key);

        Instant expiresAt = now.plus(previewPresignTtlMinutes, ChronoUnit.MINUTES);
        java.net.URL url = presignGet(tempBucket, key, previewPresignTtlMinutes);

        return new GenerateCoverResult(coverId, url.toString(), expiresAt);
    }

    public AcceptCoverResult accept(String ownerId, String coverId) {
        DynamoCoverPreviewItem preview = previewsRepository.findById(coverId)
                .filter(p -> ownerId.equals(p.getOwnerId()))
                .orElseThrow(() -> new CoverPreviewNotFoundException(coverId));

        Instant now = Instant.now(clock);
        Instant expiresAt = now.plus(reservationTtlMinutes, ChronoUnit.MINUTES);
        String reservationId = UUID.randomUUID().toString();

        reservationsRepository.save(
                reservationId,
                ownerId,
                now,
                expiresAt,
                preview.getTempBucket(),
                preview.getTempKey()
        );

        return new AcceptCoverResult(reservationId);
    }

    public void cancel(String ownerId, String coverId) {
        DynamoCoverPreviewItem preview = previewsRepository.findById(coverId)
                .filter(p -> ownerId.equals(p.getOwnerId()))
                .orElseThrow(() -> new CoverPreviewNotFoundException(coverId));

        try {
            s3Client.deleteObject(DeleteObjectRequest.builder()
                    .bucket(preview.getTempBucket())
                    .key(preview.getTempKey())
                    .build());
        } catch (Exception ignored) {
        }

        previewsRepository.deleteById(coverId);
    }

    public String consumeReservationAndCopyToEvent(String ownerId, String reservationId, String eventId) {
        DynamoCoverReservationItem reservation = reservationsRepository.findById(reservationId)
                .filter(r -> ownerId.equals(r.getOwnerId()))
                .orElseThrow(() -> new CoverReservationNotFoundException(reservationId));

        Instant expiresAt = Instant.parse(reservation.getExpiresAt());
        Instant now = Instant.now(clock);
        if (now.isAfter(expiresAt)) {
            reservationsRepository.deleteById(reservationId);
            throw new CoverReservationExpiredException(reservationId);
        }

        String destKey = finalKey(eventId);

        s3Client.copyObject(CopyObjectRequest.builder()
                .copySource(reservation.getTempBucket() + "/" + reservation.getTempKey())
                .destinationBucket(finalBucket)
                .destinationKey(destKey)
                .build());

        try {
            s3Client.deleteObject(DeleteObjectRequest.builder()
                    .bucket(reservation.getTempBucket())
                    .key(reservation.getTempKey())
                    .build());
        } catch (Exception ignored) {
        }

        reservationsRepository.deleteById(reservationId);

        return destKey;
    }

    public PresignedUrlResult getFinalCoverUrl(String coverKey) {
        Instant now = Instant.now(clock);
        Instant expiresAt = now.plus(finalPresignTtlMinutes, ChronoUnit.MINUTES);
        java.net.URL url = presignGet(finalBucket, coverKey, finalPresignTtlMinutes);
        return new PresignedUrlResult(url.toString(), expiresAt);
    }

    public String getCoverKeyForEvent(String ownerId, String eventId) {
        Event event = eventsRepository.findById(eventId)
                .filter(e -> ownerId.equals(e.getOwnerId()))
                .orElseThrow(() -> new EventNotFoundException(eventId));

        String coverKey = event.getCoverKey();
        if (coverKey == null || coverKey.isBlank()) {
            throw new EventCoverNotFoundException(eventId);
        }
        return coverKey;
    }

    private java.net.URL presignGet(String bucket, String key, long ttlMinutes) {
        software.amazon.awssdk.services.s3.model.GetObjectRequest get = software.amazon.awssdk.services.s3.model.GetObjectRequest.builder()
                .bucket(bucket)
                .key(key)
                .build();

        GetObjectPresignRequest presignRequest = GetObjectPresignRequest.builder()
                .signatureDuration(java.time.Duration.ofMinutes(ttlMinutes))
                .getObjectRequest(get)
                .build();

        return s3Presigner.presignGetObject(presignRequest).url();
    }

    private String loadOpenAiApiKey() {
        return secretsManagerClient.getSecretValue(
                        GetSecretValueRequest.builder().secretId(openAiApiKeySecretName).build())
                .secretString();
    }

    private static String buildPrompt(String eventName, String categoryLabel, String eventTypeLabel, String location) {
        return "Create a minimal, modern, high-quality event cover image. " +
                "The event is named '" + safe(eventName) + "'. " +
                "Category: '" + safe(categoryLabel) + "'. " +
                "Event type: '" + safe(eventTypeLabel) + "'. " +
                "Location: '" + safe(location) + "'. " +
                "No text. Clean composition. Use vibrant but tasteful colors. Suitable as a square thumbnail.";
    }

    private static String safe(String value) {
        return value == null ? "" : value.trim();
    }

    private static String tempKey(String ownerId, String coverId) {
        return "tmp/events/covers/" + ownerId + "/" + coverId + ".png";
    }

    private static String finalKey(String eventId) {
        return "events/" + eventId + "/cover/cover.png";
    }

    public record GenerateCoverResult(String coverId, String previewUrl, Instant expiresAt) {
    }

    public record AcceptCoverResult(String reservationId) {
    }

    public record PresignedUrlResult(String url, Instant expiresAt) {
    }
}
