package com.ones.api.adapters.outbound.mercadopago;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

class MercadoPagoClientSerializationTest {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void usesWholePesosForCopPlanAmounts() {
        assertEquals(19900.0, MercadoPagoClient.toMercadoPagoAmount(19900, "COP"));
        assertEquals(199.0, MercadoPagoClient.toMercadoPagoAmount(19900, "USD"));
    }

    @Test
    void serializesPreapprovalPlanRequestUsingMercadoPagoFieldNames() throws Exception {
        MercadoPagoClient.CreatePlanRequest request = new MercadoPagoClient.CreatePlanRequest(
                "Ones Plus Monthly",
                new MercadoPagoClient.AutoRecurring(1, "months", 19900, "COP"),
                "https://app.ones.events/plans/success?ones_uid=user-123",
                "https://app.ones.events/v1/payments/mercadopago/webhook",
                "user-123"
        );

        JsonNode payload = objectMapper.readTree(objectMapper.writeValueAsString(request));

        assertEquals("Ones Plus Monthly", payload.path("reason").asText());
        assertEquals("https://app.ones.events/plans/success?ones_uid=user-123", payload.path("back_url").asText());
        assertEquals("https://app.ones.events/v1/payments/mercadopago/webhook", payload.path("notification_url").asText());
        assertEquals("user-123", payload.path("external_reference").asText());
        assertEquals(1, payload.path("auto_recurring").path("frequency").asInt());
        assertEquals("months", payload.path("auto_recurring").path("frequency_type").asText());
        assertEquals(19900, payload.path("auto_recurring").path("transaction_amount").asInt());
        assertEquals("COP", payload.path("auto_recurring").path("currency_id").asText());
        assertFalse(payload.has("backUrl"));
        assertFalse(payload.has("autoRecurring"));
        assertFalse(payload.path("auto_recurring").has("frequencyType"));
    }
}
