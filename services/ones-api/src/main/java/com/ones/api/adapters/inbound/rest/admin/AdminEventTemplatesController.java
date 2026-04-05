package com.ones.api.adapters.inbound.rest.admin;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.eventtemplates.EventTemplatesManagementService;
import com.ones.api.domain.eventtemplates.EventTemplate;

@RestController
@RequestMapping("/v1/admin/event-templates")
public class AdminEventTemplatesController {

    private final EventTemplatesManagementService service;

    public AdminEventTemplatesController(EventTemplatesManagementService service) {
        this.service = service;
    }

    @GetMapping
    public List<EventTemplateResponse> list(@RequestParam(value = "status", required = false) String status) {
        EventTemplate.Status parsed = parseStatus(status);
        List<EventTemplate> items = service.list(parsed);
        return items.stream().map(et -> toResponse(et)).toList();
    }

    @PostMapping
    public EventTemplateResponse create(Authentication authentication, @RequestBody UpsertEventTemplateRequest request) {
        EventTemplate created = service.upsert(
                authentication,
                null,
                request.name(),
                request.status(),
                request.sortOrder(),
                request.frameIds()
        );
        return toResponse(created);
    }

    @PutMapping("/{eventTemplateId}")
    public EventTemplateResponse update(
            Authentication authentication,
            @PathVariable("eventTemplateId") String eventTemplateId,
            @RequestBody UpsertEventTemplateRequest request
    ) {
        EventTemplate updated = service.upsert(
                authentication,
                eventTemplateId,
                request.name(),
                request.status(),
                request.sortOrder(),
                request.frameIds()
        );
        return toResponse(updated);
    }

    @DeleteMapping("/{eventTemplateId}")
    public ResponseEntity<Void> delete(@PathVariable("eventTemplateId") String eventTemplateId) {
        service.delete(eventTemplateId);
        return ResponseEntity.noContent().build();
    }

    private static EventTemplate.Status parseStatus(String raw) {
        if (raw == null || raw.isBlank()) {
            return EventTemplate.Status.active;
        }
        String v = raw.trim().toLowerCase();
        if ("active".equals(v)) return EventTemplate.Status.active;
        if ("inactive".equals(v)) return EventTemplate.Status.inactive;
        return EventTemplate.Status.active;
    }

    private static EventTemplateResponse toResponse(EventTemplate et) {
        return new EventTemplateResponse(
                et.getEventTemplateId(),
                et.getName(),
                et.getStatus() != null ? et.getStatus().name() : null,
                et.getSortOrder(),
                et.getFrameIds(),
                et.getCreatedAt(),
                et.getUpdatedAt(),
                et.getCreatedBy(),
                et.getUpdatedBy()
        );
    }

    public record EventTemplateResponse(
            String eventTemplateId,
            String name,
            String status,
            Integer sortOrder,
            List<String> frameIds,
            Instant createdAt,
            Instant updatedAt,
            String createdBy,
            String updatedBy
    ) {
    }

    public record UpsertEventTemplateRequest(
            String name,
            EventTemplate.Status status,
            Integer sortOrder,
            List<String> frameIds
    ) {
    }
}
