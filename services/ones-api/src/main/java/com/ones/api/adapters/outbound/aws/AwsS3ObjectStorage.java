package com.ones.api.adapters.outbound.aws;

import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import com.ones.api.application.events.ports.ObjectNotFoundException;
import com.ones.api.application.events.ports.ObjectStorage;

import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.AbortMultipartUploadRequest;
import software.amazon.awssdk.services.s3.model.CompleteMultipartUploadRequest;
import software.amazon.awssdk.services.s3.model.CompletedMultipartUpload;
import software.amazon.awssdk.services.s3.model.CompletedPart;
import software.amazon.awssdk.services.s3.model.CopyObjectRequest;
import software.amazon.awssdk.services.s3.model.CreateMultipartUploadRequest;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.NoSuchKeyException;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.S3Exception;
import software.amazon.awssdk.services.s3.model.UploadPartRequest;

@Component
public class AwsS3ObjectStorage implements ObjectStorage {

    private static final Logger log = LoggerFactory.getLogger(AwsS3ObjectStorage.class);

    /** Tamaño de cada parte de la subida multipart (S3 exige ≥ 5 MB salvo la última). */
    static final int PART_SIZE = 8 * 1024 * 1024;

    private final S3Client client;

    public AwsS3ObjectStorage(S3Client client) {
        this.client = client;
    }

    @Override
    public void putPng(String bucket, String key, byte[] png) {
        PutObjectRequest put = PutObjectRequest.builder()
                .bucket(bucket)
                .key(key)
                .contentType("image/png")
                .build();
        client.putObject(put, RequestBody.fromBytes(png));
    }

    @Override
    public InputStream open(String bucket, String key) {
        try {
            return client.getObject(GetObjectRequest.builder().bucket(bucket).key(key).build());
        } catch (NoSuchKeyException e) {
            throw new ObjectNotFoundException(bucket, key, e);
        } catch (S3Exception e) {
            if (e.statusCode() == 404) throw new ObjectNotFoundException(bucket, key, e);
            throw e;
        }
    }

    @Override
    public Upload openUpload(String bucket, String key, String contentType) {
        String uploadId = client.createMultipartUpload(CreateMultipartUploadRequest.builder()
                .bucket(bucket).key(key).contentType(contentType).build()).uploadId();
        return new MultipartUpload(bucket, key, uploadId);
    }

    @Override
    public void copy(String sourceBucket, String sourceKey, String destinationBucket, String destinationKey) {
        client.copyObject(CopyObjectRequest.builder()
                .copySource(sourceBucket + "/" + sourceKey)
                .destinationBucket(destinationBucket)
                .destinationKey(destinationKey)
                .build());
    }

    @Override
    public void delete(String bucket, String key) {
        client.deleteObject(DeleteObjectRequest.builder()
                .bucket(bucket)
                .key(key)
                .build());
    }

    /**
     * Sube en partes de {@link #PART_SIZE} guardadas en memoria; close() completa y abort() descarta.
     * Cualquier fallo de S3 aborta la subida (no quedan partes huérfanas cobrando almacenamiento).
     */
    private final class MultipartUpload extends Upload {
        private final String bucket;
        private final String key;
        private final String uploadId;
        private final byte[] buffer = new byte[PART_SIZE];
        private final List<CompletedPart> parts = new ArrayList<>();
        private int pos;
        private boolean finished; // completada o abortada

        MultipartUpload(String bucket, String key, String uploadId) {
            this.bucket = bucket;
            this.key = key;
            this.uploadId = uploadId;
        }

        @Override
        public void write(int b) throws IOException {
            write(new byte[] {(byte) b}, 0, 1);
        }

        @Override
        public void write(byte[] b, int off, int len) throws IOException {
            if (finished) throw new IOException("La subida de " + bucket + "/" + key + " ya terminó o se abortó");
            while (len > 0) {
                int n = Math.min(len, PART_SIZE - pos);
                System.arraycopy(b, off, buffer, pos, n);
                pos += n;
                off += n;
                len -= n;
                if (pos == PART_SIZE) uploadPart();
            }
        }

        private void uploadPart() throws IOException {
            int partNumber = parts.size() + 1;
            try {
                String eTag = client.uploadPart(UploadPartRequest.builder()
                                .bucket(bucket).key(key).uploadId(uploadId).partNumber(partNumber).build(),
                        RequestBody.fromBytes(Arrays.copyOf(buffer, pos))).eTag();
                parts.add(CompletedPart.builder().partNumber(partNumber).eTag(eTag).build());
                pos = 0;
            } catch (RuntimeException e) {
                abort();
                throw new IOException("Falló la parte " + partNumber + " de " + bucket + "/" + key, e);
            }
        }

        @Override
        public void close() throws IOException {
            if (finished) return;
            if (pos > 0 || parts.isEmpty()) uploadPart();
            try {
                client.completeMultipartUpload(CompleteMultipartUploadRequest.builder()
                        .bucket(bucket).key(key).uploadId(uploadId)
                        .multipartUpload(CompletedMultipartUpload.builder().parts(parts).build())
                        .build());
                finished = true;
            } catch (RuntimeException e) {
                abort();
                throw new IOException("No se pudo completar la subida de " + bucket + "/" + key, e);
            }
        }

        @Override
        public void abort() {
            if (finished) return;
            finished = true;
            try {
                client.abortMultipartUpload(AbortMultipartUploadRequest.builder()
                        .bucket(bucket).key(key).uploadId(uploadId).build());
            } catch (RuntimeException e) {
                // Las partes huérfanas las limpia la regla de ciclo de vida del bucket.
                log.warn("[S3] no se pudo abortar la subida {}/{} uploadId={}", bucket, key, uploadId, e);
            }
        }
    }
}
