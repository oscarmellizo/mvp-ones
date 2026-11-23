package com.ones.api.adapters.outbound.aws;

import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ones.api.application.tournament.ports.TournamentScoringQueue;

import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.SendMessageRequest;
import software.amazon.awssdk.services.sqs.model.SendMessageBatchRequest;
import software.amazon.awssdk.services.sqs.model.SendMessageBatchRequestEntry;

@Component
public class SqsTournamentScoringQueue implements TournamentScoringQueue {

    private static final Logger log = LoggerFactory.getLogger(SqsTournamentScoringQueue.class);
    private final SqsClient sqs;
    private final ObjectMapper objectMapper;
    private final String queueUrl;

    public SqsTournamentScoringQueue(
            SqsClient sqs,
            ObjectMapper objectMapper,
            @Value("${ones.sqs.tournament-scoring-queue-url:}") String queueUrl
    ) {
        this.sqs = sqs;
        this.objectMapper = objectMapper;
        this.queueUrl = queueUrl;
    }

    @Override
    public void enqueue(String eventId) {
        if (queueUrl == null || queueUrl.isBlank()) {
            log.warn("Tournament score queue is not configured; eventId={} will need score refresh", eventId);
            return;
        }
        try {
            for (int offset = 0; offset < 16; offset += 10) {
                var entries = new java.util.ArrayList<SendMessageBatchRequestEntry>();
                for (int shard = offset; shard < Math.min(16, offset + 10); shard++) {
                    String body = objectMapper.writeValueAsString(Map.of("eventId", eventId, "shard", shard));
                    entries.add(SendMessageBatchRequestEntry.builder()
                            .id("shard-" + shard)
                            .messageBody(body)
                            .build());
                }
                var response = sqs.sendMessageBatch(SendMessageBatchRequest.builder()
                        .queueUrl(queueUrl)
                        .entries(entries)
                        .build());
                if (!response.failed().isEmpty()) {
                    throw new IllegalStateException("Unable to enqueue tournament score shards: " +
                            response.failed().size() + " message(s) failed");
                }
            }
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("Could not serialize tournament score job", e);
        }
    }
}
