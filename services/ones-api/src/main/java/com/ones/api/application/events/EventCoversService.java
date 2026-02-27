package com.ones.api.application.events;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.application.events.ports.CoverPreviewsRepository;
import com.ones.api.application.events.ports.CoverReservationsRepository;
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
    private final CoverPreviewsRepository previewsRepository;
    private final CoverReservationsRepository reservationsRepository;
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
            CoverPreviewsRepository previewsRepository,
            CoverReservationsRepository reservationsRepository,
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
            String objective,
            String location,
            String size
    ) {
        String coverId = UUID.randomUUID().toString();
        Instant now = Instant.now(clock);

        String prompt = buildPrompt(eventName, objective, location);
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
        CoverPreviewsRepository.CoverPreview preview = previewsRepository.findById(coverId)
                .filter(p -> ownerId.equals(p.ownerId()))
                .orElseThrow(() -> new CoverPreviewNotFoundException(coverId));

        Instant now = Instant.now(clock);
        Instant expiresAt = now.plus(reservationTtlMinutes, ChronoUnit.MINUTES);
        String reservationId = UUID.randomUUID().toString();

        reservationsRepository.save(
                reservationId,
                ownerId,
                now,
                expiresAt,
                preview.tempBucket(),
                preview.tempKey()
        );

        return new AcceptCoverResult(reservationId);
    }

    public void cancel(String ownerId, String coverId) {
        CoverPreviewsRepository.CoverPreview preview = previewsRepository.findById(coverId)
                .filter(p -> ownerId.equals(p.ownerId()))
                .orElseThrow(() -> new CoverPreviewNotFoundException(coverId));

        try {
            s3Client.deleteObject(DeleteObjectRequest.builder()
                    .bucket(preview.tempBucket())
                    .key(preview.tempKey())
                    .build());
        } catch (Exception ignored) {
        }

        previewsRepository.deleteById(coverId);
    }

    public String consumeReservationAndCopyToEvent(String ownerId, String reservationId, String eventId) {
        CoverReservationsRepository.CoverReservation reservation = reservationsRepository.findById(reservationId)
                .filter(r -> ownerId.equals(r.ownerId()))
                .orElseThrow(() -> new CoverReservationNotFoundException(reservationId));

        Instant expiresAt = reservation.expiresAt();
        Instant now = Instant.now(clock);
        if (now.isAfter(expiresAt)) {
            reservationsRepository.deleteById(reservationId);
            throw new CoverReservationExpiredException(reservationId);
        }

        String destKey = finalKey(eventId);

        s3Client.copyObject(CopyObjectRequest.builder()
                .copySource(reservation.tempBucket() + "/" + reservation.tempKey())
                .destinationBucket(finalBucket)
                .destinationKey(destKey)
                .build());

        try {
            s3Client.deleteObject(DeleteObjectRequest.builder()
                    .bucket(reservation.tempBucket())
                    .key(reservation.tempKey())
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

    private static String buildPrompt(String eventName, String objective, String location) {
        String name = safe(eventName);
        String obj = safe(objective);
        String loc = safe(location);

        String theme = inferTheme(obj, name);
        String iconConcept = inferIconConcept(obj, name);
        String palette = inferPalette(obj);
        String composition = "horizontal cover banner layout with one clear focal element, plenty of negative space, simple shapes, and clean margins";

        String locationHint = loc.isBlank()
                ? ""
                : "Subtle location context inspired by '" + loc + "' as environment/venue style only (do not render text). ";

        return "Create a promotional event cover image (horizontal landscape banner 16:9). " +
                "The event is: '" + name + "'. " +
                "Description: '" + obj + "'. " +
                locationHint +
                "Theme: " + theme + ". " +
                "Key visual elements: " + iconConcept + ". " +
                "Color palette: " + palette + ". " +
                "Composition: " + composition + ". " +
                "Style: modern graphic design poster, premium promotional look, crisp details, subtle depth, clean layout. " +
                "Keep it simple and to the point: limit the design to 1 main subject plus at most 2 supporting decorative elements. Avoid busy patterns or many objects. " +
                "Background may be a subtle themed backdrop (can be scene-like), but it must remain soft and uncluttered so the event reads clearly at a glance. " +
                "Do NOT make it look like a logo or icon; it should feel like a clean promotional cover image. " +
                "Compose with safe margins (leave room for potential UI overlays). " +
                "Constraints: no watermarks, no brand logos, no UI. Avoid readable text (no words, no letters, no numbers).";
    }

    private static String inferTheme(String objective, String eventName) {
        String o = (objective == null ? "" : objective).toLowerCase();
        String n = (eventName == null ? "" : eventName).toLowerCase();

        String all = (o + " " + n).trim();

        if (containsAny(all, "cumple", "birthday", "aniversario")) {
            return "birthday celebration";
        }
        if (containsAny(all, "boda", "wedding", "matrimonio")) {
            return "wedding celebration";
        }
        if (containsAny(all, "concierto", "concert", "festival", "dj", "musica", "music")) {
            return "music event";
        }
        if (containsAny(all, "corpor", "empresa", "business", "convenci", "network")) {
            return "professional corporate event";
        }
        if (containsAny(all, "infantil", "kids", "niñ", "child", "school")) {
            return "kids-friendly celebration";
        }
        if (containsAny(all, "deport", "match", "futbol", "football", "soccer", "basket")) {
            return "sports event";
        }
        if (containsAny(all, "baby", "gender reveal", "revelacion", "baby shower")) {
            return "baby shower / family celebration";
        }
        return "a social event";
    }

    private static String inferIconConcept(String objective, String eventName) {
        String o = (objective == null ? "" : objective).toLowerCase();
        String n = (eventName == null ? "" : eventName).toLowerCase();
        String all = (o + " " + n).trim();

        if (containsAny(all, "cumple", "birthday", "aniversario")) {
            return "a single birthday emblem: a stylized birthday cake with one candle and a balloon, isolated on clean background";
        }
        if (containsAny(all, "wedding", "boda", "matrimonio")) {
            return "a single wedding emblem: elegant intertwined rings with subtle floral accent, isolated on clean background";
        }
        if (containsAny(all, "concierto", "concert", "festival", "dj", "musica", "music")) {
            return "a single music emblem: a microphone or guitar pick icon rendered as a realistic emblem, isolated on clean background";
        }
        if (containsAny(all, "corpor", "empresa", "business", "convenci", "network")) {
            return "a single corporate emblem: a minimal geometric mark suggesting networking/connection nodes, realistic emblem, isolated";
        }
        if (containsAny(all, "infantil", "kids", "niñ", "child", "school")) {
            return "a single kids emblem: a playful party hat with confetti, realistic emblem, isolated";
        }
        if (containsAny(all, "deport", "match", "futbol", "football", "soccer", "basket")) {
            return "a single sports emblem: a ball icon (soccer/basket) rendered as a realistic emblem, isolated";
        }
        if (containsAny(all, "baby", "gender reveal", "revelacion", "baby shower")) {
            return "a single baby celebration emblem: a baby bottle or pacifier icon rendered as a realistic emblem, isolated";
        }
        return "a single modern emblem/icon that represents the objective, isolated on a clean background";
    }

    private static String inferPalette(String objective) {
        String o = (objective == null ? "" : objective).toLowerCase();

        if (containsAny(o, "wedding", "boda")) {
            return "soft whites, creams, gold accents";
        }
        if (containsAny(o, "concierto", "concert", "festival", "dj", "musica", "music")) {
            return "deep blacks with neon accents (purple/blue)";
        }
        if (containsAny(o, "corpor", "empresa", "business", "convenci", "network")) {
            return "neutral tones (charcoal, white) with subtle accent";
        }
        if (containsAny(o, "infantil", "kids", "niñ", "child", "cumple", "birthday")) {
            return "bright but balanced colors (pastels with a few vibrant accents)";
        }
        return "vibrant but tasteful colors";
    }

    private static boolean containsAny(String haystack, String... needles) {
        if (haystack == null || haystack.isBlank()) {
            return false;
        }
        String h = haystack.toLowerCase();
        for (String n : needles) {
            if (n == null || n.isBlank()) continue;
            if (h.contains(n.toLowerCase())) return true;
        }
        return false;
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
