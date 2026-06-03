package com.ones.api.application.eventtemplates;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;

import com.ones.api.adapters.inbound.rest.AuthClaims;
import com.ones.api.application.eventtemplates.ports.EventTemplatesRepository;
import com.ones.api.application.frames.ports.FramesRepository;
import com.ones.api.configuration.CacheConfig;
import com.ones.api.domain.eventtemplates.EventTemplate;
import com.ones.api.domain.frames.Frame;

@Service
public class EventTemplatesManagementService {

    private final EventTemplatesRepository repository;
    private final FramesRepository framesRepository;
    private final Clock clock;

    public EventTemplatesManagementService(
            EventTemplatesRepository repository,
            FramesRepository framesRepository,
            Clock clock
    ) {
        this.repository = repository;
        this.framesRepository = framesRepository;
        this.clock = clock;
    }

    @Cacheable(
            cacheNames = CacheConfig.EVENT_TEMPLATES_BY_STATUS_CACHE,
            key = "#status == null ? 'active' : #status.name()",
            sync = true
    )
    public List<EventTemplate> list(EventTemplate.Status status) {
        return repository.list(status);
    }

    @CacheEvict(
            cacheNames = CacheConfig.EVENT_TEMPLATES_BY_STATUS_CACHE,
            allEntries = true
    )
    public EventTemplate upsert(
            Authentication authentication,
            String eventTemplateId,
            String name,
            EventTemplate.Status status,
            Integer sortOrder,
            List<String> frameIds
    ) {
        if (name == null || name.isBlank()) {
            throw new IllegalArgumentException("name is required");
        }
        if (frameIds == null) {
            frameIds = List.of();
        }
        // Validate that all frameIds exist
        for (String fid : frameIds) {
            if (!framesRepository.findById(fid).isPresent()) {
                throw new IllegalArgumentException("Frame not found: " + fid);
            }
        }

        Instant now = Instant.now(clock);
        String actor = resolveActor(authentication);

        String id = (eventTemplateId == null || eventTemplateId.isBlank()) ? UUID.randomUUID().toString() : eventTemplateId.trim();

        EventTemplate existing = repository.findById(id).orElse(null);
        Instant createdAt = existing != null && existing.getCreatedAt() != null ? existing.getCreatedAt() : now;
        String createdBy = existing != null ? existing.getCreatedBy() : actor;

        EventTemplate toSave = new EventTemplate(
                id,
                name.trim(),
                status != null ? status : EventTemplate.Status.inactive,
                sortOrder,
                frameIds,
                createdAt,
                now,
                createdBy,
                actor
        );

        return repository.upsert(toSave);
    }

    @CacheEvict(
            cacheNames = CacheConfig.EVENT_TEMPLATES_BY_STATUS_CACHE,
            allEntries = true
    )
    public void delete(String eventTemplateId) {
        repository.deleteById(eventTemplateId);
    }

    private static String resolveActor(Authentication authentication) {
        if (authentication == null) {
            return "system";
        }
        try {
            return AuthClaims.requireEmail(authentication);
        } catch (Exception e) {
            return "system";
        }
    }
}
