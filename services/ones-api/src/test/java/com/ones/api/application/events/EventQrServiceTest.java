package com.ones.api.application.events;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.util.Arrays;

import javax.imageio.ImageIO;

import org.junit.jupiter.api.Test;

import com.google.zxing.BinaryBitmap;
import com.google.zxing.MultiFormatReader;
import com.google.zxing.client.j2se.BufferedImageLuminanceSource;
import com.google.zxing.common.HybridBinarizer;
import com.ones.api.application.events.invitelink.EventInviteLinkTokenService;

class EventQrServiceTest {

    @Test
    void generatedPosterKeepsTheSignedInviteUrlScannable() throws Exception {
        EventInviteLinkTokenService tokenService = mock(EventInviteLinkTokenService.class);
        when(tokenService.signatureForEventId("event-123")).thenReturn("signature-456");
        EventQrService service = new EventQrService(
                null,
                java.time.Clock.systemUTC(),
                null,
                tokenService,
                "https://appdev.ones.events/",
                "photos-bucket");

        String inviteUrl = service.buildInviteUrl("event-123");
        assertEquals(
                "https://appdev.ones.events/event-invite?eventId=event-123&sig=signature-456",
                inviteUrl);

        byte[] png = EventQrService.renderQrPng(
                inviteUrl, "Birthday celebration", "123456", 256);
        BufferedImage poster = ImageIO.read(new ByteArrayInputStream(png));

        assertEquals(256, poster.getWidth());
        assertTrue(poster.getHeight() > poster.getWidth());
        BufferedImage qrArea = poster.getSubimage(0, 0, 256, 256);
        var source = new BufferedImageLuminanceSource(qrArea);
        var bitmap = new BinaryBitmap(new HybridBinarizer(source));
        assertEquals(inviteUrl, new MultiFormatReader().decode(bitmap).getText());
    }

    @Test
    void posterAndContentHashChangeWhenEventMetadataChanges() {
        String inviteUrl = "https://appdev.ones.events/event-invite"
                + "?eventId=event-123&sig=signature-456";
        byte[] first = EventQrService.renderQrPng(
                inviteUrl, "Birthday celebration", "123456", 256);
        byte[] changedTitle = EventQrService.renderQrPng(
                inviteUrl, "Family reunion", "123456", 256);
        byte[] changedCode = EventQrService.renderQrPng(
                inviteUrl, "Birthday celebration", "654321", 256);

        assertFalse(Arrays.equals(first, changedTitle));
        assertFalse(Arrays.equals(first, changedCode));
        assertFalse(EventQrService.qrContentHash(
                inviteUrl, "Birthday celebration", "123456").equals(
                EventQrService.qrContentHash(
                        inviteUrl, "Family reunion", "123456")));
        assertFalse(EventQrService.qrContentHash(
                inviteUrl, "Birthday celebration", "123456").equals(
                EventQrService.qrContentHash(
                        inviteUrl, "Birthday celebration", "654321")));
    }
}
