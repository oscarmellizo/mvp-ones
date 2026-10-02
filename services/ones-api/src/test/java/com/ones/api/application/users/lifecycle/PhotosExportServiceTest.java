package com.ones.api.application.users.lifecycle;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.application.events.ports.ObjectStorage;
import com.ones.api.application.photos.ports.PhotosRepository;
import com.ones.api.application.photos.ports.PhotosRepository.PageResult;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.photos.Photo;

class PhotosExportServiceTest {

    private static final Instant NOW = Instant.parse("2026-01-01T00:00:00Z");

    // Fakes en memoria sobre los puertos (mocks con comportamiento real).
    private final List<Event> eventList = new ArrayList<>();
    private final List<Photo> photoList = new ArrayList<>();
    private final Map<String, byte[]> objects = new HashMap<>();
    private final Map<String, byte[]> uploaded = new HashMap<>();
    private PhotosExportService service;

    @BeforeEach
    void setUp() throws Exception {
        EventsRepository events = mock(EventsRepository.class);
        when(events.listByOwnerId(anyString(), anyInt())).thenAnswer(inv ->
                eventList.stream().filter(e -> e.getOwnerId().equals(inv.getArgument(0))).toList());

        PhotosRepository photos = mock(PhotosRepository.class);
        when(photos.listByEventId(anyString(), anyInt(), any())).thenAnswer(inv ->
                new PageResult<>(photoList.stream().filter(p -> p.getEventId().equals(inv.getArgument(0))).toList(), null));
        when(photos.listByGuestId(anyString(), anyInt(), any())).thenAnswer(inv ->
                new PageResult<>(photoList.stream().filter(p -> p.getGuestId().equals(inv.getArgument(0))).toList(), null));

        ObjectStorage storage = mock(ObjectStorage.class);
        when(storage.open(anyString(), anyString())).thenAnswer(inv -> {
            byte[] data = objects.get(inv.getArgument(0) + "/" + inv.getArgument(1));
            if (data == null) throw new IllegalStateException("no existe");
            if (data.length == 0) { // objeto que falla a mitad de lectura
                return new java.io.InputStream() {
                    int n = 0;
                    @Override public int read() throws IOException {
                        if (n++ < 3) return 'x';
                        throw new IOException("corte de red");
                    }
                };
            }
            return new ByteArrayInputStream(data);
        });
        org.mockito.Mockito.doAnswer(inv -> {
            uploaded.put(inv.getArgument(0) + "/" + inv.getArgument(1), Files.readAllBytes(inv.<Path>getArgument(2)));
            return null;
        }).when(storage).putFile(anyString(), anyString(), any(Path.class), anyString());

        service = new PhotosExportService(events, photos, storage, "photos", "exports");
    }

    private static Event event(String id, String owner, String title) {
        return new Event(id, owner, NOW, title, "o", "l", NOW, NOW.plusSeconds(60), null, true, true, List.of());
    }

    private static Photo photo(String id, String eventId, String guest) {
        String base = "eventos/" + eventId + "/guests/" + guest + "/private/" + id;
        return new Photo(id, eventId, guest, NOW, NOW, "uploaded", base + ".jpg", base + "_m.jpg", base + "_s.jpg");
    }

    private void withObject(Photo p, String content) {
        photoList.add(p);
        objects.put("photos/" + p.getS3KeyOriginal(), content.getBytes());
    }

    private static Set<String> zipEntryFileNames(byte[] zip) throws IOException {
        Set<String> names = new java.util.HashSet<>();
        try (ZipInputStream in = new ZipInputStream(new ByteArrayInputStream(zip))) {
            ZipEntry e;
            while ((e = in.getNextEntry()) != null) {
                String n = e.getName();
                names.add(n.substring(n.lastIndexOf('/') + 1));
                new ByteArrayOutputStream().writeBytes(in.readAllBytes());
            }
        }
        return names;
    }

    @Test
    void export_includesOwnedEventPhotosAndOwnUploadsElsewhere_once() throws Exception {
        eventList.add(event("e1", "u1", "Boda Ana"));
        withObject(photo("p1", "e1", "u1"), "a"); // propia en su evento (aparece por evento y por invitado)
        withObject(photo("p2", "e1", "guest"), "b"); // de un invitado en su evento
        withObject(photo("p3", "e9", "u1"), "c"); // subida en evento ajeno

        Optional<String> key = service.export("u1");

        assertEquals(Optional.of("exports/u1/ones-fotos.zip"), key);
        assertEquals(Set.of("p1.jpg", "p2.jpg", "p3.jpg"),
                zipEntryFileNames(uploaded.get("exports/exports/u1/ones-fotos.zip")));
    }

    @Test
    void export_noPhotos_returnsEmpty_andUploadsNothing() {
        assertTrue(service.export("u1").isEmpty());
        assertTrue(uploaded.isEmpty());
    }

    @Test
    void export_skipsMissingObjects() {
        photoList.add(photo("p1", "e9", "u1")); // sin objeto en S3
        eventList.add(event("e9", "other", "Otro"));
        assertTrue(service.export("u1").isEmpty());
        assertTrue(uploaded.isEmpty());
    }

    @Test
    void export_skipsPhotoWhoseReadFailsMidway_withoutTruncatedEntry() throws Exception {
        withObject(photo("bad", "e1", "u1"), ""); // vacío = stream que falla tras 3 bytes
        withObject(photo("good", "e1", "u1"), "bytes-buenos");

        assertEquals(Optional.of("exports/u1/ones-fotos.zip"), service.export("u1"));

        try (ZipInputStream in = new ZipInputStream(new ByteArrayInputStream(uploaded.get("exports/exports/u1/ones-fotos.zip")))) {
            ZipEntry e = in.getNextEntry();
            assertEquals("e1/good.jpg", e.getName());
            assertEquals("bytes-buenos", new String(in.readAllBytes()));
            assertEquals(null, in.getNextEntry());
        }
    }
}
