package com.ones.api.adapters.outbound.aws;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ones.api.application.collections.ports.CollectionDeletionQueue;

import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.SendMessageRequest;

@Component
public class SqsCollectionDeletionQueue implements CollectionDeletionQueue {
    private final SqsClient sqs;
    private final ObjectMapper objectMapper;
    private final String queueUrl;

    public SqsCollectionDeletionQueue(
            SqsClient sqs,
            ObjectMapper objectMapper,
            @Value("${ones.sqs.collection-deletion-queue-url:}") String queueUrl
    ) {
        this.sqs = sqs;
        this.objectMapper = objectMapper;
        this.queueUrl = queueUrl;
    }

    @Override
    public void enqueue(String collectionId) {
        if (queueUrl == null || queueUrl.isBlank()) {
            throw new IllegalStateException("Collection deletion queue is not configured");
        }
        try {
            sqs.sendMessage(SendMessageRequest.builder()
                    .queueUrl(queueUrl)
                    .messageBody(objectMapper.writeValueAsString(new DeleteCollectionJob(collectionId)))
                    .build());
        } catch (JsonProcessingException e) {
            throw new IllegalArgumentException("Could not serialize collection deletion job", e);
        }
    }

    private record DeleteCollectionJob(String collectionId) {}
}
