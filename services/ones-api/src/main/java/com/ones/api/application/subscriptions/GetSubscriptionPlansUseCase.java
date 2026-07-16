package com.ones.api.application.subscriptions;

import java.util.List;

import com.ones.api.application.subscriptions.ports.SubscriptionPlansRepository;
import com.ones.api.domain.subscriptions.SubscriptionPlan;

public class GetSubscriptionPlansUseCase {

    private final SubscriptionPlansRepository plansRepository;

    public GetSubscriptionPlansUseCase(SubscriptionPlansRepository plansRepository) {
        this.plansRepository = plansRepository;
    }

    public List<SubscriptionPlan> execute() {
        return plansRepository.findAllActive();
    }
}
