package com.ones.api.application.events;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.application.events.ports.AiImagesClient;
import com.ones.api.application.events.ports.CoverPreviewsRepository;
import com.ones.api.application.events.ports.CoverReservationsRepository;
import com.ones.api.application.events.ports.ObjectStorage;
import com.ones.api.application.events.ports.ObjectStoragePresigner;
import com.ones.api.application.events.ports.SecretsProvider;
import com.ones.api.application.photos.ports.PhotosRepository;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.photos.Photo;

@Service
public class EventCoversService {

    private final EventsRepository eventsRepository;
    private final CoverPreviewsRepository previewsRepository;
    private final CoverReservationsRepository reservationsRepository;
    private final AiImagesClient aiImagesClient;
    private final SecretsProvider secretsProvider;
    private final ObjectStorage objectStorage;
    private final ObjectStoragePresigner objectStoragePresigner;
    private final Clock clock;
    private final PhotosRepository photosRepository;

    private final String openAiApiKeySecretName;
    private final String openAiImageSize;
    private final String tempBucket;
    private final String finalBucket;
    private final String photosBucket;
    private final long previewPresignTtlMinutes;
    private final long finalPresignTtlMinutes;
    private final long reservationTtlMinutes;

    @Autowired
    public EventCoversService(
            EventsRepository eventsRepository,
            CoverPreviewsRepository previewsRepository,
            CoverReservationsRepository reservationsRepository,
            AiImagesClient aiImagesClient,
            SecretsProvider secretsProvider,
            ObjectStorage objectStorage,
            ObjectStoragePresigner objectStoragePresigner,
            Clock clock,
            PhotosRepository photosRepository,
            @Value("${ones.ai.openai.api-key-secret-name}") String openAiApiKeySecretName,
            @Value("${ones.ai.openai.image-size:512x512}") String openAiImageSize,
            @Value("${ones.s3.events.covers.temp-bucket}") String tempBucket,
            @Value("${ones.s3.events.covers.final-bucket}") String finalBucket,
            @Value("${ones.s3.events.photos.bucket}") String photosBucket,
            @Value("${ones.s3.events.covers.preview-presign-ttl-minutes:15}") long previewPresignTtlMinutes,
            @Value("${ones.s3.events.covers.final-presign-ttl-minutes:15}") long finalPresignTtlMinutes,
            @Value("${ones.s3.events.covers.reservation-ttl-minutes:30}") long reservationTtlMinutes
    ) {
        this.eventsRepository = eventsRepository;
        this.previewsRepository = previewsRepository;
        this.reservationsRepository = reservationsRepository;
        this.aiImagesClient = aiImagesClient;
        this.secretsProvider = secretsProvider;
        this.objectStorage = objectStorage;
        this.objectStoragePresigner = objectStoragePresigner;
        this.clock = clock;
        this.photosRepository = photosRepository;
        this.openAiApiKeySecretName = openAiApiKeySecretName;
        this.openAiImageSize = openAiImageSize;
        this.tempBucket = tempBucket;
        this.finalBucket = finalBucket;
        this.photosBucket = photosBucket;
        this.previewPresignTtlMinutes = previewPresignTtlMinutes;
        this.finalPresignTtlMinutes = finalPresignTtlMinutes;
        this.reservationTtlMinutes = reservationTtlMinutes;
    }

    public EventCoversService(
            EventsRepository eventsRepository,
            CoverPreviewsRepository previewsRepository,
            CoverReservationsRepository reservationsRepository,
            AiImagesClient aiImagesClient,
            SecretsProvider secretsProvider,
            ObjectStorage objectStorage,
            ObjectStoragePresigner objectStoragePresigner,
            Clock clock,
            @Value("${ones.ai.openai.api-key-secret-name}") String openAiApiKeySecretName,
            @Value("${ones.ai.openai.image-size:512x512}") String openAiImageSize,
            @Value("${ones.s3.events.covers.temp-bucket}") String tempBucket,
            @Value("${ones.s3.events.covers.final-bucket}") String finalBucket,
            @Value("${ones.s3.events.covers.preview-presign-ttl-minutes:15}") long previewPresignTtlMinutes,
            @Value("${ones.s3.events.covers.final-presign-ttl-minutes:15}") long finalPresignTtlMinutes,
            @Value("${ones.s3.events.covers.reservation-ttl-minutes:30}") long reservationTtlMinutes
    ) {
        this(
                eventsRepository,
                previewsRepository,
                reservationsRepository,
                aiImagesClient,
                secretsProvider,
                objectStorage,
                objectStoragePresigner,
                clock,
                null,
                openAiApiKeySecretName,
                openAiImageSize,
                tempBucket,
                finalBucket,
                null,
                previewPresignTtlMinutes,
                finalPresignTtlMinutes,
                reservationTtlMinutes
        );
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
        byte[] png;
        try {
            png = aiImagesClient.generatePng(apiKey, prompt, resolvedSize);
        } catch (AiImageGenerationException e) {
            throw e;
        } catch (Exception e) {
            throw new AiImageGenerationException("Failed to generate AI cover image", e);
        }

        String key = tempKey(ownerId, coverId);
        objectStorage.putPng(tempBucket, key, png);

        previewsRepository.save(coverId, ownerId, now, tempBucket, key);

        Instant expiresAt = now.plus(previewPresignTtlMinutes, ChronoUnit.MINUTES);
        java.net.URL url = objectStoragePresigner.presignGet(
                tempBucket,
                key,
                java.time.Duration.ofMinutes(previewPresignTtlMinutes)
        );

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
            objectStorage.delete(preview.tempBucket(), preview.tempKey());
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

        objectStorage.copy(reservation.tempBucket(), reservation.tempKey(), finalBucket, destKey);

        try {
            objectStorage.delete(reservation.tempBucket(), reservation.tempKey());
        } catch (Exception ignored) {
        }

        reservationsRepository.deleteById(reservationId);

        return destKey;
    }

    public PresignedUrlResult getFinalCoverUrl(String coverKey) {
        Instant now = Instant.now(clock);
        Instant expiresAt = now.plus(finalPresignTtlMinutes, ChronoUnit.MINUTES);
        java.net.URL url = objectStoragePresigner.presignGet(
                finalBucket,
                coverKey,
                java.time.Duration.ofMinutes(finalPresignTtlMinutes)
        );
        return new PresignedUrlResult(url.toString(), expiresAt);
    }

    public PresignUploadResult presignUpload(String eventId, String contentType) {
        if (eventId == null || eventId.isBlank()) {
            throw new IllegalArgumentException("Missing eventId");
        }
        String ct = contentType == null ? "" : contentType.trim().toLowerCase();
        if (!(ct.equals("image/png") || ct.equals("image/jpeg") || ct.equals("image/jpg"))) {
            throw new IllegalArgumentException("Unsupported contentType: " + contentType);
        }

        String ext = ct.contains("png") ? ".png" : ".jpg";
        String key = "tmp/events/covers/uploads/" + eventId.trim() + "/" + UUID.randomUUID() + ext;

        Instant now = Instant.now(clock);
        Instant expiresAt = now.plus(previewPresignTtlMinutes, ChronoUnit.MINUTES);
        java.net.URL url = objectStoragePresigner.presignPut(
                tempBucket,
                key,
                java.time.Duration.ofMinutes(previewPresignTtlMinutes),
                ct
        );

        return new PresignUploadResult(url.toString(), key, expiresAt);
    }

    public String setCoverFromUpload(Event event, String uploadKey) {
        if (event == null) {
            throw new IllegalArgumentException("Missing event");
        }
        if (uploadKey == null || uploadKey.isBlank()) {
            throw new IllegalArgumentException("Missing uploadKey");
        }

        String normalizedKey = uploadKey.trim();
        String eid = event.getEventId();
        if (eid == null || eid.isBlank()) {
            throw new IllegalArgumentException("Invalid eventId");
        }

        // Simple guard: ensure the upload key belongs to this event uploads path
        if (!normalizedKey.contains("/" + eid + "/")) {
            throw new IllegalArgumentException("uploadKey does not belong to event");
        }

        String destKey = finalKey(eid);

        objectStorage.copy(tempBucket, normalizedKey, finalBucket, destKey);
        try {
            objectStorage.delete(tempBucket, normalizedKey);
        } catch (Exception ignored) {
        }

        Event updated = new Event(
                event.getEventId(),
                event.getOwnerId(),
                event.getCreatedAt(),
                event.getTitle(),
                event.getObjective(),
                event.getLocation(),
                event.getStartAt(),
                event.getEndAt(),
                destKey,
                event.isAllowGuestInvites(),
                event.isInviteLinkEnabled(),
                event.getFrameIds()
        );

        eventsRepository.save(updated);
        return destKey;
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

    public String setCoverFromPhoto(Event event, String photoId) {
        if (event == null) throw new IllegalArgumentException("Missing event");
        if (photoId == null || photoId.isBlank()) throw new IllegalArgumentException("Missing photoId");

        Photo p = photosRepository.findById(photoId.trim()).orElse(null);
        if (p == null || p.getEventId() == null || !p.getEventId().equals(event.getEventId())) {
            throw new IllegalArgumentException("Photo does not belong to event");
        }

        String sourceKey = p.getS3KeyMedium();
        String originalKey = p.getS3KeyOriginal();
        if ((sourceKey == null || sourceKey.isBlank()) && originalKey != null && !originalKey.isBlank()) {
            sourceKey = variantKeyFromOriginal(originalKey, "_m");
        }
        if (sourceKey == null || sourceKey.isBlank()) {
            // Fallback to small or original if medium not available
            String small = p.getS3KeySmall();
            if (small != null && !small.isBlank()) {
                sourceKey = small;
            } else {
                sourceKey = originalKey;
            }
        }
        if (sourceKey == null || sourceKey.isBlank()) {
            throw new IllegalStateException("Photo has no S3 keys available");
        }

        String destKey = finalKey(event.getEventId());
        objectStorage.copy(photosBucket, sourceKey.trim(), finalBucket, destKey);

        Event updated = new Event(
                event.getEventId(),
                event.getOwnerId(),
                event.getCreatedAt(),
                event.getTitle(),
                event.getObjective(),
                event.getLocation(),
                event.getStartAt(),
                event.getEndAt(),
                destKey,
                event.isAllowGuestInvites(),
                event.isInviteLinkEnabled(),
                event.getFrameIds()
        );
        eventsRepository.save(updated);
        return destKey;
    }

    private static String variantKeyFromOriginal(String originalKey, String suffix) {
        if (originalKey == null || originalKey.isBlank()) return null;
        String key = originalKey.trim();
        String sfx = suffix != null ? suffix : "";
        if (key.endsWith(".jpg")) return key.substring(0, key.length() - 4) + sfx + ".jpg";
        if (key.endsWith(".jpeg")) return key.substring(0, key.length() - 5) + sfx + ".jpeg";
        return key + sfx;
    }

    private String loadOpenAiApiKey() {
        if (openAiApiKeySecretName == null || openAiApiKeySecretName.isBlank()) {
            throw new AiConfigurationException("Missing OpenAI secret name configuration: ones.ai.openai.api-key-secret-name");
        }

        final String apiKey;
        try {
            apiKey = secretsProvider.getSecretString(openAiApiKeySecretName);
        } catch (Exception e) {
            throw new AiConfigurationException(
                    "Failed to load OpenAI API key from Secrets Manager: secretName=" + openAiApiKeySecretName,
                    e
            );
        }

        if (apiKey == null || apiKey.isBlank()) {
            throw new AiConfigurationException(
                    "OpenAI API key secret is empty: secretName=" + openAiApiKeySecretName
            );
        }
        return apiKey;
    }

    private static String buildPrompt(String eventName, String objective, String location) {
        String name = safe(eventName, 80);
        String obj = safe(objective, 240);
        String loc = safe(location, 80);

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
        return safe(value, 400);
    }

    private static String safe(String value, int maxChars) {
        if (value == null) return "";
        String v = value.trim();
        if (v.isEmpty()) return "";
        v = v.replaceAll("\\s+", " ");
        if (maxChars > 0 && v.length() > maxChars) {
            v = v.substring(0, maxChars);
        }
        return v;
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

    public record PresignUploadResult(String uploadUrl, String uploadKey, Instant expiresAt) {
    }
}
