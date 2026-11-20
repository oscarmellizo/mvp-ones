package com.ones.api.adapters.outbound.aws;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ones.api.application.photos.ports.PhotoDateResolutionQueue;

import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.SendMessageRequest;

@Component
public class SqsPhotoDateResolutionQueue implements PhotoDateResolutionQueue {

    private final SqsClient sqsClient;
    private final ObjectMapper objectMapper;
    private final String queueUrl;
    private final boolean enabled;

    public SqsPhotoDateResolutionQueue(
            SqsClient sqsClient,
            ObjectMapper objectMapper,
            @Value("${ones.sqs.photo-date-resolution-queue-url:}") String queueUrl,
            @Value("${ones.photos.date-resolution.enabled:true}") boolean enabled
    ) {
        this.sqsClient = sqsClient;
        this.objectMapper = objectMapper;
        this.queueUrl = queueUrl;
        this.enabled = enabled;
    }

    @Override
    public boolean isConfigured() {
        return enabled && queueUrl != null && !queueUrl.isBlank();
    }

    @Override
    public void enqueue(Job job) {
        if (!isConfigured()) {
            throw new IllegalStateException("Photo date resolution queue is not configured");
        }
        try {
            sqsClient.sendMessage(SendMessageRequest.builder()
                    .queueUrl(queueUrl)
                    .messageBody(objectMapper.writeValueAsString(job))
                    .build());
        } catch (JsonProcessingException e) {
            throw new IllegalArgumentException("Failed to serialize photo date resolution job", e);
        }
    }
}
