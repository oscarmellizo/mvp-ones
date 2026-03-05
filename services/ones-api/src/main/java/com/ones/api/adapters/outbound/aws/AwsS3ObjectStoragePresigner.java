package com.ones.api.adapters.outbound.aws;

import java.net.URL;
import java.time.Duration;

import org.springframework.stereotype.Component;

import com.ones.api.application.events.ports.ObjectStoragePresigner;

import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;
import software.amazon.awssdk.services.s3.presigner.model.PutObjectPresignRequest;

@Component
public class AwsS3ObjectStoragePresigner implements ObjectStoragePresigner {

    private final S3Presigner presigner;

    public AwsS3ObjectStoragePresigner(S3Presigner presigner) {
        this.presigner = presigner;
    }

    @Override
    public URL presignGet(String bucket, String key, Duration ttl) {
        GetObjectRequest get = GetObjectRequest.builder()
                .bucket(bucket)
                .key(key)
                .build();

        GetObjectPresignRequest presignRequest = GetObjectPresignRequest.builder()
                .signatureDuration(ttl)
                .getObjectRequest(get)
                .build();

        return presigner.presignGetObject(presignRequest).url();
    }

    @Override
    public URL presignPut(String bucket, String key, Duration ttl, String contentType) {
        PutObjectRequest.Builder put = PutObjectRequest.builder()
                .bucket(bucket)
                .key(key);

        if (contentType != null && !contentType.isBlank()) {
            put = put.contentType(contentType.trim());
        }

        PutObjectPresignRequest presignRequest = PutObjectPresignRequest.builder()
                .signatureDuration(ttl)
                .putObjectRequest(put.build())
                .build();

        return presigner.presignPutObject(presignRequest).url();
    }
}
