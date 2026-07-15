package com.ones.api.adapters.outbound.mercadopago;

import java.time.Duration;
import java.util.Optional;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
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
        return new Preapproval(resp.id, resp.status, resp.initPoint);
    }

    @Override
    public Optional<Preapproval> getPreapproval(String preapprovalId) {
        if (preapprovalId == null || preapprovalId.isBlank()) {
            return Optional.empty();
        }
        try {
            PreapprovalResponse resp = webClient.get()
                    .uri("/preapproval/{id}", preapprovalId)
                    .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
                    .accept(MediaType.APPLICATION_JSON)
                    .retrieve()
                    .bodyToMono(PreapprovalResponse.class)
                    .block(Duration.ofSeconds(30));
            if (resp == null) {
                return Optional.empty();
            }
            return Optional.of(new Preapproval(resp.id, resp.status, resp.initPoint));
        } catch (WebClientResponseException.NotFound e) {
            return Optional.empty();
        }
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
    }
}
