package com.ones.api.application.frames;

public class FrameNotFoundException extends RuntimeException {

    public FrameNotFoundException(String frameId) {
        super("Frame not found: frameId=" + frameId);
    }
}
