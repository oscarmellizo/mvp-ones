package com.ones.api.application.users.lifecycle;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
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
import com.ones.api.application.events.ports.ObjectNotFoundException;
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
    private final List<CapturingUpload> uploads = new ArrayList<>();
    private boolean failZipWrites;

    /** Subida en streaming que guarda los bytes solo al completarse (close) y registra abort(). */
    private class CapturingUpload extends ObjectStorage.Upload {
        final String path;
        final ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        boolean aborted;
        boolean completed;

        CapturingUpload(String path) {
            this.path = path;
        }

        @Override
        public void write(int b) throws IOException {
            if (aborted || completed) throw new IOException("subida terminada");
            if (failZipWrites) throw new IOException("disco/red llena");
            bytes.write(b);
        }

        @Override
        public void write(byte[] b, int off, int len) throws IOException {
            if (aborted || completed) throw new IOException("subida terminada");
            if (failZipWrites) throw new IOException("disco/red llena");
            bytes.write(b, off, len);
        }

        @Override
        public void close() {
            if (aborted || completed) return;
            completed = true;
            uploaded.put(path, bytes.toByteArray());
        }

        @Override
        public void abort() {
            aborted = true;
        }
    }
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
            if (data == null) throw new ObjectNotFoundException(inv.getArgument(0), inv.getArgument(1));
            if (new String(data).equals("DENIED")) throw new IllegalStateException("AccessDenied (403)");
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
        when(storage.openUpload(anyString(), anyString(), anyString())).thenAnswer(inv -> {
            CapturingUpload u = new CapturingUpload(inv.getArgument(0) + "/" + inv.getArgument(1));
            uploads.add(u);
            return u;
        });

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
    void export_readFailingMidway_failsWholeExport_andAbortsUpload() {
        withObject(photo("good", "e1", "u1"), "bytes-buenos");
        withObject(photo("bad", "e1", "u1"), ""); // vacío = stream que falla tras 3 bytes

        assertThrows(RuntimeException.class, () -> service.export("u1"));

        assertTrue(uploaded.isEmpty());
        assertEquals(1, uploads.size());
        assertTrue(uploads.get(0).aborted);
    }

    @Test
    void export_nonNotFoundReadError_propagates_insteadOfReportingNoPhotos() {
        withObject(photo("p1", "e1", "u1"), "DENIED");

        assertThrows(IllegalStateException.class, () -> service.export("u1"));
        assertTrue(uploaded.isEmpty());
    }

    @Test
    void export_zipWriteError_propagates_andAbortsUpload() {
        withObject(photo("p1", "e1", "u1"), "a");
        failZipWrites = true;

        assertThrows(RuntimeException.class, () -> service.export("u1"));

        assertTrue(uploaded.isEmpty());
        assertTrue(uploads.get(0).aborted);
    }

    @Test
    void export_missingObjectAmongOthers_isSkipped_restIsStreamed() throws Exception {
        photoList.add(photo("gone", "e1", "u1")); // sin objeto en S3: NoSuchKey
        withObject(photo("good", "e1", "u1"), "bytes-buenos");

        assertEquals(Optional.of("exports/u1/ones-fotos.zip"), service.export("u1"));

        try (ZipInputStream in = new ZipInputStream(new ByteArrayInputStream(uploaded.get("exports/exports/u1/ones-fotos.zip")))) {
            ZipEntry e = in.getNextEntry();
            assertEquals("e1/good.jpg", e.getName());
            assertEquals("bytes-buenos", new String(in.readAllBytes()));
            assertEquals(null, in.getNextEntry());
        }
        assertTrue(uploads.get(0).completed);
    }
}
