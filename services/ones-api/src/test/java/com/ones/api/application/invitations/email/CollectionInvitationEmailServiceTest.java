package com.ones.api.application.invitations.email;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import com.ones.api.application.users.ports.UsersRepository;

import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import software.amazon.awssdk.services.sesv2.SesV2Client;
import software.amazon.awssdk.services.sesv2.model.SendEmailRequest;

class CollectionInvitationEmailServiceTest {
    @Test
    void sendsBrandedCollectionInvitationWithEscapedDetailsAndActions() {
        SesV2Client ses = mock(SesV2Client.class);
        InvitationActionTokenService tokenService =
                mock(InvitationActionTokenService.class);
        when(tokenService.create(
                "collection:collection-1",
                "invitee@example.com",
                InvitationActionTokenService.Action.accept
        )).thenReturn("accept-token");
        when(tokenService.create(
                "collection:collection-1",
                "invitee@example.com",
                InvitationActionTokenService.Action.reject
        )).thenReturn("reject-token");

        InvitationEmailService service = new InvitationEmailService(
                ses,
                tokenService,
                mock(UsersRepository.class),
                new SimpleMeterRegistry(),
                "no-reply@ones.events",
                "https://appdev.ones.events/",
                "https://cdn.ones.events/ones-logo.png",
                true
        );

        service.sendCollectionInvitation(
                "collection-1",
                "Familia & <Recuerdos>",
                "invitee@example.com",
                "María"
        );

        ArgumentCaptor<SendEmailRequest> request =
                ArgumentCaptor.forClass(SendEmailRequest.class);
        verify(ses).sendEmail(request.capture());
        var message = request.getValue().content().simple();
        String html = message.body().html().data();
        String text = message.body().text().data();

        assertEquals("invitee@example.com",
                request.getValue().destination().toAddresses().get(0));
        assertEquals(
                "Invitaci\u00F3n a unirte a Familia & <Recuerdos> en ONES",
                message.subject().data()
        );
        assertTrue(html.contains("data-ones-template=\"collection-invitation-v2\""));
        assertTrue(html.contains("https://cdn.ones.events/ones-logo.png"));
        assertTrue(html.contains("Familia &amp; &lt;Recuerdos&gt;"));
        assertTrue(html.contains("Mar\u00EDa"));
        assertTrue(html.contains(
                "https://appdev.ones.events/collection-invitation?token=accept-token"));
        assertTrue(html.contains(
                "https://appdev.ones.events/collection-invitation?token=reject-token"));
        assertTrue(html.contains("Aceptar invitación"));
        assertTrue(html.contains("Rechazar invitación"));
        assertTrue(text.contains("Mar\u00EDa te invit\u00F3 a unirte"));
        assertTrue(text.contains("Aceptar invitación:"));
        assertTrue(text.contains("Rechazar invitación:"));
    }
}
