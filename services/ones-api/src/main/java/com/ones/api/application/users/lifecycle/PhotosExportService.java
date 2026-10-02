package com.ones.api.application.users.lifecycle;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
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
import com.ones.api.application.events.ports.ObjectNotFoundException;
import com.ones.api.application.events.ports.ObjectStorage;
import com.ones.api.application.photos.ports.PhotosRepository;
import com.ones.api.application.photos.ports.PhotosRepository.PageResult;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.photos.Photo;

/**
 * Genera un ZIP con las fotos de la cuenta (de sus eventos y las que subió a otros) y lo sube en streaming al
 * bucket de exportaciones. Solo se omiten fotos cuyo original no existe; cualquier otro error se propaga.
 */
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

        String key = "exports/" + userId + "/ones-fotos.zip";
        ObjectStorage.Upload upload = null;
        ZipOutputStream zip = null;
        int written = 0;
        int skipped = 0;
        try {
            for (Photo p : byId.values()) {
                if (p.getS3KeyOriginal() == null || p.getS3KeyOriginal().isBlank()) {
                    skipped++;
                    continue;
                }
                // Se descarga completa a un temporal antes de tocar el ZIP: así nunca queda una entrada
                // truncada, y el ZIP se escribe directo a S3 (multipart) sin ocupar el disco de la tarea.
                Path photoTmp = Files.createTempFile("ones-export-photo-", ".jpg");
                try {
                    try (InputStream in = objectStorage.open(photosBucket, p.getS3KeyOriginal())) {
                        Files.copy(in, photoTmp, StandardCopyOption.REPLACE_EXISTING);
                    } catch (ObjectNotFoundException missing) {
                        // Solo un objeto que de verdad no existe se omite; cualquier otro error aborta la
                        // exportación y la cuenta se reintenta mañana.
                        skipped++;
                        log.warn("[PhotosExportService] foto sin original en S3, se omite photoId={}", p.getPhotoId());
                        continue;
                    }
                    if (zip == null) {
                        upload = objectStorage.openUpload(exportsBucket, key, "application/zip");
                        zip = new ZipOutputStream(upload);
                    }
                    zip.putNextEntry(new ZipEntry(p.getEventId() + "/" + p.getPhotoId() + ".jpg"));
                    Files.copy(photoTmp, zip);
                    zip.closeEntry();
                    written++;
                } finally {
                    Files.deleteIfExists(photoTmp);
                }
            }
            if (skipped > 0) {
                log.warn("[PhotosExportService] userId={} fotos omitidas={} exportadas={}", userId, skipped, written);
            }
            if (zip == null) return Optional.empty(); // ninguna foto exportable: no se sube nada
            zip.close(); // completa la subida multipart
            return Optional.of(key);
        } catch (IOException | RuntimeException e) {
            if (upload != null) upload.abort();
            closeQuietly(zip);
            if (e instanceof IOException io) throw new UncheckedIOException(io);
            throw (RuntimeException) e;
        }
    }

    private static void closeQuietly(ZipOutputStream zip) {
        if (zip == null) return;
        try {
            zip.close(); // libera el Deflater; la subida ya está abortada, así que no se completa nada
        } catch (IOException ignore) {
            // esperado: escribir el cierre del ZIP sobre una subida abortada falla
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
