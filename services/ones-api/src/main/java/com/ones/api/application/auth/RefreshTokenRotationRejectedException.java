package com.ones.api.application.auth;

public class RefreshTokenRotationRejectedException extends RuntimeException {

    public RefreshTokenRotationRejectedException(String message, Throwable cause) {
        super(message, cause);
    }
}
