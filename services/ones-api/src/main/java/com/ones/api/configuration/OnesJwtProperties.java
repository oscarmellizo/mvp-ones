package com.ones.api.configuration;

import java.time.Duration;

public record OnesJwtProperties(
        String env,
        String issuer,
        String keyId,
        String privateKeySecretName,
        String publicKeySecretName,
        Duration accessTtl
) {
}
