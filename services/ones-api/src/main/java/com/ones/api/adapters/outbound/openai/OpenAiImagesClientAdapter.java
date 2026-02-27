package com.ones.api.adapters.outbound.openai;

import org.springframework.stereotype.Component;

import com.ones.api.application.events.OpenAiImagesClient;
import com.ones.api.application.events.ports.AiImagesClient;

@Component
public class OpenAiImagesClientAdapter implements AiImagesClient {

    private final OpenAiImagesClient delegate;

    public OpenAiImagesClientAdapter(OpenAiImagesClient delegate) {
        this.delegate = delegate;
    }

    @Override
    public byte[] generatePng(String apiKey, String prompt, String size) {
        return delegate.generatePng(apiKey, prompt, size);
    }
}
