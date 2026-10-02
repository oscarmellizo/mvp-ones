package com.ones.api.application.users.lifecycle;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;
import java.util.function.Function;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.application.events.ports.ObjectStorage;
import com.ones.api.application.photos.ports.PhotosRepository;
import com.ones.api.application.photos.ports.PhotosRepository.PageResult;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.photos.Photo;

/** Genera un ZIP con las fotos de la cuenta (de sus eventos y las que subió a otros) y lo sube al bucket de exportaciones. */
@Service
public class PhotosExportService {

    private static final Logger log = LoggerFactory.getLogger(PhotosExportService.class);

    // Tope de eventos por cuenta: hoy no existe una cuenta con más de 200 eventos.
    private static final int MAX_EVENTS = 200;

    private final EventsRepository eventsRepository;
    private final PhotosRepository photosRepository;
    private final ObjectStorage objectStorage;
    private final String photosBucket;
    private final String exportsBucket;

    public PhotosExportService(
            EventsRepository eventsRepository,
            PhotosRepository photosRepository,
            ObjectStorage objectStorage,
            @Value("${ones.s3.events.photos.bucket}") String photosBucket,
            @Value("${ones.account.exports-bucket:}") String exportsBucket) {
        this.eventsRepository = eventsRepository;
        this.photosRepository = photosRepository;
        this.objectStorage = objectStorage;
        this.photosBucket = photosBucket;
        this.exportsBucket = exportsBucket;
    }

    /** Devuelve la clave del ZIP subido, o vacío si no había fotos que exportar. */
    public Optional<String> export(String userId) {
        Map<String, Photo> byId = new LinkedHashMap<>();
        for (Event e : eventsRepository.listByOwnerId(userId, MAX_EVENTS)) {
            collect(byId, next -> photosRepository.listByEventId(e.getEventId(), 100, next));
        }
        collect(byId, next -> photosRepository.listByGuestId(userId, 100, next));

        try {
            Path tmp = Files.createTempFile("ones-export-", ".zip");
            try {
                int written = 0;
                // Se escribe a disco (no a memoria): una cuenta puede tener miles de fotos.
                try (ZipOutputStream zip = new ZipOutputStream(Files.newOutputStream(tmp))) {
                    for (Photo p : byId.values()) {
                        // El stream se abre antes de putNextEntry: si el objeto no existe no queda entrada vacía.
                        try (InputStream in = objectStorage.open(photosBucket, p.getS3KeyOriginal())) {
                            zip.putNextEntry(new ZipEntry(p.getEventId() + "/" + p.getPhotoId() + ".jpg"));
                            in.transferTo(zip);
                            zip.closeEntry();
                            written++;
                        } catch (Exception ex) {
                            log.warn("[PhotosExportService] foto omitida photoId={} err={}", p.getPhotoId(), ex.toString());
                        }
                    }
                }
                if (written == 0) return Optional.empty();
                String key = "exports/" + userId + "/ones-fotos.zip";
                objectStorage.putFile(exportsBucket, key, tmp, "application/zip");
                return Optional.of(key);
            } finally {
                Files.deleteIfExists(tmp);
            }
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    private static void collect(Map<String, Photo> byId, Function<String, PageResult<Photo>> page) {
        String next = null;
        do {
            PageResult<Photo> r = page.apply(next);
            for (Photo p : r.items()) byId.putIfAbsent(p.getPhotoId(), p);
            next = r.nextToken();
        } while (next != null && !next.isBlank());
    }
}
