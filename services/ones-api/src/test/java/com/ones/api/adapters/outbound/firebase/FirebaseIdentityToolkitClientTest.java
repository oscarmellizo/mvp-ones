package com.ones.api.adapters.outbound.firebase;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.web.reactive.function.client.ClientResponse;
import org.springframework.web.reactive.function.client.WebClient;

import reactor.core.publisher.Mono;

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

    private static final LegacyGoogleUser LEGACY = new LegacyGoogleUser("google-sub-1", "a@example.com", "Ana", null);

    @Test
    void replace_deletesNewUidThenImportsLegacyUser() {
        List<String> calls = new ArrayList<>();
        client(calls, ok("{}"), ok("{}")).replaceWithLegacyGoogleUser("firebase-uid-9", LEGACY);

        assertEquals(List.of("/v1/projects/ones-a96a7/accounts:delete", "/v1/projects/ones-a96a7/accounts:batchCreate"), calls);
    }

    @Test
    void replace_newUidAlreadyDeleted_continuesWithImport() {
        List<String> calls = new ArrayList<>();
        client(calls, error(400, "{\"error\":{\"code\":400,\"message\":\"USER_NOT_FOUND\"}}"), ok("{}"))
                .replaceWithLegacyGoogleUser("firebase-uid-9", LEGACY);

        assertEquals(2, calls.size());
    }

    @Test
    void replace_legacyUserAlreadyImported_isTreatedAsMigrated() {
        client(new ArrayList<>(), ok("{}"), ok("{\"error\":[{\"index\":0,\"message\":\"DUPLICATE_LOCAL_ID\"}]}"))
                .replaceWithLegacyGoogleUser("firebase-uid-9", LEGACY);
    }

    @Test
    void replace_otherImportError_fails() {
        FirebaseIdentityToolkitClient c = client(new ArrayList<>(), ok("{}"),
                ok("{\"error\":[{\"index\":0,\"message\":\"INVALID_EMAIL\"}]}"));

        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> c.replaceWithLegacyGoogleUser("firebase-uid-9", LEGACY));
        assertTrue(ex.getMessage().contains("INVALID_EMAIL"));
    }

    @Test
    void replace_httpError_keepsFirebaseErrorBodyInMessage() {
        FirebaseIdentityToolkitClient c = client(new ArrayList<>(),
                error(403, "{\"error\":{\"code\":403,\"message\":\"PERMISSION_DENIED\"}}"), ok("{}"));

        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> c.replaceWithLegacyGoogleUser("firebase-uid-9", LEGACY));
        assertTrue(ex.getMessage().contains("PERMISSION_DENIED"), ex.getMessage());
        assertTrue(ex.getMessage().contains("accounts:delete"), ex.getMessage());
    }

    @Test
    void replace_importHttpErrorAfterDelete_saysDeleteAlreadyApplied() {
        FirebaseIdentityToolkitClient c = client(new ArrayList<>(), ok("{}"),
                error(500, "{\"error\":{\"code\":500,\"message\":\"INTERNAL\"}}"));

        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> c.replaceWithLegacyGoogleUser("firebase-uid-9", LEGACY));
        assertTrue(ex.getMessage().contains("firebase-uid-9"), ex.getMessage());
        assertTrue(ex.getMessage().contains("INTERNAL"), ex.getMessage());
    }

    private static FirebaseIdentityToolkitClient client(List<String> calls, ClientResponse delete, ClientResponse create) {
        WebClient.Builder builder = WebClient.builder().exchangeFunction(req -> {
            calls.add(req.url().getPath());
            return Mono.just(req.url().getPath().endsWith(":delete") ? delete : create);
        });
        return new FirebaseIdentityToolkitClient(builder, mock(SecretsProvider.class), "ones-a96a7", "arn:secret") {
            @Override
            String accessToken() {
                return "token";
            }
        };
    }

    private static ClientResponse ok(String json) {
        return ClientResponse.create(HttpStatus.OK).header("Content-Type", "application/json").body(json).build();
    }

    private static ClientResponse error(int status, String json) {
        return ClientResponse.create(HttpStatus.valueOf(status)).header("Content-Type", "application/json").body(json).build();
    }
}
