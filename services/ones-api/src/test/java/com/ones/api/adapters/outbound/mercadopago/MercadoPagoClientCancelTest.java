package com.ones.api.adapters.outbound.mercadopago;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.web.reactive.function.client.ClientRequest;
import org.springframework.web.reactive.function.client.ClientResponse;
import org.springframework.web.reactive.function.client.WebClient;

import com.fasterxml.jackson.databind.ObjectMapper;

import reactor.core.publisher.Mono;

class MercadoPagoClientCancelTest {

    private final List<ClientRequest> requests = new ArrayList<>();

    private MercadoPagoClient client(HttpStatus status, String token) {
        WebClient.Builder builder = WebClient.builder().exchangeFunction(req -> {
            requests.add(req);
            return Mono.just(ClientResponse.create(status).header("Content-Type", "application/json").body("{}").build());
        });
        return new MercadoPagoClient(builder, token);
    }

    @Test
    void cancelPreapproval_putsCancelledStatusWithBearerToken() throws Exception {
        client(HttpStatus.OK, "tok-1").cancelPreapproval("pre-1");

        assertEquals(1, requests.size());
        ClientRequest req = requests.get(0);
        assertEquals(HttpMethod.PUT, req.method());
        assertEquals("https://api.mercadopago.com/preapproval/pre-1", req.url().toString());
        assertEquals("Bearer tok-1", req.headers().getFirst("Authorization"));
        assertEquals("{\"status\":\"cancelled\"}",
                new ObjectMapper().writeValueAsString(new MercadoPagoClient.CancelPreapprovalRequest("cancelled")));
    }

    @Test
    void cancelPreapproval_httpError_throws() {
        assertThrows(RuntimeException.class, () -> client(HttpStatus.INTERNAL_SERVER_ERROR, "tok-1").cancelPreapproval("pre-1"));
    }

    @Test
    void cancelPreapproval_withoutAccessToken_throws_withoutCallingMercadoPago() {
        assertThrows(RuntimeException.class, () -> client(HttpStatus.OK, "").cancelPreapproval("pre-1"));
        assertEquals(0, requests.size());
    }
}
