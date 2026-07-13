package com.ones.api.adapters.inbound.rest.subscriptions;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.subscriptions.ProcessMercadoPagoWebhookUseCase;

@RestController
@RequestMapping("/v1/payments/mercadopago")
public class MercadoPagoWebhookController {

    private static final Logger log = LoggerFactory.getLogger(MercadoPagoWebhookController.class);

    private final ProcessMercadoPagoWebhookUseCase processMercadoPagoWebhookUseCase;

    public MercadoPagoWebhookController(ProcessMercadoPagoWebhookUseCase processMercadoPagoWebhookUseCase) {
        this.processMercadoPagoWebhookUseCase = processMercadoPagoWebhookUseCase;
    }

    @PostMapping("/webhook")
    public ResponseEntity<Void> webhook(
            @RequestParam(name = "topic", required = false) String topic,
            @RequestParam(name = "id", required = false) String id
    ) {
        log.info("Received Mercado Pago webhook: topic={}, id={}", topic, id);
        processMercadoPagoWebhookUseCase.execute(topic, id);
        return ResponseEntity.ok().build();
    }
}
