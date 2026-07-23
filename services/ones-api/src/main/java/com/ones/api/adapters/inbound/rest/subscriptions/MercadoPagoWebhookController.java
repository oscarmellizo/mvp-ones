package com.ones.api.adapters.inbound.rest.subscriptions;

import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.subscriptions.ProcessMercadoPagoWebhookUseCase;

@RestController
public class MercadoPagoWebhookController {

    private static final Logger log = LoggerFactory.getLogger(MercadoPagoWebhookController.class);

    private final ProcessMercadoPagoWebhookUseCase processMercadoPagoWebhookUseCase;

    public MercadoPagoWebhookController(ProcessMercadoPagoWebhookUseCase processMercadoPagoWebhookUseCase) {
        this.processMercadoPagoWebhookUseCase = processMercadoPagoWebhookUseCase;
    }

    @PostMapping({"/v1/payments/mercadopago/webhook", "/v1/webhooks/mercadopago"})
    public ResponseEntity<Void> webhook(
            @RequestParam(name = "topic", required = false) String topic,
            @RequestParam(name = "id", required = false) String id,
            @RequestBody(required = false) Map<String, Object> body
    ) {
        String resolvedTopic = topic;
        String resolvedId = id;

        if ((resolvedId == null || resolvedId.isBlank()) && body != null) {
            Object dataObj = body.get("data");
            if (dataObj instanceof Map<?, ?> dataMap) {
                Object dataId = dataMap.get("id");
                if (dataId != null) {
                    resolvedId = dataId.toString();
                }
            }
        }

        if ((resolvedTopic == null || resolvedTopic.isBlank()) && body != null) {
            Object type = body.get("type");
            if (type != null) {
                resolvedTopic = type.toString();
            }
            Object bodyTopic = body.get("topic");
            if ((resolvedTopic == null || resolvedTopic.isBlank()) && bodyTopic != null) {
                resolvedTopic = bodyTopic.toString();
            }
        }

        log.info(
                "[MP webhook inbound] topic={} id={} rawTopic={} rawId={} payload={}",
                resolvedTopic,
                resolvedId,
                topic,
                id,
                body
        );
        processMercadoPagoWebhookUseCase.execute(resolvedTopic, resolvedId);
        return ResponseEntity.ok().build();
    }
}
