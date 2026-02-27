package com.ones.api.adapters.outbound.aws;

import java.net.URL;
import java.time.Duration;

import org.springframework.stereotype.Component;

import com.ones.api.application.events.ports.ObjectStoragePresigner;

import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;

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
}
