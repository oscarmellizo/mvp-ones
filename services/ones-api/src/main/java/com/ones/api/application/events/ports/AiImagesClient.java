package com.ones.api.application.events.ports;

public interface AiImagesClient {

    byte[] generatePng(String apiKey, String prompt, String size);
}
