package com.ones.api.application.subscriptions.ports;

import java.util.Optional;

import com.ones.api.domain.subscriptions.PaymentProfile;

public interface PaymentProfilesRepository {

    Optional<PaymentProfile> findByUserId(String userId);

    PaymentProfile upsert(PaymentProfile profile);
}
