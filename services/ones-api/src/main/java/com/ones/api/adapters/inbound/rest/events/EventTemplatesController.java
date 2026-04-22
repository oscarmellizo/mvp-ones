package com.ones.api.adapters.inbound.rest.events;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.eventtemplates.EventTemplatesManagementService;
import com.ones.api.domain.eventtemplates.EventTemplate;

@RestController
@RequestMapping("/v1/event-templates")
public class EventTemplatesController {

    private final EventTemplatesManagementService service;

    public EventTemplatesController(EventTemplatesManagementService service) {
        this.service = service;
    }

    @GetMapping
    public List<EventTemplateResponse> list() {
        List<EventTemplate> items = service.list(EventTemplate.Status.active);
        return items.stream().map(EventTemplatesController::toResponse).toList();
    }

    private static EventTemplateResponse toResponse(EventTemplate et) {
        return new EventTemplateResponse(
                et.getEventTemplateId(),
                et.getName(),
                et.getStatus() != null ? et.getStatus().name() : null,
                et.getSortOrder(),
                et.getFrameIds()
        );
    }

    public record EventTemplateResponse(
            String eventTemplateId,
            String name,
            String status,
            Integer sortOrder,
            List<String> frameIds
    ) {
    }
}
