package com.ones.api.adapters.outbound.noop;

import com.ones.api.application.push.PushMessage;
import com.ones.api.application.push.ports.PushGateway;
import com.ones.api.domain.push.DeviceToken;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class LoggingPushGateway implements PushGateway {
    private static final Logger log = LoggerFactory.getLogger(LoggingPushGateway.class);
    @Override
    public Result send(DeviceToken token, PushMessage message) {
        log.info("[Push:noop] userId={} platform={} tokenHash={} title={} body={} dataKeys={}",
                token.getUserId(), token.getPlatform(), token.getTokenHash(),
                message.title(), message.body(), message.data() != null ? message.data().keySet() : null);
        return Result.OK;
    }
}
