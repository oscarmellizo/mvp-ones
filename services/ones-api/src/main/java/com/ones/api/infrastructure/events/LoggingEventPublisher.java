package com.ones.api.infrastructure.events;

import java.time.Clock;
import java.time.Instant;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import com.ones.api.application.events.bus.DomainEventPublisher;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.invitations.Invitation;

@Component
public class LoggingEventPublisher implements DomainEventPublisher {

    private static final Logger log = LoggerFactory.getLogger(LoggingEventPublisher.class);

    private final Clock clock;
    private final software.amazon.awssdk.services.sns.SnsClient sns;
    private final String snsTopicArn;
    private final com.fasterxml.jackson.databind.ObjectMapper objectMapper;

    public LoggingEventPublisher(
            Clock clock
    ) {
        this.clock = clock;
        String topic = System.getenv("ONES_DOMAIN_EVENTS_TOPIC_ARN");
        this.snsTopicArn = (topic != null && !topic.isBlank()) ? topic.trim() : null;
        this.sns = (this.snsTopicArn != null) ? software.amazon.awssdk.services.sns.SnsClient.create() : null;
        this.objectMapper = new com.fasterxml.jackson.databind.ObjectMapper();
    }

    @Override
    public void publishPhotosUploaded(String eventId, String uploaderUserId, String uploaderName, int photoCount, String eventTitle) {
        if (eventId == null || eventId.isBlank()) return;
        publishDomainEvent("photo.uploaded", Map.of(
                "eventId", eventId,
                "uploaderUserId", uploaderUserId,
                "uploaderName", uploaderName,
                "photoCount", photoCount,
                "eventTitle", eventTitle
        ));
    }

    @Override
    public void publishInvitationCreated(Invitation invitation) {
        if (invitation == null) return;
        log.info("[DomainEvent] InvitationCreated eventId={} inviteeEmail={} ownerId={}",
                invitation.getEventId(), invitation.getInviteeEmail(), invitation.getEventOwnerId());

        publishDomainEvent("invitation.created", Map.of(
                "eventId", invitation.getEventId(),
                "inviteeEmail", invitation.getInviteeEmail(),
                "ownerId", invitation.getEventOwnerId(),
                "eventTitle", invitation.getEventTitle()
        ));
    }

    @Override
    public void publishInvitationResponded(Invitation invitation) {
        if (invitation == null) return;
        String ownerId = invitation.getEventOwnerId();
        String status = invitation.getStatus() == null ? "" : invitation.getStatus().name();
        publishDomainEvent("invitation.responded", Map.of(
                "eventId", invitation.getEventId(),
                "inviteeEmail", invitation.getInviteeEmail(),
                "ownerId", ownerId,
                "status", status
        ));
    }

    @Override
    public void publishEventUpdated(Event previous, Event updated) {
        if (updated == null) return;
        String eventId = updated.getEventId();
        if (eventId == null || eventId.isBlank()) return;
        publishDomainEvent("event.updated", Map.of(
                "eventId", eventId,
                "ownerId", updated.getOwnerId(),
                "title", updated.getTitle()
        ));
    }

    private void publishDomainEvent(String type, Map<String, Object> data) {
        if (snsTopicArn == null || snsTopicArn.isBlank() || sns == null) return;
        try {
            String payload = objectMapper.writeValueAsString(Map.of(
                    "type", type,
                    "data", data,
                    "occurredAt", Instant.now(clock).toString()
            ));
            sns.publish(software.amazon.awssdk.services.sns.model.PublishRequest.builder()
                    .topicArn(snsTopicArn)
                    .message(payload)
                    .build());
        } catch (Exception e) {
            log.debug("[Events] SNS publish failed type={} err={}", type, e.toString());
        }
    }
}
