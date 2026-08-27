package com.ones.api.application.push.ports;

import com.ones.api.domain.push.DeviceToken;
import java.util.List;

public interface DeviceTokensRepository {
    DeviceToken upsert(DeviceToken token);
    void deleteByUserAndTokenHash(String userId, String platform, String tokenHash);
    List<DeviceToken> listByUserId(String userId, int limit);
}
