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

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Component
public class OpenAiImagesClient {

    private final WebClient webClient;
    private final String imageModel;
    private static final Duration OPENAI_TIMEOUT = Duration.ofSeconds(110);
    private static final ObjectMapper MAPPER = new ObjectMapper();
    private static final String DEFAULT_MODEL = "gpt-image-2";
    private static final Logger log = LoggerFactory.getLogger(OpenAiImagesClient.class);

    public OpenAiImagesClient(
            WebClient.Builder builder,
            @Value("${ones.ai.openai.image-model:gpt-image-2}") String imageModel
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
        String resolvedModel = (imageModel == null || imageModel.isBlank()) ? DEFAULT_MODEL : imageModel.trim();
        if (resolvedModel.equalsIgnoreCase("dall-e-3") || resolvedModel.equalsIgnoreCase("dall-e-2")) {
            log.warn("OpenAI model {} is deprecated/removed; falling back to {}", resolvedModel, DEFAULT_MODEL);
            resolvedModel = DEFAULT_MODEL;
        }
        String normalizedSize = normalizeSize(resolvedModel, size);
        Object req = resolvedModel.toLowerCase().contains("gpt-image")
                ? new OpenAiGptImageRequest(resolvedModel, prompt, normalizedSize, 1)
                : new OpenAiDalleImageRequest(resolvedModel, prompt, normalizedSize, "b64_json", 1);

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
            log.error(
                    "OpenAI image generation failed: model={}, size={}, status={}, body={}",
                    resolvedModel,
                    normalizedSize,
                    e.getStatusCode().value(),
                    trimmed
            );
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
        String resolvedModel = (model == null || model.isBlank()) ? DEFAULT_MODEL : model.trim().toLowerCase();

        if (size == null || size.isBlank()) {
            return resolvedModel.contains("gpt-image") ? "auto" : "1024x1024";
        }

        String s = size.trim();

        // GPT image models (gpt-image-2, gpt-image-1, gpt-image-1-mini)
        if (resolvedModel.contains("gpt-image")) {
            if (s.equalsIgnoreCase("auto")) return "auto";

            // gpt-image-2 accepts any resolution within constraints
            // - Maximum edge length <= 3840
            // - Both edges multiple of 16
            // - Long:short ratio <= 3:1
            // - Total pixels between 655,360 and 8,294,400
            String[] parts = s.split("x");
            if (parts.length == 2) {
                try {
                    int w = Integer.parseInt(parts[0]);
                    int h = Integer.parseInt(parts[1]);

                    int longEdge = Math.max(w, h);
                    int shortEdge = Math.min(w, h);
                    long pixels = (long) w * (long) h;

                    boolean ok = longEdge <= 3840
                            && (w % 16 == 0)
                            && (h % 16 == 0)
                            && ((double) longEdge / (double) shortEdge) <= 3.0
                            && pixels >= 655_360L
                            && pixels <= 8_294_400L;

                    if (ok) return s;
                    if (w > h) return "1536x1024";
                    if (h > w) return "1024x1536";
                } catch (Exception ignored) {
                }
            }

            return "1024x1024";
        }

        // dall-e-2 supported sizes
        if (resolvedModel.equals("dall-e-2")) {
            return switch (s) {
                case "1024x1024", "512x512", "256x256" -> s;
                default -> "1024x1024";
            };
        }

        // dall-e-3 supported sizes (legacy)
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

    private record OpenAiDalleImageRequest(
            String model,
            String prompt,
            String size,
            @JsonProperty("response_format") String responseFormat,
            int n
    ) {
    }

    private record OpenAiGptImageRequest(
            String model,
            String prompt,
            String size,
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
