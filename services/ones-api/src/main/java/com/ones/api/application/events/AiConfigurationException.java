package com.ones.api.application.events;

public class AiConfigurationException extends RuntimeException {

    public AiConfigurationException(String message) {
        super(message);
    }

    public AiConfigurationException(String message, Throwable cause) {
        super(message, cause);
    }
}
