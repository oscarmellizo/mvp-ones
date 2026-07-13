package com.ones.api.application.events;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.Test;

import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.application.subscriptions.CheckPlanLimitUseCase;
import com.ones.api.application.subscriptions.ports.SubscriptionPlansRepository;
import com.ones.api.application.subscriptions.ports.UserSubscriptionsRepository;
import com.ones.api.domain.events.Event;

class CreateEventUseCaseTest {

    @Test
    void createsEventWithOwnerAndTitle() {
        EventsRepository repo = new InMemoryEventsRepository();
        Clock clock = Clock.fixed(Instant.parse("2025-01-01T00:00:00Z"), ZoneOffset.UTC);
        CheckPlanLimitUseCase checkPlanLimitUseCase = new CheckPlanLimitUseCase(
                new EmptyUserSubscriptionsRepository(),
                new EmptySubscriptionPlansRepository()
        );

        CreateEventUseCase useCase = new CreateEventUseCase(repo, null, null, clock, null, null, checkPlanLimitUseCase);
        Instant startAt = Instant.parse("2025-01-01T18:00:00Z");
        Instant endAt = Instant.parse("2025-01-01T22:00:00Z");
        Event created = useCase.execute("user-123", "Hello", "birthday", "San Jose, CR", startAt, endAt, null, List.of(), true, List.of());

        assertNotNull(created.getEventId());
        assertEquals("user-123", created.getOwnerId());
        assertEquals("Hello", created.getTitle());
        assertEquals(Instant.parse("2025-01-01T00:00:00Z"), created.getCreatedAt());
        assertEquals("birthday", created.getObjective());
        assertEquals("San Jose, CR", created.getLocation());
        assertEquals(startAt, created.getStartAt());
        assertEquals(endAt, created.getEndAt());
        assertEquals(null, created.getCoverKey());
    }

    private static class InMemoryEventsRepository implements EventsRepository {
        private Event last;

        @Override
        public Event save(Event event) {
            this.last = event;
            return event;
        }

        @Override
        public Optional<Event> findById(String eventId) {
            return Optional.ofNullable(last).filter(e -> e.getEventId().equals(eventId));
        }

        @Override
        public List<Event> findByIds(List<String> eventIds) {
            if (eventIds == null || eventIds.isEmpty() || last == null) {
                return List.of();
            }
            return eventIds.stream().anyMatch(id -> id != null && id.equals(last.getEventId())) ? List.of(last) : List.of();
        }

        @Override
        public java.util.List<Event> listByOwnerId(String ownerId, int limit) {
            return last != null && last.getOwnerId().equals(ownerId) ? java.util.List.of(last) : java.util.List.of();
        }

        @Override
        public long countByOwnerId(String ownerId) {
            return last != null && last.getOwnerId().equals(ownerId) ? 1 : 0;
        }

        @Override
        public void deleteById(String eventId) {
            if (last != null && last.getEventId().equals(eventId)) last = null;
        }
    }

    private static class EmptyUserSubscriptionsRepository implements UserSubscriptionsRepository {
        @Override
        public Optional<com.ones.api.domain.subscriptions.UserSubscription> findByUserId(String userId) {
            return Optional.of(new com.ones.api.domain.subscriptions.UserSubscription(
                    userId, "free", "free", null,
                    java.time.Instant.now(), null, null, null, java.time.Instant.now()
            ));
        }

        @Override
        public com.ones.api.domain.subscriptions.UserSubscription upsert(com.ones.api.domain.subscriptions.UserSubscription subscription) {
            return subscription;
        }

        @Override
        public void deleteByUserId(String userId) {
        }
    }

    private static class EmptySubscriptionPlansRepository implements SubscriptionPlansRepository {
        @Override
        public Optional<com.ones.api.domain.subscriptions.SubscriptionPlan> findById(String planId) {
            if (!"free".equals(planId)) {
                return Optional.empty();
            }
            java.util.Map<String, com.ones.api.domain.subscriptions.PlanFeature> features = new java.util.HashMap<>();
            features.put("maxActiveEvents", new com.ones.api.domain.subscriptions.PlanFeature(100L, "number", "Eventos"));
            features.put("maxPhotosPerEvent", new com.ones.api.domain.subscriptions.PlanFeature(1000L, "number", "Fotos"));
            return Optional.of(new com.ones.api.domain.subscriptions.SubscriptionPlan(
                    "free", "Free", "", "free", 0, "COP", null, null,
                    features, true, 1,
                    java.time.Instant.now(), java.time.Instant.now()
            ));
        }

        @Override
        public java.util.List<com.ones.api.domain.subscriptions.SubscriptionPlan> findAllActive() {
            return java.util.List.of();
        }

        @Override
        public com.ones.api.domain.subscriptions.SubscriptionPlan upsert(com.ones.api.domain.subscriptions.SubscriptionPlan plan) {
            return plan;
        }

        @Override
        public void deleteById(String planId) {
        }
    }
}
