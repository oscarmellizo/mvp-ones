package com.ones.api.adapters.outbound.hybrid;

import com.ones.api.application.push.PushMessage;
import com.ones.api.application.push.ports.PushGateway;
import com.ones.api.domain.push.DeviceToken;

public class RoutingPushGateway implements PushGateway {
    private final PushGateway iosGateway;
    private final PushGateway androidGateway;
    private final PushGateway fallbackGateway;

    public RoutingPushGateway(PushGateway iosGateway, PushGateway androidGateway, PushGateway fallbackGateway) {
        this.iosGateway = iosGateway;
        this.androidGateway = androidGateway;
        this.fallbackGateway = fallbackGateway;
    }

    @Override
    public Result send(DeviceToken token, PushMessage message) throws Exception {
        if (token == null || token.getPlatform() == null) return Result.FAILED;
        String p = token.getPlatform().trim().toLowerCase();
        PushGateway gw = switch (p) {
            case "ios", "apns" -> iosGateway;
            case "android", "gcm", "fcm" -> androidGateway;
            default -> fallbackGateway;
        };
        if (gw == null) gw = fallbackGateway;
        return gw != null ? gw.send(token, message) : Result.FAILED;
    }
}
