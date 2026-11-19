package com.ones.api.adapters.outbound.aws;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ones.api.application.photos.ports.PhotoProcessingQueue;

import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.SendMessageRequest;

@Component
public class SqsPhotoProcessingQueue implements PhotoProcessingQueue {

    private final SqsClient sqsClient;
    private final ObjectMapper objectMapper;
    private final String queueUrl;

    public SqsPhotoProcessingQueue(
            SqsClient sqsClient,
            ObjectMapper objectMapper,
            @Value("${ones.sqs.photo-processing-queue-url:}") String queueUrl
    ) {
        this.sqsClient = sqsClient;
        this.objectMapper = objectMapper;
        this.queueUrl = queueUrl;
    }

    @Override
    public void enqueue(Job job) {
        if (queueUrl == null || queueUrl.isBlank()) {
            throw new IllegalStateException("Photo processing queue is not configured");
        }

        try {
            sqsClient.sendMessage(SendMessageRequest.builder()
                    .queueUrl(queueUrl)
                    .messageBody(objectMapper.writeValueAsString(job))
                    .build());
        } catch (JsonProcessingException e) {
            throw new IllegalArgumentException("Failed to serialize photo processing job", e);
        }
    }
}
