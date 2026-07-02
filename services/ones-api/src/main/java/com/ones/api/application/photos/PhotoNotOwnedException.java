package com.ones.api.application.photos;

public class PhotoNotOwnedException extends RuntimeException {

    public PhotoNotOwnedException(String photoId) {
        super("Photo does not belong to the requesting user: " + photoId);
    }
}
