package com.ones.api.application.subscriptions.ports;

import java.util.List;
import java.util.Optional;

import com.ones.api.domain.subscriptions.SubscriptionPlan;

public interface SubscriptionPlansRepository {

    Optional<SubscriptionPlan> findById(String planId);

    List<SubscriptionPlan> findAllActive();

    SubscriptionPlan upsert(SubscriptionPlan plan);

    void deleteById(String planId);
}
