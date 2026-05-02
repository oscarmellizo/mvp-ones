package com.ones.api.adapters.inbound.rest.frames;

import java.util.ArrayList;
import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.frames.FrameAssetNotFoundException;
import com.ones.api.application.frames.FramesManagementService;
import com.ones.api.application.frames.ports.FramesRepository;
import com.ones.api.domain.frames.Frame;

@RestController
@RequestMapping("/v1/frames")
public class FramesController {

    private final FramesManagementService framesService;

    public FramesController(FramesManagementService framesService) {
        this.framesService = framesService;
    }

    @GetMapping
    public ListFramesResponse list(
            @RequestParam(value = "status", required = false) String status,
            @RequestParam(value = "limit", required = false) Integer limit,
            @RequestParam(value = "nextToken", required = false) String nextToken
    ) {
        int l = limit != null ? limit : 50;
        String s = (status == null || status.isBlank()) ? "active" : status;

        FramesRepository.ListResult res = framesService.list(s, l, nextToken);

        List<FrameResponse> items = new ArrayList<>();
        for (Frame f : res.items()) {
            FrameResponse mapped = toResponseSafely(f);
            if (mapped != null) {
                items.add(mapped);
            }
        }

        return new ListFramesResponse(items, res.nextToken());
    }

    private FrameResponse toResponseSafely(Frame f) {
        if (f == null || f.getFrameId() == null || f.getFrameId().isBlank()) {
            return null;
        }

        String frameId = f.getFrameId();
        String verticalUrl = null;
        String horizontalUrl = null;

        try {
            FramesManagementService.PresignedGetAssetResult vertical = framesService.presignGetAsset(frameId, "vertical");
            verticalUrl = vertical.url();
        } catch (FrameAssetNotFoundException ignored) {
            // ignore missing vertical asset
        }

        try {
            FramesManagementService.PresignedGetAssetResult horizontal = framesService.presignGetAsset(frameId, "horizontal");
            horizontalUrl = horizontal.url();
        } catch (FrameAssetNotFoundException ignored) {
            // ignore missing horizontal asset
        }

        if ((verticalUrl == null || verticalUrl.isBlank()) && (horizontalUrl == null || horizontalUrl.isBlank())) {
            return null;
        }

        return new FrameResponse(
                frameId,
                f.getName(),
                verticalUrl,
                horizontalUrl
        );
    }

    public record FrameResponse(
            String frameId,
            String name,
            String verticalUrl,
            String horizontalUrl
    ) {
    }

    public record ListFramesResponse(List<FrameResponse> items, String nextToken) {
    }
}
