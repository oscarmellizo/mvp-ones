package com.ones.api.application.photos;

public class PhotoSharedException extends RuntimeException {

    public PhotoSharedException(String photoId) {
        super("Photo is shared and cannot be deleted: " + photoId);
    }
}
