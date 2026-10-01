package com.ones.api.adapters.outbound.firebase;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;

import com.fasterxml.jackson.databind.JsonNode;
import com.google.auth.oauth2.GoogleCredentials;
import com.ones.api.application.events.ports.SecretsProvider;
import com.ones.api.application.users.ports.FirebaseIdentityAdmin;

/** Cliente REST de Identity Toolkit (Firebase Auth) autenticado con una service account de Secrets Manager. */
@Component
public class FirebaseIdentityToolkitClient implements FirebaseIdentityAdmin {

    private static final String SCOPE = "https://www.googleapis.com/auth/cloud-platform";
    private static final Duration TIMEOUT = Duration.ofSeconds(15);

    private final WebClient webClient;
    private final SecretsProvider secretsProvider;
    private final String projectId;
    private final String serviceAccountSecretName;
    private volatile GoogleCredentials credentials;

    public FirebaseIdentityToolkitClient(
            WebClient.Builder builder,
            SecretsProvider secretsProvider,
            @Value("${ones.auth.firebase.project-id:}") String projectId,
            @Value("${ones.auth.firebase.service-account-secret-name:}") String serviceAccountSecretName
    ) {
        this.webClient = builder.baseUrl("https://identitytoolkit.googleapis.com").build();
        this.secretsProvider = secretsProvider;
        this.projectId = projectId != null ? projectId.trim() : "";
        this.serviceAccountSecretName = serviceAccountSecretName != null ? serviceAccountSecretName.trim() : "";
    }

    @Override
    public boolean isConfigured() {
        return StringUtils.hasText(projectId) && StringUtils.hasText(serviceAccountSecretName);
    }

    @Override
    public void replaceWithLegacyGoogleUser(String newUid, LegacyGoogleUser legacy) {
        String token = accessToken();

        // Primero se borra el usuario nuevo: tiene la identidad google.com que el importado necesita.
        // Ambos pasos toleran haber sido aplicados ya (peticiones paralelas o reintentos con el token viejo).
        try {
            post("/v1/projects/" + projectId + "/accounts:delete", Map.of("localId", newUid), token);
        } catch (WebClientResponseException e) {
            if (!e.getResponseBodyAsString().contains("USER_NOT_FOUND")) {
                throw new IllegalStateException("Firebase accounts:delete falló para " + newUid
                        + " (" + e.getStatusCode().value() + "): " + e.getResponseBodyAsString(), e);
            }
        }

        JsonNode result;
        try {
            result = post("/v1/projects/" + projectId + "/accounts:batchCreate", batchCreateBody(legacy), token);
        } catch (WebClientResponseException e) {
            throw new IllegalStateException("Firebase accounts:batchCreate falló para " + legacy.userId()
                    + " tras borrar el uid " + newUid + " (" + e.getStatusCode().value() + "): "
                    + e.getResponseBodyAsString(), e);
        }
        List<String> errors = importErrors(result).stream()
                .filter(error -> !error.contains("DUPLICATE_LOCAL_ID"))
                .toList();
        if (!errors.isEmpty()) {
            throw new IllegalStateException("Firebase batchCreate falló para " + legacy.userId()
                    + " tras borrar el uid " + newUid + ": " + errors);
        }
    }

    static Map<String, Object> batchCreateBody(LegacyGoogleUser legacy) {
        Map<String, Object> provider = new LinkedHashMap<>();
        provider.put("providerId", "google.com");
        provider.put("rawId", legacy.userId());
        putIfPresent(provider, "email", legacy.email());
        putIfPresent(provider, "displayName", legacy.displayName());
        putIfPresent(provider, "photoUrl", legacy.photoUrl());

        Map<String, Object> user = new LinkedHashMap<>();
        user.put("localId", legacy.userId());
        putIfPresent(user, "email", legacy.email());
        user.put("emailVerified", true);
        putIfPresent(user, "displayName", legacy.displayName());
        putIfPresent(user, "photoUrl", legacy.photoUrl());
        user.put("providerUserInfo", List.of(provider));

        return Map.of("users", List.of(user));
    }

    static List<String> importErrors(JsonNode result) {
        List<String> out = new ArrayList<>();
        if (result != null && result.path("error").isArray()) {
            result.path("error").forEach(e -> out.add(e.path("message").asText()));
        }
        return out;
    }

    private JsonNode post(String path, Object body, String token) {
        return webClient.post()
                .uri(path)
                .headers(h -> h.setBearerAuth(token))
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(body)
                .retrieve()
                .bodyToMono(JsonNode.class)
                .block(TIMEOUT);
    }

    String accessToken() {
        try {
            GoogleCredentials c = credentials;
            if (c == null) {
                String json = secretsProvider.getSecretString(serviceAccountSecretName);
                c = GoogleCredentials
                        .fromStream(new ByteArrayInputStream(json.getBytes(StandardCharsets.UTF_8)))
                        .createScoped(List.of(SCOPE));
                credentials = c;
            }
            c.refreshIfExpired();
            return c.getAccessToken().getTokenValue();
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo obtener token de la service account de Firebase", e);
        }
    }

    private static void putIfPresent(Map<String, Object> map, String key, String value) {
        if (value != null && !value.isBlank()) {
            map.put(key, value);
        }
    }
}
