package com.ones.api.application.admin;

import org.springframework.stereotype.Service;
import software.amazon.awssdk.services.lambda.LambdaClient;
import software.amazon.awssdk.services.lambda.model.ListEventSourceMappingsRequest;
import software.amazon.awssdk.services.lambda.model.UpdateEventSourceMappingRequest;
import software.amazon.awssdk.services.lambda.model.EventSourceMappingConfiguration;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.GetQueueAttributesRequest;
import software.amazon.awssdk.services.sqs.model.GetQueueUrlRequest;

import java.util.List;
import java.util.Map;

@Service
public class AdminOpsService {
    private final SqsClient sqs;
    private final LambdaClient lambda;
    private final String realtimeQueueName;
    private final String pushQueueName;
    private final String realtimeDlqName;
    private final String pushDlqName;
    private final String realtimeConsumerFn;
    private final String pushConsumerFn;

    public AdminOpsService(
            SqsClient sqs,
            LambdaClient lambda,
            String realtimeQueueName,
            String pushQueueName,
            String realtimeDlqName,
            String pushDlqName,
            String realtimeConsumerFn,
            String pushConsumerFn
    ) {
        this.sqs = sqs;
        this.lambda = lambda;
        this.realtimeQueueName = realtimeQueueName;
        this.pushQueueName = pushQueueName;
        this.realtimeDlqName = realtimeDlqName;
        this.pushDlqName = pushDlqName;
        this.realtimeConsumerFn = realtimeConsumerFn;
        this.pushConsumerFn = pushConsumerFn;
    }

    public QueuesStatus queuesStatus() {
        return new QueuesStatus(
                queueAttrs(realtimeQueueName),
                queueAttrs(pushQueueName),
                queueAttrs(realtimeDlqName),
                queueAttrs(pushDlqName)
        );
    }

    public MappingsStatus mappingsStatus() {
        List<EventSourceMappingConfiguration> r = lambda.listEventSourceMappings(ListEventSourceMappingsRequest.builder()
                .functionName(realtimeConsumerFn)
                .build()).eventSourceMappings();
        List<EventSourceMappingConfiguration> p = lambda.listEventSourceMappings(ListEventSourceMappingsRequest.builder()
                .functionName(pushConsumerFn)
                .build()).eventSourceMappings();
        return new MappingsStatus(r, p);
    }

    public void setRealtimeMappingEnabled(boolean enabled) {
        List<EventSourceMappingConfiguration> mappings = lambda.listEventSourceMappings(ListEventSourceMappingsRequest.builder()
                .functionName(realtimeConsumerFn)
                .build()).eventSourceMappings();
        for (EventSourceMappingConfiguration m : mappings) {
            lambda.updateEventSourceMapping(UpdateEventSourceMappingRequest.builder()
                    .uuid(m.uuid())
                    .enabled(enabled)
                    .build());
        }
    }

    private Map<String, String> queueAttrs(String queueName) {
        if (queueName == null || queueName.isBlank()) return Map.of();
        String url = sqs.getQueueUrl(GetQueueUrlRequest.builder().queueName(queueName).build()).queueUrl();
        return sqs.getQueueAttributes(GetQueueAttributesRequest.builder()
                        .queueUrl(url)
                        .attributeNamesWithStrings(
                                "ApproximateNumberOfMessages",
                                "ApproximateNumberOfMessagesNotVisible",
                                "ApproximateAgeOfOldestMessage"
                        )
                        .build())
                .attributesAsStrings();
    }

    public record QueuesStatus(
            Map<String, String> realtime,
            Map<String, String> push,
            Map<String, String> realtimeDlq,
            Map<String, String> pushDlq
    ) {}

    public record MappingsStatus(
            List<EventSourceMappingConfiguration> realtime,
            List<EventSourceMappingConfiguration> push
    ) {}
}
