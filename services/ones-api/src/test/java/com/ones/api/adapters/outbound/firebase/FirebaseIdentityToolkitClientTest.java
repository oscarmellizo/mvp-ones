package com.ones.api.adapters.outbound.firebase;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;

import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.web.reactive.function.client.WebClient;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ones.api.application.events.ports.SecretsProvider;
import com.ones.api.application.users.ports.FirebaseIdentityAdmin.LegacyGoogleUser;

class FirebaseIdentityToolkitClientTest {

    private final ObjectMapper mapper = new ObjectMapper();

    @Test
    void batchCreateBody_linksGoogleProviderWithLegacyUid() throws Exception {
        Map<String, Object> body = FirebaseIdentityToolkitClient.batchCreateBody(
                new LegacyGoogleUser("google-sub-1", "a@example.com", "Ana", "https://img/a.png"));

        String json = mapper.writeValueAsString(body);
        assertEquals(
                "{\"users\":[{\"localId\":\"google-sub-1\",\"email\":\"a@example.com\",\"emailVerified\":true,"
                        + "\"displayName\":\"Ana\",\"photoUrl\":\"https://img/a.png\",\"providerUserInfo\":[{"
                        + "\"providerId\":\"google.com\",\"rawId\":\"google-sub-1\",\"email\":\"a@example.com\","
                        + "\"displayName\":\"Ana\",\"photoUrl\":\"https://img/a.png\"}]}]}",
                json);
    }

    @Test
    void batchCreateBody_omitsNullFields() throws Exception {
        String json = mapper.writeValueAsString(FirebaseIdentityToolkitClient.batchCreateBody(
                new LegacyGoogleUser("g-2", "b@example.com", null, null)));

        assertFalse(json.contains("displayName"));
        assertFalse(json.contains("photoUrl"));
    }

    @Test
    void importErrors_readsPerUserErrors() throws Exception {
        assertEquals(List.of("DUPLICATE_LOCAL_ID"), FirebaseIdentityToolkitClient.importErrors(
                mapper.readTree("{\"error\":[{\"index\":0,\"message\":\"DUPLICATE_LOCAL_ID\"}]}")));
        assertTrue(FirebaseIdentityToolkitClient.importErrors(mapper.readTree("{}")).isEmpty());
    }

    @Test
    void isConfigured_requiresProjectAndSecretName() {
        SecretsProvider secrets = mock(SecretsProvider.class);

        assertFalse(new FirebaseIdentityToolkitClient(WebClient.builder(), secrets, "ones-a96a7", "").isConfigured());
        assertFalse(new FirebaseIdentityToolkitClient(WebClient.builder(), secrets, "", "arn:secret").isConfigured());
        assertTrue(new FirebaseIdentityToolkitClient(WebClient.builder(), secrets, "ones-a96a7", "arn:secret").isConfigured());
    }
}
