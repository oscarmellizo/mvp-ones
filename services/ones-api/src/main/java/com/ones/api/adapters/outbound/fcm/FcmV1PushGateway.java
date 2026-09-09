package com.ones.api.adapters.outbound.fcm;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ones.api.application.push.PushMessage;
import com.ones.api.application.push.ports.PushGateway;
import com.ones.api.domain.push.DeviceToken;
import com.google.auth.oauth2.AccessToken;
import com.google.auth.oauth2.GoogleCredentials;
import com.google.auth.oauth2.ServiceAccountCredentials;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.ByteArrayInputStream;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import java.util.Objects;

public class FcmV1PushGateway implements PushGateway {
    private static final Logger log = LoggerFactory.getLogger(FcmV1PushGateway.class);

    private static final String SCOPE = "https://www.googleapis.com/auth/firebase.messaging";

    private final String projectId;
    private final ServiceAccountCredentials credentials;
    private final HttpClient http;
    private final ObjectMapper mapper;

    public FcmV1PushGateway(String projectId, String serviceAccountJson) {
        this.projectId = Objects.requireNonNull(projectId, "projectId");
        Objects.requireNonNull(serviceAccountJson, "serviceAccountJson");
        try {
            GoogleCredentials base = ServiceAccountCredentials.fromStream(
                    new ByteArrayInputStream(serviceAccountJson.getBytes(StandardCharsets.UTF_8))
            );
            this.credentials = (ServiceAccountCredentials) base.createScoped(SCOPE);
        } catch (Exception e) {
            throw new IllegalStateException("Invalid FCM service account JSON", e);
        }
        this.http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();
        this.mapper = new ObjectMapper();
    }

    @Override
    public Result send(DeviceToken token, PushMessage message) throws Exception {
        if (token == null || token.getToken() == null || token.getToken().isBlank()) return Result.FAILED;

        String url = "https://fcm.googleapis.com/v1/projects/" + projectId + "/messages:send";

        Map<String, Object> root = new HashMap<>();
        Map<String, Object> msg = new HashMap<>();

        msg.put("token", token.getToken());

        Map<String, Object> notif = new HashMap<>();
        if (message.title() != null) notif.put("title", message.title());
        if (message.body() != null) notif.put("body", message.body());
        if (!notif.isEmpty()) msg.put("notification", notif);

        if (message.data() != null && !message.data().isEmpty()) {
            msg.put("data", message.data());
        }

        root.put("message", msg);

        String body = mapper.writeValueAsString(root);

        String accessToken = getAccessToken();

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .timeout(Duration.ofSeconds(10))
                .header("Authorization", "Bearer " + accessToken)
                .header("Content-Type", "application/json; charset=UTF-8")
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .build();

        HttpResponse<String> resp = http.send(request, HttpResponse.BodyHandlers.ofString());
        int status = resp.statusCode();
        if (status >= 200 && status < 300) return Result.OK;

        String rbody = resp.body() != null ? resp.body() : "";
        if (rbody.contains("UNREGISTERED") || rbody.contains("NOT_FOUND")) {
            return Result.INVALID_TOKEN;
        }
        log.warn("[Push:fcmv1] send failed status={} body={}", status, abbreviate(rbody, 500));
        return Result.FAILED;
    }

    private String getAccessToken() throws Exception {
        AccessToken token = credentials.refreshAccessToken();
        if (token == null || token.getTokenValue() == null) {
            throw new IllegalStateException("Unable to obtain access token for FCM v1");
        }
        return token.getTokenValue();
    }

    private static String abbreviate(String s, int max) {
        if (s == null) return "";
        return s.length() <= max ? s : s.substring(0, max);
    }
}
