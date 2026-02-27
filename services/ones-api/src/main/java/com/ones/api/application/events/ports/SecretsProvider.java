package com.ones.api.application.events.ports;

public interface SecretsProvider {

    String getSecretString(String secretName);
}
