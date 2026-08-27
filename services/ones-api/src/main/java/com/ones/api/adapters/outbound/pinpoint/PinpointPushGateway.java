package com.ones.api.adapters.outbound.pinpoint;

import com.ones.api.application.push.PushMessage;
import com.ones.api.application.push.ports.PushGateway;
import com.ones.api.domain.push.DeviceToken;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import software.amazon.awssdk.services.pinpoint.PinpointClient;
import software.amazon.awssdk.services.pinpoint.model.AddressConfiguration;
import software.amazon.awssdk.services.pinpoint.model.APNSMessage;
import software.amazon.awssdk.services.pinpoint.model.ChannelType;
import software.amazon.awssdk.services.pinpoint.model.DirectMessageConfiguration;
import software.amazon.awssdk.services.pinpoint.model.GCMMessage;
import software.amazon.awssdk.services.pinpoint.model.MessageRequest;
import software.amazon.awssdk.services.pinpoint.model.SendMessagesRequest;
import software.amazon.awssdk.services.pinpoint.model.SendMessagesResponse;
import software.amazon.awssdk.services.pinpoint.model.MessageResult;

import java.util.HashMap;
import java.util.Map;

public class PinpointPushGateway implements PushGateway {
    private static final Logger log = LoggerFactory.getLogger(PinpointPushGateway.class);

    private final PinpointClient client;
    private final String applicationId;

    public PinpointPushGateway(PinpointClient client, String applicationId) {
        this.client = client;
        this.applicationId = applicationId;
    }

    @Override
    public Result send(DeviceToken token, PushMessage message) throws Exception {
        ChannelType channel = mapChannel(token.getPlatform());
        if (channel == null) {
            log.debug("[Push:pinpoint] Unsupported platform {}", token.getPlatform());
            return Result.FAILED;
        }
        String address = token.getToken();
        if (address == null || address.isBlank()) return Result.FAILED;

        Map<String, AddressConfiguration> addresses = new HashMap<>();
        addresses.put(address, AddressConfiguration.builder().channelType(channel).build());

        GCMMessage gcm = GCMMessage.builder()
                .title(message.title())
                .body(message.body())
                .data(message.data())
                .priority("high")
                .build();
        APNSMessage apns = APNSMessage.builder()
                .title(message.title())
                .body(message.body())
                .badge(1)
                .sound("default")
                .data(message.data())
                .build();

        DirectMessageConfiguration dmc = DirectMessageConfiguration.builder()
                .gcmMessage(gcm)
                .apnsMessage(apns)
                .build();

        MessageRequest mr = MessageRequest.builder()
                .addresses(addresses)
                .messageConfiguration(dmc)
                .build();

        SendMessagesRequest req = SendMessagesRequest.builder()
                .applicationId(applicationId)
                .messageRequest(mr)
                .build();

        SendMessagesResponse resp = client.sendMessages(req);
        Map<String, MessageResult> result = resp.messageResponse().result();
        MessageResult r = result.get(address);
        if (r == null) return Result.FAILED;
        int status = r.statusCode() != null ? r.statusCode() : 0;
        if (status >= 200 && status < 300) return Result.OK;
        String statusStr = r.statusMessage();
        if (status == 400 || status == 410 || (statusStr != null && statusStr.toLowerCase().contains("invalid"))) {
            return Result.INVALID_TOKEN;
        }
        return Result.FAILED;
    }

    private static ChannelType mapChannel(String platform) {
        if (platform == null) return null;
        String p = platform.trim().toLowerCase();
        return switch (p) {
            case "android", "gcm", "fcm" -> ChannelType.GCM;
            case "ios", "apns" -> ChannelType.APNS;
            default -> null;
        };
    }
}
