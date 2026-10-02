package com.ones.api.adapters.outbound.aws;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import com.ones.api.application.events.ports.ObjectNotFoundException;
import com.ones.api.application.events.ports.ObjectStorage;

import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.AbortMultipartUploadRequest;
import software.amazon.awssdk.services.s3.model.CompleteMultipartUploadRequest;
import software.amazon.awssdk.services.s3.model.CreateMultipartUploadRequest;
import software.amazon.awssdk.services.s3.model.CreateMultipartUploadResponse;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.NoSuchKeyException;
import software.amazon.awssdk.services.s3.model.S3Exception;
import software.amazon.awssdk.services.s3.model.UploadPartRequest;
import software.amazon.awssdk.services.s3.model.UploadPartResponse;

class AwsS3ObjectStorageTest {

    private static final int PART = AwsS3ObjectStorage.PART_SIZE;

    private S3Client s3;
    private AwsS3ObjectStorage storage;
    private final List<Long> partSizes = new ArrayList<>();

    @BeforeEach
    void setUp() {
        s3 = mock(S3Client.class);
        storage = new AwsS3ObjectStorage(s3);
        when(s3.createMultipartUpload(any(CreateMultipartUploadRequest.class)))
                .thenReturn(CreateMultipartUploadResponse.builder().uploadId("up-1").build());
        when(s3.uploadPart(any(UploadPartRequest.class), any(RequestBody.class))).thenAnswer(inv -> {
            RequestBody body = inv.getArgument(1);
            partSizes.add(body.optionalContentLength().orElse(-1L));
            UploadPartRequest req = inv.getArgument(0);
            return UploadPartResponse.builder().eTag("etag-" + req.partNumber()).build();
        });
    }

    @Test
    void upload_splitsInto8MbParts_andCompletesInOrderOnClose() throws IOException {
        ObjectStorage.Upload up = storage.openUpload("exports", "k.zip", "application/zip");
        up.write(new byte[PART + 10]);
        up.write(7);
        up.close();

        assertEquals(List.of((long) PART, 11L), partSizes);
        ArgumentCaptor<CompleteMultipartUploadRequest> done = ArgumentCaptor.forClass(CompleteMultipartUploadRequest.class);
        verify(s3).completeMultipartUpload(done.capture());
        assertEquals("up-1", done.getValue().uploadId());
        assertEquals(List.of("etag-1", "etag-2"),
                done.getValue().multipartUpload().parts().stream().map(p -> p.eTag()).toList());
        verify(s3, never()).abortMultipartUpload(any(AbortMultipartUploadRequest.class));
    }

    @Test
    void failedPart_abortsUpload_andCloseDoesNotComplete() {
        when(s3.uploadPart(any(UploadPartRequest.class), any(RequestBody.class)))
                .thenThrow(S3Exception.builder().statusCode(500).message("boom").build());
        ObjectStorage.Upload up = storage.openUpload("exports", "k.zip", "application/zip");

        assertThrows(IOException.class, () -> up.write(new byte[PART]));
        assertThrows(IOException.class, () -> up.write(1));

        verify(s3).abortMultipartUpload(any(AbortMultipartUploadRequest.class));
        verify(s3, never()).completeMultipartUpload(any(CompleteMultipartUploadRequest.class));
    }

    @Test
    void abort_discardsUpload_andIsIdempotent() throws IOException {
        ObjectStorage.Upload up = storage.openUpload("exports", "k.zip", "application/zip");
        up.write(new byte[10]);
        up.abort();
        up.abort();
        up.close();

        verify(s3, times(1)).abortMultipartUpload(any(AbortMultipartUploadRequest.class));
        verify(s3, never()).completeMultipartUpload(any(CompleteMultipartUploadRequest.class));
    }

    @Test
    void failedComplete_abortsUpload() {
        when(s3.completeMultipartUpload(any(CompleteMultipartUploadRequest.class)))
                .thenThrow(S3Exception.builder().statusCode(500).message("boom").build());
        ObjectStorage.Upload up = storage.openUpload("exports", "k.zip", "application/zip");

        assertThrows(IOException.class, up::close);
        verify(s3).abortMultipartUpload(any(AbortMultipartUploadRequest.class));
    }

    @Test
    void open_missingKey_mapsToObjectNotFound_otherErrorsPropagate() {
        when(s3.getObject(any(GetObjectRequest.class)))
                .thenThrow(NoSuchKeyException.builder().statusCode(404).message("nope").build())
                .thenThrow(S3Exception.builder().statusCode(403).message("AccessDenied").build());

        assertThrows(ObjectNotFoundException.class, () -> storage.open("photos", "a.jpg"));
        S3Exception denied = assertThrows(S3Exception.class, () -> storage.open("photos", "b.jpg"));
        assertEquals(403, denied.statusCode());
    }
}
