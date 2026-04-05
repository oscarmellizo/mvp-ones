package com.ones.api.adapters.inbound.rest.admin;

import java.time.Instant;
import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.frames.FramesManagementService;
import com.ones.api.application.frames.ports.FramesRepository;
import com.ones.api.domain.frames.Frame;

@RestController
@RequestMapping("/v1/admin/frames")
public class AdminFramesController {

    private final FramesManagementService service;

    public AdminFramesController(FramesManagementService service) {
        this.service = service;
    }

    @GetMapping
    public ListFramesResponse list(
            @RequestParam(value = "status", required = false) String status,
            @RequestParam(value = "limit", required = false) Integer limit,
            @RequestParam(value = "nextToken", required = false) String nextToken
    ) {
        int l = limit != null ? limit : 50;
        String s = (status == null || status.isBlank()) ? "active" : status;

        FramesRepository.ListResult res = service.list(s, l, nextToken);
        List<FrameResponse> items = res.items().stream().map(AdminFramesController::toResponse).toList();
        return new ListFramesResponse(items, res.nextToken());
    }

    @PostMapping
    public ResponseEntity<FrameResponse> upsert(Authentication authentication, @RequestBody UpsertFrameRequest request) {
        String frameId = request != null ? request.frameId() : null;
        String name = request != null ? request.name() : null;
        Frame.Status status = parseStatus(request != null ? request.status() : null);
        Integer sortOrder = request != null ? request.sortOrder() : null;

        Frame saved = service.upsert(authentication, frameId, name, status, sortOrder);
        return ResponseEntity.ok(toResponse(saved));
    }

    @DeleteMapping("/{frameId}")
    public ResponseEntity<Void> delete(@PathVariable("frameId") String frameId) {
        service.delete(frameId);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{frameId}/asset/presign")
    public FramesManagementService.PresignPutAssetResult presignPut(
            Authentication authentication,
            @PathVariable("frameId") String frameId,
            @RequestBody PresignFrameAssetRequest request
    ) {
        String contentType = request != null ? request.contentType() : null;
        return service.presignPutAsset(authentication, frameId, contentType);
    }

    @GetMapping("/{frameId}/asset-url")
    public FramesManagementService.PresignedGetAssetResult getAssetUrl(
            @PathVariable("frameId") String frameId
    ) {
        return service.presignGetAsset(frameId);
    }

    private static Frame.Status parseStatus(String raw) {
        if (raw == null || raw.isBlank()) {
            return Frame.Status.inactive;
        }
        String v = raw.trim().toLowerCase();
        if ("active".equals(v)) return Frame.Status.active;
        if ("inactive".equals(v)) return Frame.Status.inactive;
        return Frame.Status.inactive;
    }

    private static FrameResponse toResponse(Frame f) {
        return new FrameResponse(
                f.getFrameId(),
                f.getName(),
                f.getStatus() != null ? f.getStatus().name() : null,
                f.getSortOrder(),
                f.getAssetKey(),
                f.getCreatedAt(),
                f.getUpdatedAt(),
                f.getCreatedBy(),
                f.getUpdatedBy()
        );
    }

    public record FrameResponse(
            String frameId,
            String name,
            String status,
            Integer sortOrder,
            String assetKey,
            Instant createdAt,
            Instant updatedAt,
            String createdBy,
            String updatedBy
    ) {
    }

    public record ListFramesResponse(List<FrameResponse> items, String nextToken) {
    }

    public record UpsertFrameRequest(String frameId, String name, String status, Integer sortOrder) {
    }

    public record PresignFrameAssetRequest(String contentType) {
    }
}
