package com.ones.api.application.photos;

public class PhotoNotFoundException extends RuntimeException {

    public PhotoNotFoundException(String photoId) {
        super("Photo not found: " + photoId);
    }
}
