package com.ones.api.adapters.outbound.aws;

import org.springframework.stereotype.Component;

import com.ones.api.application.events.ports.SecretsProvider;

import software.amazon.awssdk.services.secretsmanager.SecretsManagerClient;
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueRequest;

@Component
public class AwsSecretsProvider implements SecretsProvider {

    private final SecretsManagerClient client;

    public AwsSecretsProvider(SecretsManagerClient client) {
        this.client = client;
    }

    @Override
    public String getSecretString(String secretName) {
        return client.getSecretValue(GetSecretValueRequest.builder().secretId(secretName).build())
                .secretString();
    }
}
