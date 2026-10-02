package com.ones.api.adapters.outbound.aws;

import java.io.InputStream;
import java.nio.file.Path;

import org.springframework.stereotype.Component;

import com.ones.api.application.events.ports.ObjectStorage;

import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.CopyObjectRequest;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

@Component
public class AwsS3ObjectStorage implements ObjectStorage {

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
        return client.getObject(GetObjectRequest.builder().bucket(bucket).key(key).build());
    }

    @Override
    public void putFile(String bucket, String key, Path file, String contentType) {
        client.putObject(PutObjectRequest.builder().bucket(bucket).key(key).contentType(contentType).build(),
                RequestBody.fromFile(file));
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
}
