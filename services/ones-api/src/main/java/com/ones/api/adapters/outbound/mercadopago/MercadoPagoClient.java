package com.ones.api.adapters.outbound.mercadopago;

import java.time.Duration;
import java.util.Optional;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.client.reactive.ReactorClientHttpConnector;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.ExchangeStrategies;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.ones.api.application.subscriptions.ports.MercadoPagoGateway;

import io.netty.channel.ChannelOption;
import reactor.netty.http.client.HttpClient;

@Component
public class MercadoPagoClient implements MercadoPagoGateway {

    private static final Logger log = LoggerFactory.getLogger(MercadoPagoClient.class);

    private static final ObjectMapper objectMapper = new ObjectMapper();

    private final WebClient webClient;
    private final String accessToken;

    public MercadoPagoClient(
            WebClient.Builder builder,
            @Value("${ones.mercadopago.access-token:}") String accessToken
    ) {
        this.accessToken = accessToken;
        HttpClient httpClient = HttpClient.create()
                .option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 10_000)
                .responseTimeout(Duration.ofSeconds(30));

        this.webClient = builder
                .baseUrl("https://api.mercadopago.com")
                .clientConnector(new ReactorClientHttpConnector(httpClient))
                .exchangeStrategies(ExchangeStrategies.builder()
                        .codecs(configurer -> configurer.defaultCodecs().maxInMemorySize(2 * 1024 * 1024))
                        .build())
                .build();
    }

    @Override
    public Optional<Preapproval> getPreapproval(String preapprovalId) {
        if (preapprovalId == null || preapprovalId.isBlank()) {
            return Optional.empty();
        }
        try {
            log.info("[MP outbound] GET /preapproval/{}", preapprovalId);
            String body = webClient.get()
                    .uri("/preapproval/{id}", preapprovalId)
                    .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
                    .accept(MediaType.APPLICATION_JSON)
                    .retrieve()
                    .bodyToMono(String.class)
                    .block(Duration.ofSeconds(30));

            if (body == null || body.isBlank()) {
                return Optional.empty();
            }

            JsonNode root;
            try {
                root = objectMapper.readTree(body);
            } catch (JsonProcessingException e) {
                log.warn("MercadoPago getPreapproval: could not parse JSON for preapprovalId={}", preapprovalId);
                return Optional.empty();
            }

            String id = text(root, "id");
            String status = text(root, "status");
            String initPoint = text(root, "init_point");
            String externalReference = text(root, "external_reference");
            String backUrl = text(root, "back_url");
            String preapprovalPlanId = text(root, "preapproval_plan_id");

            String payerEmail = text(root, "payer_email");
            if (payerEmail == null || payerEmail.isBlank()) {
                payerEmail = text(root.path("payer"), "email");
            }

            if (payerEmail == null || payerEmail.isBlank()) {
                String snippet = body.length() > 800 ? body.substring(0, 800) + "..." : body;
                log.warn(
                        "MercadoPago preapproval missing payer email. preapprovalId={} status={} responseSnippet={}",
                        preapprovalId,
                        status,
                        snippet
                );
            }

            log.info(
                    "[MP inbound] GET /preapproval response requestedPreapprovalId={} preapprovalId={} status={} payerEmailPresent={} payerEmailMasked={} externalReference={} backUrl={} preapprovalPlanId={} initPoint={}",
                    preapprovalId,
                    id,
                    status,
                    payerEmail != null && !payerEmail.isBlank(),
                    maskEmail(payerEmail),
                    externalReference,
                    backUrl,
                    preapprovalPlanId,
                    initPoint
            );
            return Optional.of(new Preapproval(id, status, initPoint, payerEmail, externalReference, backUrl, preapprovalPlanId));
        } catch (WebClientResponseException.NotFound e) {
            return Optional.empty();
        }
    }

    @Override
    public void cancelPreapproval(String preapprovalId) {
        if (accessToken == null || accessToken.isBlank()) {
            throw new IllegalStateException("Mercado Pago no está configurado en este ambiente (access token faltante).");
        }
        log.info("[MP outbound] PUT /preapproval/{} status=cancelled", preapprovalId);
        // retrieve() convierte 4xx/5xx en WebClientResponseException: el llamador decide reintentar.
        webClient.put()
                .uri("/preapproval/{id}", preapprovalId)
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .accept(MediaType.APPLICATION_JSON)
                .bodyValue(new CancelPreapprovalRequest("cancelled"))
                .retrieve()
                .toBodilessEntity()
                .block(Duration.ofSeconds(30));
        log.info("[MP inbound] PUT /preapproval/{} cancelada", preapprovalId);
    }

    record CancelPreapprovalRequest(String status) {
    }

    private static String maskEmail(String email) {
        if (email == null || email.isBlank()) {
            return null;
        }
        int at = email.indexOf('@');
        if (at <= 1) {
            return "***";
        }
        return email.substring(0, 1) + "***" + email.substring(at);
    }

    private static String text(JsonNode node, String field) {
        if (node == null || node.isMissingNode() || node.isNull()) {
            return null;
        }
        JsonNode value = node.get(field);
        if (value == null || value.isNull()) {
            return null;
        }
        String text = value.asText();
        return (text == null || text.isBlank()) ? null : text;
    }

}
