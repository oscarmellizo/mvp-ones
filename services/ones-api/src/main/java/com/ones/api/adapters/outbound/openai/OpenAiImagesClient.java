package com.ones.api.adapters.outbound.openai;

import java.util.Base64;
import java.time.Duration;
import java.util.List;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.http.client.reactive.ReactorClientHttpConnector;
import org.springframework.web.reactive.function.client.ExchangeStrategies;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;

import io.netty.channel.ChannelOption;
import reactor.netty.http.client.HttpClient;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.ones.api.application.events.AiImageGenerationException;

@Component
public class OpenAiImagesClient {

    private final WebClient webClient;
    private final String imageModel;
    private static final Duration OPENAI_TIMEOUT = Duration.ofSeconds(110);
    private static final ObjectMapper MAPPER = new ObjectMapper();

    public OpenAiImagesClient(
            WebClient.Builder builder,
            @Value("${ones.ai.openai.image-model:dall-e-3}") String imageModel
    ) {
        HttpClient httpClient = HttpClient.create()
                .option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 10_000)
                .responseTimeout(OPENAI_TIMEOUT);

        this.imageModel = imageModel;
        this.webClient = builder
                .baseUrl("https://api.openai.com")
                .clientConnector(new ReactorClientHttpConnector(httpClient))
                .exchangeStrategies(ExchangeStrategies.builder()
                        .codecs(configurer -> configurer.defaultCodecs().maxInMemorySize(10 * 1024 * 1024))
                        .build())
                .build();
    }

    public byte[] generatePng(String apiKey, String prompt, String size) {
        String resolvedModel = (imageModel == null || imageModel.isBlank()) ? "dall-e-3" : imageModel.trim();
        String normalizedSize = normalizeSize(resolvedModel, size);
        OpenAiImageRequest req = new OpenAiImageRequest(
                resolvedModel,
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
                    .block(OPENAI_TIMEOUT);
        } catch (WebClientResponseException e) {
            String body = e.getResponseBodyAsString();
            String trimmed = formatOpenAiError(body);
            throw new AiImageGenerationException(
                    "OpenAI image generation failed: model=" + resolvedModel + ", size=" + normalizedSize + ", status=" + e.getStatusCode().value() + ", body=" + trimmed,
                    e
            );
        } catch (Exception e) {
            throw new AiImageGenerationException("OpenAI image generation failed", e);
        }

        if (resp == null || resp.data == null || resp.data.isEmpty() || resp.data.get(0).b64Json == null) {
            throw new AiImageGenerationException("OpenAI image generation returned empty response");
        }

        return Base64.getDecoder().decode(resp.data.get(0).b64Json);
    }

    private String normalizeSize(String model, String size) {
        String resolvedModel = (model == null || model.isBlank()) ? "dall-e-3" : model.trim().toLowerCase();
        if (size == null || size.isBlank()) {
            return resolvedModel.equals("dall-e-2") ? "1024x1024" : "1024x1024";
        }

        String s = size.trim();
        if (resolvedModel.equals("dall-e-2")) {
            return switch (s) {
                case "1024x1024", "512x512", "256x256" -> s;
                default -> "1024x1024";
            };
        }

        return switch (s) {
            case "1024x1024", "1792x1024", "1024x1792" -> s;
            default -> "1024x1024";
        };
    }

    private String formatOpenAiError(String body) {
        String trimmed = body == null ? "" : body.trim();
        if (trimmed.isEmpty()) return trimmed;
        try {
            JsonNode root = MAPPER.readTree(trimmed);
            JsonNode err = root.get("error");
            if (err != null && err.isObject()) {
                String message = err.path("message").asText("");
                String type = err.path("type").asText("");
                String code = err.path("code").asText("");
                String param = err.path("param").asText("");

                String compact = (type.isBlank() ? "" : type + ": ") + message;
                if (!code.isBlank()) {
                    compact = compact + " (code=" + code + ")";
                }
                if (!param.isBlank()) {
                    compact = compact + " (param=" + param + ")";
                }
                trimmed = compact.isBlank() ? trimmed : compact;
            }
        } catch (Exception ignored) {
        }

        if (trimmed.length() > 800) {
            trimmed = trimmed.substring(0, 800) + "...";
        }
        return trimmed;
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
