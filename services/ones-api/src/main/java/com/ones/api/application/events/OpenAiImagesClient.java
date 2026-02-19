package com.ones.api.application.events;

import java.util.Base64;
import java.util.List;

import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;
import org.springframework.web.reactive.function.client.ExchangeStrategies;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

@Component
public class OpenAiImagesClient {

    private final WebClient webClient;

    public OpenAiImagesClient(WebClient.Builder builder) {
        this.webClient = builder
                .baseUrl("https://api.openai.com")
                .exchangeStrategies(ExchangeStrategies.builder()
                        .codecs(configurer -> configurer.defaultCodecs().maxInMemorySize(10 * 1024 * 1024))
                        .build())
                .build();
    }

    public byte[] generatePng(String apiKey, String prompt, String size) {
        String normalizedSize = normalizeSize(size);
        OpenAiImageRequest req = new OpenAiImageRequest(
                "dall-e-3",
                prompt,
                normalizedSize,
                "b64_json",
                1
        );

        OpenAiImageResponse resp;
        try {
            resp = webClient.post()
                    .uri("/v1/images/generations")
                    .header(HttpHeaders.AUTHORIZATION, "Bearer " + apiKey)
                    .contentType(MediaType.APPLICATION_JSON)
                    .accept(MediaType.APPLICATION_JSON)
                    .bodyValue(req)
                    .retrieve()
                    .bodyToMono(OpenAiImageResponse.class)
                    .block();
        } catch (WebClientResponseException e) {
            String body = e.getResponseBodyAsString();
            throw new RuntimeException(
                    "OpenAI image generation failed: status=" + e.getStatusCode().value() + ", body=" + body,
                    e
            );
        } catch (Exception e) {
            throw new RuntimeException("OpenAI image generation failed", e);
        }

        if (resp == null || resp.data == null || resp.data.isEmpty() || resp.data.get(0).b64Json == null) {
            throw new RuntimeException("OpenAI image generation returned empty response");
        }

        return Base64.getDecoder().decode(resp.data.get(0).b64Json);
    }

    private String normalizeSize(String size) {
        if (size == null || size.isBlank()) {
            return "1024x1024";
        }

        // dall-e-3 supported sizes
        return switch (size.trim()) {
            case "1024x1024", "1792x1024", "1024x1792" -> size.trim();
            default -> "1024x1024";
        };
    }

    private record OpenAiImageRequest(
            String model,
            String prompt,
            String size,
            @JsonProperty("response_format") String responseFormat,
            int n
    ) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    private static class OpenAiImageResponse {
        public List<OpenAiImageData> data;
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    private static class OpenAiImageData {
        @JsonProperty("b64_json")
        public String b64Json;
    }
}
