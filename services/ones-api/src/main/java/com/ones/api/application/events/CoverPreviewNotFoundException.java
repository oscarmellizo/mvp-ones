package com.ones.api.application.events;

public class CoverPreviewNotFoundException extends RuntimeException {

    public CoverPreviewNotFoundException(String coverId) {
        super("Cover preview not found: " + coverId);
    }
}
