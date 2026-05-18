package com.ones.api.configuration;

import java.security.KeyFactory;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.PrivateKey;
import java.security.PublicKey;
import java.security.interfaces.RSAPrivateKey;
import java.security.interfaces.RSAPublicKey;
import java.security.spec.PKCS8EncodedKeySpec;
import java.security.spec.X509EncodedKeySpec;
import java.time.Duration;
import java.util.Base64;

import com.nimbusds.jose.jwk.JWKSet;
import com.nimbusds.jose.jwk.RSAKey;
import com.nimbusds.jose.jwk.source.ImmutableJWKSet;
import com.ones.api.application.events.ports.SecretsProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.util.StringUtils;

@Configuration
public class OnesJwtConfig {

    private volatile KeyPair cachedDevKeyPair;

    @Bean
    OnesJwtProperties onesJwtProperties(
            @Value("${ones.env:dev}") String env,
            @Value("${ones.auth.jwt.issuer:ones}") String issuer,
            @Value("${ones.auth.jwt.key-id:ones}") String keyId,
            @Value("${ones.auth.jwt.private-key-secret-name:}") String privateKeySecretName,
            @Value("${ones.auth.jwt.public-key-secret-name:}") String publicKeySecretName,
            @Value("${ones.auth.jwt.access-ttl-minutes:60}") long accessTtlMinutes
    ) {
        return new OnesJwtProperties(
                env,
                issuer,
                keyId,
                privateKeySecretName,
                publicKeySecretName,
                Duration.ofMinutes(accessTtlMinutes)
        );
    }

    @Bean
    JwtEncoder jwtEncoder(SecretsProvider secretsProvider, OnesJwtProperties props) {
        KeyPair pair = resolveKeyPair(secretsProvider, props);
        RSAPrivateKey privateKey = (RSAPrivateKey) pair.getPrivate();
        RSAPublicKey publicKey = (RSAPublicKey) pair.getPublic();

        RSAKey jwk = new RSAKey.Builder(publicKey)
                .privateKey(privateKey)
                .keyID(props.keyId())
                .build();

        return new NimbusJwtEncoder(new ImmutableJWKSet<>(new JWKSet(jwk)));
    }

    @Bean
    JwtDecoder onesJwtDecoder(SecretsProvider secretsProvider, OnesJwtProperties props) {
        KeyPair pair = resolveKeyPair(secretsProvider, props);
        RSAPublicKey publicKey = (RSAPublicKey) pair.getPublic();

        return NimbusJwtDecoder.withPublicKey(publicKey).build();
    }

    private KeyPair resolveKeyPair(SecretsProvider secretsProvider, OnesJwtProperties props) {
        boolean hasPrivate = StringUtils.hasText(props.privateKeySecretName());
        boolean hasPublic = StringUtils.hasText(props.publicKeySecretName());

        if (hasPrivate && hasPublic) {
            PrivateKey privateKey = loadPrivateKey(secretsProvider, props.privateKeySecretName());
            PublicKey publicKey = loadPublicKey(secretsProvider, props.publicKeySecretName());
            return new KeyPair(publicKey, privateKey);
        }

        String env = props.env() != null ? props.env().trim().toLowerCase() : "dev";
        if (!env.equals("dev") && !env.equals("test")) {
            throw new IllegalStateException(
                    "Missing config: ones.auth.jwt.private-key-secret-name and ones.auth.jwt.public-key-secret-name (required for env=" + env + ")"
            );
        }

        KeyPair cached = cachedDevKeyPair;
        if (cached != null) {
            return cached;
        }

        synchronized (this) {
            if (cachedDevKeyPair != null) {
                return cachedDevKeyPair;
            }
            cachedDevKeyPair = generateRsaKeyPair();
            return cachedDevKeyPair;
        }
    }

    private static KeyPair generateRsaKeyPair() {
        try {
            KeyPairGenerator gen = KeyPairGenerator.getInstance("RSA");
            gen.initialize(2048);
            return gen.generateKeyPair();
        } catch (Exception e) {
            throw new IllegalStateException("Failed to generate RSA key pair", e);
        }
    }

    private static PrivateKey loadPrivateKey(SecretsProvider secretsProvider, String secretName) {
        if (!StringUtils.hasText(secretName)) {
            throw new IllegalStateException("Missing config: ones.auth.jwt.private-key-secret-name");
        }
        String pem = secretsProvider.getSecretString(secretName.trim());
        if (!StringUtils.hasText(pem)) {
            throw new IllegalStateException("JWT private key secret is empty: secretName=" + secretName);
        }
        return parsePemPrivateKey(pem);
    }

    private static PublicKey loadPublicKey(SecretsProvider secretsProvider, String secretName) {
        if (!StringUtils.hasText(secretName)) {
            throw new IllegalStateException("Missing config: ones.auth.jwt.public-key-secret-name");
        }
        String pem = secretsProvider.getSecretString(secretName.trim());
        if (!StringUtils.hasText(pem)) {
            throw new IllegalStateException("JWT public key secret is empty: secretName=" + secretName);
        }
        return parsePemPublicKey(pem);
    }

    private static PrivateKey parsePemPrivateKey(String pem) {
        try {
            String normalized = pem
                    .replace("-----BEGIN PRIVATE KEY-----", "")
                    .replace("-----END PRIVATE KEY-----", "")
                    .replaceAll("\\s", "");

            byte[] der = Base64.getDecoder().decode(normalized);
            PKCS8EncodedKeySpec spec = new PKCS8EncodedKeySpec(der);
            KeyFactory kf = KeyFactory.getInstance("RSA");
            return kf.generatePrivate(spec);
        } catch (Exception e) {
            throw new IllegalStateException("Failed to parse JWT private key (expected PKCS#8 PEM)", e);
        }
    }

    private static PublicKey parsePemPublicKey(String pem) {
        try {
            String normalized = pem
                    .replace("-----BEGIN PUBLIC KEY-----", "")
                    .replace("-----END PUBLIC KEY-----", "")
                    .replaceAll("\\s", "");

            byte[] der = Base64.getDecoder().decode(normalized);
            X509EncodedKeySpec spec = new X509EncodedKeySpec(der);
            KeyFactory kf = KeyFactory.getInstance("RSA");
            return kf.generatePublic(spec);
        } catch (Exception e) {
            throw new IllegalStateException("Failed to parse JWT public key (expected X.509 PEM)", e);
        }
    }
}
