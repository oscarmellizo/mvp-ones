package com.ones.api.application.subscriptions;

/** No se pudo cancelar en Mercado Pago la suscripción recurrente de la cuenta. */
public class SubscriptionCancellationException extends RuntimeException {

    public SubscriptionCancellationException(String userId, Throwable cause) {
        super("No se pudo cancelar la suscripción recurrente de userId=" + userId, cause);
    }
}
