package com.ones.api.adapters.inbound.rest.events;

import java.util.List;
import java.util.Objects;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.eventtemplates.EventTemplatesManagementService;
import com.ones.api.application.frames.FrameAssetNotFoundException;
import com.ones.api.application.frames.FrameNotFoundException;
import com.ones.api.application.frames.FramesManagementService;
import com.ones.api.application.frames.ports.FramesRepository;
import com.ones.api.domain.eventtemplates.EventTemplate;
import com.ones.api.domain.frames.Frame;

@RestController
@RequestMapping("/v1/event-templates")
public class EventTemplatesController {

    private static final Logger log = LoggerFactory.getLogger(EventTemplatesController.class);

    private final EventTemplatesManagementService service;
    private final FramesManagementService framesService;
    private final FramesRepository framesRepository;

    public EventTemplatesController(
            EventTemplatesManagementService service,
            FramesManagementService framesService,
            FramesRepository framesRepository
    ) {
        this.service = service;
        this.framesService = framesService;
        this.framesRepository = framesRepository;
    }

    @GetMapping
    public List<EventTemplateResponse> list() {
        List<EventTemplate> items = service.list(EventTemplate.Status.active);
        return items.stream().map(this::toResponse).toList();
    }

    private EventTemplateResponse toResponse(EventTemplate et) {
        List<String> frameIds = et.getFrameIds();
        List<TemplateFrameResponse> frames = frameIds == null || frameIds.isEmpty()
                ? List.of()
                : frameIds.stream()
                .filter(id -> id != null && !id.isBlank())
                .map(String::trim)
                .map(this::toFrameResponseSafely)
                .filter(Objects::nonNull)
                .collect(Collectors.toList());

        return new EventTemplateResponse(
                et.getEventTemplateId(),
                et.getName(),
                et.getStatus() != null ? et.getStatus().name() : null,
                et.getSortOrder(),
                et.getFrameIds(),
                frames
        );
    }

    private TemplateFrameResponse toFrameResponseSafely(String frameId) {
        try {
            Frame frame = framesRepository.findById(frameId)
                    .orElseThrow(() -> new FrameNotFoundException(frameId));

            String verticalUrl = null;
            String horizontalUrl = null;

            try {
                FramesManagementService.PresignedGetAssetResult vertical =
                        framesService.presignGetAsset(frame, "vertical");
                verticalUrl = vertical.url();
            } catch (FrameAssetNotFoundException ignored) {
                // ignore missing vertical asset
            } catch (Exception ex) {
                log.warn("Failed to presign vertical frame asset for frameId={}", frameId, ex);
            }

            try {
                FramesManagementService.PresignedGetAssetResult horizontal =
                        framesService.presignGetAsset(frame, "horizontal");
                horizontalUrl = horizontal.url();
            } catch (FrameAssetNotFoundException ignored) {
                // ignore missing horizontal asset
            } catch (Exception ex) {
                log.warn("Failed to presign horizontal frame asset for frameId={}", frameId, ex);
            }

            if (verticalUrl == null && horizontalUrl == null) {
                return null;
            }

            return new TemplateFrameResponse(
                    frame.getFrameId(),
                    frame.getName(),
                    verticalUrl,
                    horizontalUrl
            );
        } catch (FrameNotFoundException ex) {
            return null;
        } catch (Exception ex) {
            log.warn("Failed to map frameId={} for event templates response", frameId, ex);
            return null;
        }
    }

    public record EventTemplateResponse(
            String eventTemplateId,
            String name,
            String status,
            Integer sortOrder,
            List<String> frameIds,
            List<TemplateFrameResponse> frames
    ) {
    }

    public record TemplateFrameResponse(
            String frameId,
            String name,
            String verticalUrl,
            String horizontalUrl
    ) {
    }
}
