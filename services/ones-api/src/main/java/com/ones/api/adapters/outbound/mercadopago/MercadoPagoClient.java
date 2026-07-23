package com.ones.api.adapters.outbound.mercadopago;

import java.time.Duration;
import java.util.Optional;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
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
    public PreapprovalPlan createPlan(
            String reason,
            String billingInterval,
            long priceCents,
            String currency,
            String backUrl,
            String notificationUrl
    ) {
        int frequency = "year".equalsIgnoreCase(billingInterval) ? 12 : 1;
        double amount = priceCents / 100.0;

        CreatePlanRequest req = new CreatePlanRequest(
                reason,
                new AutoRecurring(frequency, "months", amount, currency),
                backUrl,
                notificationUrl
        );

        PlanResponse resp = post("/preapproval_plan", req, PlanResponse.class);
        return new PreapprovalPlan(resp.id, resp.reason, resp.initPoint);
    }

    @Override
    public Optional<PreapprovalPlan> getPlan(String preapprovalPlanId) {
        if (preapprovalPlanId == null || preapprovalPlanId.isBlank()) {
            return Optional.empty();
        }
        if (accessToken == null || accessToken.isBlank()) {
            throw new IllegalArgumentException(
                    "Mercado Pago no está configurado en este ambiente (access token faltante)."
            );
        }
        try {
            PlanResponse resp = webClient.get()
                    .uri("/preapproval_plan/{id}", preapprovalPlanId)
                    .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
                    .accept(MediaType.APPLICATION_JSON)
                    .retrieve()
                    .bodyToMono(PlanResponse.class)
                    .block(Duration.ofSeconds(30));
            if (resp == null) {
                return Optional.empty();
            }
            return Optional.of(new PreapprovalPlan(resp.id, resp.reason, resp.initPoint));
        } catch (WebClientResponseException.NotFound e) {
            return Optional.empty();
        } catch (WebClientResponseException e) {
            log.warn("MercadoPago getPlan failed with status={} body={}", e.getStatusCode().value(), e.getResponseBodyAsString());
            throw e;
        }
    }

    @Override
    public Optional<String> getPayerEmailFromPayment(String paymentId) {
        if (paymentId == null || paymentId.isBlank()) {
            return Optional.empty();
        }
        if (accessToken == null || accessToken.isBlank()) {
            throw new IllegalArgumentException(
                    "Mercado Pago no está configurado en este ambiente (access token faltante)."
            );
        }

        try {
            String body = webClient.get()
                    .uri("/v1/payments/{id}", paymentId)
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
                log.warn("MercadoPago getPayerEmailFromPayment: could not parse JSON for paymentId={}", paymentId);
                return Optional.empty();
            }

            String payerEmail = text(root, "payer_email");
            if (payerEmail == null || payerEmail.isBlank()) {
                payerEmail = text(root.path("payer"), "email");
            }
            if (payerEmail == null || payerEmail.isBlank()) {
                payerEmail = findFirstTextByFieldName(root, "email");
            }

            if (payerEmail == null || payerEmail.isBlank()) {
                String snippet = body.length() > 800 ? body.substring(0, 800) + "..." : body;
                log.warn(
                        "MercadoPago payment missing payer email. paymentId={} responseSnippet={}"
                        ,
                        paymentId,
                        snippet
                );
                return Optional.empty();
            }

            return Optional.of(payerEmail);
        } catch (WebClientResponseException.NotFound e) {
            return Optional.empty();
        } catch (WebClientResponseException e) {
            log.warn(
                    "MercadoPago getPayerEmailFromPayment failed with status={} body={}"
                    ,
                    e.getStatusCode().value(),
                    e.getResponseBodyAsString()
            );
            throw e;
        }
    }

    @Override
    public Preapproval createPreapproval(
            String preapprovalPlanId,
            String payerEmail,
            String backUrl
    ) {
        CreatePreapprovalRequest req = new CreatePreapprovalRequest(
                preapprovalPlanId,
                payerEmail,
                backUrl
        );

        PreapprovalResponse resp = post("/preapproval", req, PreapprovalResponse.class);
        return new Preapproval(resp.id, resp.status, resp.initPoint, resp.getResolvedPayerEmail(), resp.externalReference, resp.backUrl);
    }

    @Override
    public Preapproval createPreapproval(
            String preapprovalPlanId,
            String payerEmail,
            String backUrl,
            String externalReference
    ) {
        CreatePreapprovalRequestWithExternalReference req = new CreatePreapprovalRequestWithExternalReference(
                preapprovalPlanId,
                payerEmail,
                backUrl,
                externalReference,
                "pending"
        );

        PreapprovalResponse resp = post("/preapproval", req, PreapprovalResponse.class);
        return new Preapproval(resp.id, resp.status, resp.initPoint, resp.getResolvedPayerEmail(), resp.externalReference, resp.backUrl);
    }

    @Override
    public Preapproval createPreapproval(
            String preapprovalPlanId,
            String payerEmail,
            String backUrl,
            String externalReference,
            String cardTokenId
    ) {
        CreatePreapprovalRequestWithCard req = new CreatePreapprovalRequestWithCard(
                preapprovalPlanId,
                payerEmail,
                backUrl,
                externalReference,
                cardTokenId
        );

        PreapprovalResponse resp = post("/preapproval", req, PreapprovalResponse.class);
        return new Preapproval(resp.id, resp.status, resp.initPoint, resp.getResolvedPayerEmail(), resp.externalReference, resp.backUrl);
    }

    @Override
    public Optional<Preapproval> getPreapproval(String preapprovalId) {
        if (preapprovalId == null || preapprovalId.isBlank()) {
            return Optional.empty();
        }
        try {
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

            return Optional.of(new Preapproval(id, status, initPoint, payerEmail, externalReference, backUrl));
        } catch (WebClientResponseException.NotFound e) {
            return Optional.empty();
        }
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

    @Override
    public Optional<String> resolvePreapprovalIdFromPayment(String paymentId) {
        if (paymentId == null || paymentId.isBlank()) {
            return Optional.empty();
        }
        if (accessToken == null || accessToken.isBlank()) {
            throw new IllegalArgumentException(
                    "Mercado Pago no está configurado en este ambiente (access token faltante)."
            );
        }
        try {
            String body = webClient.get()
                    .uri("/v1/payments/{id}", paymentId)
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
                log.warn("MercadoPago resolvePreapprovalIdFromPayment: could not parse JSON for paymentId={}", paymentId);
                return Optional.empty();
            }

            String preapprovalId = text(root, "preapproval_id");
            if (preapprovalId == null || preapprovalId.isBlank()) {
                preapprovalId = text(root, "subscription_id");
            }
            if (preapprovalId == null || preapprovalId.isBlank()) {
                preapprovalId = text(root.path("metadata"), "preapproval_id");
            }

            if (preapprovalId == null || preapprovalId.isBlank()) {
                preapprovalId = findFirstTextByFieldName(root, "preapproval_id");
            }
            if (preapprovalId == null || preapprovalId.isBlank()) {
                preapprovalId = findFirstTextByFieldName(root, "subscription_id");
            }

            if (preapprovalId != null && !preapprovalId.isBlank()) {
                return Optional.of(preapprovalId);
            }

            String snippet = body.length() > 800 ? body.substring(0, 800) + "..." : body;
            log.warn(
                    "MercadoPago payment missing preapproval/subscription id. paymentId={} responseSnippet={}",
                    paymentId,
                    snippet
            );

            return Optional.empty();
        } catch (WebClientResponseException.NotFound e) {
            return Optional.empty();
        } catch (WebClientResponseException e) {
            log.warn(
                    "MercadoPago resolvePreapprovalIdFromPayment failed with status={} body={}",
                    e.getStatusCode().value(),
                    e.getResponseBodyAsString()
            );
            throw e;
        }
    }

    private static String findFirstTextByFieldName(JsonNode node, String fieldName) {
        if (node == null || node.isNull() || node.isMissingNode()) {
            return null;
        }
        if (node.isObject()) {
            JsonNode direct = node.get(fieldName);
            if (direct != null && !direct.isNull()) {
                String value = direct.asText();
                if (value != null && !value.isBlank()) {
                    return value;
                }
            }
            var it = node.fields();
            while (it.hasNext()) {
                var entry = it.next();
                String found = findFirstTextByFieldName(entry.getValue(), fieldName);
                if (found != null && !found.isBlank()) {
                    return found;
                }
            }
        } else if (node.isArray()) {
            for (JsonNode child : node) {
                String found = findFirstTextByFieldName(child, fieldName);
                if (found != null && !found.isBlank()) {
                    return found;
                }
            }
        }
        return null;
    }

    private <T> T post(String uri, Object body, Class<T> responseType) {
        if (accessToken == null || accessToken.isBlank()) {
            throw new IllegalArgumentException(
                    "Mercado Pago no está configurado en este ambiente (access token faltante)."
            );
        }

        try {
            return webClient.post()
                    .uri(uri)
                    .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
                    .contentType(MediaType.APPLICATION_JSON)
                    .accept(MediaType.APPLICATION_JSON)
                    .bodyValue(body)
                    .retrieve()
                    .bodyToMono(responseType)
                    .block(Duration.ofSeconds(30));
        } catch (WebClientResponseException.Unauthorized | WebClientResponseException.Forbidden e) {
            log.warn("MercadoPago request failed with status={} body={}", e.getStatusCode().value(), e.getResponseBodyAsString());
            throw new IllegalArgumentException(
                    "No pudimos iniciar la suscripción porque Mercado Pago rechazó las credenciales de este ambiente. " +
                            "Verifica el access token (sandbox/test) en AWS Secrets Manager y reinicia el servicio.",
                    e
            );
        } catch (WebClientResponseException e) {
            String bodyText = e.getResponseBodyAsString();
            log.warn("MercadoPago request failed with status={} body={}", e.getStatusCode().value(), bodyText);
            String suffix = (bodyText == null || bodyText.isBlank()) ? "" : (" Detalle: " + bodyText);
            throw new IllegalArgumentException(
                    "Mercado Pago devolvió un error al iniciar la suscripción (HTTP " + e.getStatusCode().value() + ")." + suffix,
                    e
            );
        }
    }

    private record CreatePlanRequest(
            String reason,
            AutoRecurring autoRecurring,
            String backUrl,
            String notificationUrl
    ) {
    }

    private record AutoRecurring(
            int frequency,
            String frequencyType,
            double transactionAmount,
            String currencyId
    ) {
    }

    private record CreatePreapprovalRequest(
            @JsonProperty("preapproval_plan_id") String preapprovalPlanId,
            @JsonProperty("payer_email") String payerEmail,
            @JsonProperty("back_url") String backUrl
    ) {
    }

    private record CreatePreapprovalRequestWithExternalReference(
            @JsonProperty("preapproval_plan_id") String preapprovalPlanId,
            @JsonProperty("payer_email") String payerEmail,
            @JsonProperty("back_url") String backUrl,
            @JsonProperty("external_reference") String externalReference,
            String status
    ) {
    }

    private record CreatePreapprovalRequestWithCard(
            @JsonProperty("preapproval_plan_id") String preapprovalPlanId,
            @JsonProperty("payer_email") String payerEmail,
            @JsonProperty("back_url") String backUrl,
            @JsonProperty("external_reference") String externalReference,
            @JsonProperty("card_token_id") String cardTokenId
    ) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    private static class PlanResponse {
        public String id;
        public String reason;
        @JsonProperty("init_point")
        public String initPoint;
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    private static class PreapprovalResponse {
        public String id;
        public String status;
        @JsonProperty("init_point")
        public String initPoint;
        @JsonProperty("payer_email")
        public String payerEmail;

        @JsonProperty("back_url")
        public String backUrl;

        @JsonProperty("external_reference")
        public String externalReference;

        public Payer payer;

        public String getResolvedPayerEmail() {
            if (payerEmail != null && !payerEmail.isBlank()) {
                return payerEmail;
            }
            if (payer != null && payer.email != null && !payer.email.isBlank()) {
                return payer.email;
            }
            return null;
        }
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    private static class Payer {
        public String email;
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    private static class PaymentResponse {
        @JsonProperty("preapproval_id")
        public String preapprovalId;

        @JsonProperty("subscription_id")
        public String subscriptionId;

        public PaymentMetadata metadata;
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    private static class PaymentMetadata {
        @JsonProperty("preapproval_id")
        public String preapprovalId;
    }
}
