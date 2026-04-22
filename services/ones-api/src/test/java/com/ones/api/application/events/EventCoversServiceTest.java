package com.ones.api.application.events;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.net.URL;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.Test;

import com.ones.api.application.events.ports.AiImagesClient;
import com.ones.api.application.events.ports.CoverPreviewsRepository;
import com.ones.api.application.events.ports.CoverReservationsRepository;
import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.application.events.ports.ObjectStorage;
import com.ones.api.application.events.ports.ObjectStoragePresigner;
import com.ones.api.application.events.ports.SecretsProvider;
import com.ones.api.domain.events.Event;

class EventCoversServiceTest {

    @Test
    void generatePreview_persistsPreviewAndUploadsToTempAndReturnsPresignedUrl() throws Exception {
        InMemoryEventsRepository events = new InMemoryEventsRepository();
        InMemoryCoverPreviewsRepository previews = new InMemoryCoverPreviewsRepository();
        InMemoryCoverReservationsRepository reservations = new InMemoryCoverReservationsRepository();
        FakeAiImagesClient ai = new FakeAiImagesClient();
        FakeSecretsProvider secrets = new FakeSecretsProvider("k");
        InMemoryObjectStorage storage = new InMemoryObjectStorage();
        FakePresigner presigner = new FakePresigner(new URL("https://example.com/p"));
        Clock clock = Clock.fixed(Instant.parse("2026-01-01T00:00:00Z"), ZoneOffset.UTC);

        EventCoversService svc = new EventCoversService(
                events,
                previews,
                reservations,
                ai,
                secrets,
                storage,
                presigner,
                clock,
                "secret",
                "512x512",
                "tmp-bucket",
                "final-bucket",
                15,
                15,
                30
        );

        EventCoversService.GenerateCoverResult out = svc.generatePreview(
                "owner-1",
                "Party",
                "birthday",
                "San Jose",
                null
        );

        assertNotNull(out.coverId());
        assertEquals("https://example.com/p", out.previewUrl());
        assertEquals(Instant.parse("2026-01-01T00:15:00Z"), out.expiresAt());

        CoverPreviewsRepository.CoverPreview saved = previews.findById(out.coverId()).orElseThrow();
        assertEquals("owner-1", saved.ownerId());
        assertEquals("tmp-bucket", saved.tempBucket());
        assertEquals(true, storage.hasObject("tmp-bucket", saved.tempKey()));
    }

    @Test
    void accept_createsReservationForOwner() {
        InMemoryEventsRepository events = new InMemoryEventsRepository();
        InMemoryCoverPreviewsRepository previews = new InMemoryCoverPreviewsRepository();
        InMemoryCoverReservationsRepository reservations = new InMemoryCoverReservationsRepository();
        FakeAiImagesClient ai = new FakeAiImagesClient();
        FakeSecretsProvider secrets = new FakeSecretsProvider("k");
        InMemoryObjectStorage storage = new InMemoryObjectStorage();
        FakePresigner presigner = new FakePresigner(null);
        Clock clock = Clock.fixed(Instant.parse("2026-01-01T00:00:00Z"), ZoneOffset.UTC);

        EventCoversService svc = new EventCoversService(
                events,
                previews,
                reservations,
                ai,
                secrets,
                storage,
                presigner,
                clock,
                "secret",
                "512x512",
                "tmp-bucket",
                "final-bucket",
                15,
                15,
                30
        );

        previews.save("cover-1", "owner-1", Instant.now(clock), "tmp-bucket", "tmp/events/covers/owner-1/cover-1.png");

        EventCoversService.AcceptCoverResult out = svc.accept("owner-1", "cover-1");
        assertNotNull(out.reservationId());

        CoverReservationsRepository.CoverReservation r = reservations.findById(out.reservationId()).orElseThrow();
        assertEquals("owner-1", r.ownerId());
        assertEquals("tmp-bucket", r.tempBucket());
    }

    @Test
    void cancel_deletesTempObjectAndPreviewRecord() {
        InMemoryEventsRepository events = new InMemoryEventsRepository();
        InMemoryCoverPreviewsRepository previews = new InMemoryCoverPreviewsRepository();
        InMemoryCoverReservationsRepository reservations = new InMemoryCoverReservationsRepository();
        FakeAiImagesClient ai = new FakeAiImagesClient();
        FakeSecretsProvider secrets = new FakeSecretsProvider("k");
        InMemoryObjectStorage storage = new InMemoryObjectStorage();
        FakePresigner presigner = new FakePresigner(null);
        Clock clock = Clock.fixed(Instant.parse("2026-01-01T00:00:00Z"), ZoneOffset.UTC);

        EventCoversService svc = new EventCoversService(
                events,
                previews,
                reservations,
                ai,
                secrets,
                storage,
                presigner,
                clock,
                "secret",
                "512x512",
                "tmp-bucket",
                "final-bucket",
                15,
                15,
                30
        );

        previews.save("cover-1", "owner-1", Instant.now(clock), "tmp-bucket", "k1");
        storage.putPng("tmp-bucket", "k1", new byte[]{1});

        svc.cancel("owner-1", "cover-1");

        assertEquals(Optional.empty(), previews.findById("cover-1"));
        assertEquals(false, storage.hasObject("tmp-bucket", "k1"));
    }

    @Test
    void consumeReservation_whenExpired_deletesReservationAndThrows() {
        InMemoryEventsRepository events = new InMemoryEventsRepository();
        InMemoryCoverPreviewsRepository previews = new InMemoryCoverPreviewsRepository();
        InMemoryCoverReservationsRepository reservations = new InMemoryCoverReservationsRepository();
        FakeAiImagesClient ai = new FakeAiImagesClient();
        FakeSecretsProvider secrets = new FakeSecretsProvider("k");
        InMemoryObjectStorage storage = new InMemoryObjectStorage();
        FakePresigner presigner = new FakePresigner(null);
        Clock clock = Clock.fixed(Instant.parse("2026-01-01T01:00:00Z"), ZoneOffset.UTC);

        EventCoversService svc = new EventCoversService(
                events,
                previews,
                reservations,
                ai,
                secrets,
                storage,
                presigner,
                clock,
                "secret",
                "512x512",
                "tmp-bucket",
                "final-bucket",
                15,
                15,
                30
        );

        reservations.save(
                "res-1",
                "owner-1",
                Instant.parse("2026-01-01T00:00:00Z"),
                Instant.parse("2026-01-01T00:30:00Z"),
                "tmp-bucket",
                "k1"
        );

        assertThrows(CoverReservationExpiredException.class, () -> svc.consumeReservationAndCopyToEvent("owner-1", "res-1", "event-1"));
        assertEquals(Optional.empty(), reservations.findById("res-1"));
    }

    @Test
    void consumeReservation_whenValid_copiesToFinalBucketDeletesTempAndReservationAndReturnsFinalKey() {
        InMemoryEventsRepository events = new InMemoryEventsRepository();
        InMemoryCoverPreviewsRepository previews = new InMemoryCoverPreviewsRepository();
        InMemoryCoverReservationsRepository reservations = new InMemoryCoverReservationsRepository();
        FakeAiImagesClient ai = new FakeAiImagesClient();
        FakeSecretsProvider secrets = new FakeSecretsProvider("k");
        InMemoryObjectStorage storage = new InMemoryObjectStorage();
        FakePresigner presigner = new FakePresigner(null);
        Clock clock = Clock.fixed(Instant.parse("2026-01-01T00:10:00Z"), ZoneOffset.UTC);

        EventCoversService svc = new EventCoversService(
                events,
                previews,
                reservations,
                ai,
                secrets,
                storage,
                presigner,
                clock,
                "secret",
                "512x512",
                "tmp-bucket",
                "final-bucket",
                15,
                15,
                30
        );

        storage.putPng("tmp-bucket", "k1", new byte[]{1, 2});
        reservations.save(
                "res-1",
                "owner-1",
                Instant.parse("2026-01-01T00:00:00Z"),
                Instant.parse("2026-01-01T00:30:00Z"),
                "tmp-bucket",
                "k1"
        );

        String key = svc.consumeReservationAndCopyToEvent("owner-1", "res-1", "event-123");
        assertEquals("events/event-123/cover/cover.png", key);
        assertEquals(true, storage.hasObject("final-bucket", key));
        assertEquals(false, storage.hasObject("tmp-bucket", "k1"));
        assertEquals(Optional.empty(), reservations.findById("res-1"));
    }

    @Test
    void getCoverKeyForEvent_whenMissingCoverKey_throws() {
        InMemoryEventsRepository events = new InMemoryEventsRepository();
        InMemoryCoverPreviewsRepository previews = new InMemoryCoverPreviewsRepository();
        InMemoryCoverReservationsRepository reservations = new InMemoryCoverReservationsRepository();
        FakeAiImagesClient ai = new FakeAiImagesClient();
        FakeSecretsProvider secrets = new FakeSecretsProvider("k");
        InMemoryObjectStorage storage = new InMemoryObjectStorage();
        FakePresigner presigner = new FakePresigner(null);
        Clock clock = Clock.fixed(Instant.parse("2026-01-01T00:00:00Z"), ZoneOffset.UTC);

        events.save(new Event(
                "event-1",
                "owner-1",
                Instant.parse("2026-01-01T00:00:00Z"),
                "t",
                "o",
                "l",
                Instant.parse("2026-01-01T00:00:00Z"),
                Instant.parse("2026-01-01T01:00:00Z"),
                null,
                true,
                java.util.List.of()
        ));

        EventCoversService svc = new EventCoversService(
                events,
                previews,
                reservations,
                ai,
                secrets,
                storage,
                presigner,
                clock,
                "secret",
                "512x512",
                "tmp-bucket",
                "final-bucket",
                15,
                15,
                30
        );

        assertThrows(EventCoverNotFoundException.class, () -> svc.getCoverKeyForEvent("owner-1", "event-1"));
    }

    private static class FakeAiImagesClient implements AiImagesClient {
        @Override
        public byte[] generatePng(String apiKey, String prompt, String size) {
            return new byte[]{1, 2, 3};
        }
    }

    private record FakeSecretsProvider(String value) implements SecretsProvider {
        @Override
        public String getSecretString(String secretName) {
            return value;
        }
    }

    private static class FakePresigner implements ObjectStoragePresigner {
        private final URL url;

        private FakePresigner(URL url) {
            this.url = url;
        }

        @Override
        public URL presignGet(String bucket, String key, Duration ttl) {
            return url;
        }

        @Override
        public URL presignPut(String bucket, String key, Duration ttl, String contentType) {
            return url;
        }
    }

    private static class InMemoryObjectStorage implements ObjectStorage {
        private final Map<String, byte[]> objects = new HashMap<>();

        @Override
        public void putPng(String bucket, String key, byte[] png) {
            objects.put(bucket + "/" + key, png);
        }

        @Override
        public void copy(String sourceBucket, String sourceKey, String destinationBucket, String destinationKey) {
            byte[] bytes = objects.get(sourceBucket + "/" + sourceKey);
            objects.put(destinationBucket + "/" + destinationKey, bytes);
        }

        @Override
        public void delete(String bucket, String key) {
            objects.remove(bucket + "/" + key);
        }

        boolean hasObject(String bucket, String key) {
            return objects.containsKey(bucket + "/" + key);
        }
    }

    private static class InMemoryCoverPreviewsRepository implements CoverPreviewsRepository {
        private final Map<String, CoverPreview> items = new HashMap<>();

        @Override
        public void save(String coverId, String ownerId, Instant createdAt, String tempBucket, String tempKey) {
            items.put(coverId, new CoverPreview(coverId, ownerId, createdAt, tempBucket, tempKey));
        }

        @Override
        public Optional<CoverPreview> findById(String coverId) {
            return Optional.ofNullable(items.get(coverId));
        }

        @Override
        public void deleteById(String coverId) {
            items.remove(coverId);
        }
    }

    private static class InMemoryCoverReservationsRepository implements CoverReservationsRepository {
        private final Map<String, CoverReservation> items = new HashMap<>();

        @Override
        public void save(String reservationId, String ownerId, Instant createdAt, Instant expiresAt, String tempBucket, String tempKey) {
            items.put(reservationId, new CoverReservation(reservationId, ownerId, createdAt, expiresAt, tempBucket, tempKey));
        }

        @Override
        public Optional<CoverReservation> findById(String reservationId) {
            return Optional.ofNullable(items.get(reservationId));
        }

        @Override
        public void deleteById(String reservationId) {
            items.remove(reservationId);
        }
    }

    private static class InMemoryEventsRepository implements EventsRepository {
        private final Map<String, Event> items = new HashMap<>();

        @Override
        public Event save(Event event) {
            items.put(event.getEventId(), event);
            return event;
        }

        @Override
        public Optional<Event> findById(String eventId) {
            return Optional.ofNullable(items.get(eventId));
        }

        @Override
        public java.util.List<Event> findByIds(java.util.List<String> eventIds) {
            if (eventIds == null || eventIds.isEmpty()) {
                return java.util.List.of();
            }
            return eventIds.stream()
                    .filter(id -> id != null && !id.isBlank())
                    .map(items::get)
                    .filter(e -> e != null)
                    .toList();
        }

        @Override
        public java.util.List<Event> listByOwnerId(String ownerId, int limit) {
            return items.values().stream().filter(e -> ownerId.equals(e.getOwnerId())).limit(limit).toList();
        }
    }
}
