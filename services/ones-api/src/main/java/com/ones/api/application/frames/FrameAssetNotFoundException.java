package com.ones.api.application.frames;

public class FrameAssetNotFoundException extends RuntimeException {

    public FrameAssetNotFoundException(String frameId) {
        super("Frame asset not found: frameId=" + frameId);
    }
}
