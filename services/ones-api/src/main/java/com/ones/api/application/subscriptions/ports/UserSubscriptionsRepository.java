package com.ones.api.application.subscriptions.ports;

import java.util.Optional;

import com.ones.api.domain.subscriptions.UserSubscription;

public interface UserSubscriptionsRepository {

    Optional<UserSubscription> findByUserId(String userId);

    UserSubscription upsert(UserSubscription subscription);

    void deleteByUserId(String userId);
}
