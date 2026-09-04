package com.ones.api.application.push.ports;

import com.ones.api.application.push.PushMessage;
import com.ones.api.domain.push.DeviceToken;

public interface PushGateway {
    enum Result { OK, INVALID_TOKEN, FAILED }
    Result send(DeviceToken token, PushMessage message) throws Exception;
}
