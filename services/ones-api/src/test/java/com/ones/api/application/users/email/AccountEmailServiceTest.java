package com.ones.api.application.users.email;

import com.ones.api.domain.users.User;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import software.amazon.awssdk.services.sesv2.SesV2Client;
import software.amazon.awssdk.services.sesv2.model.SendEmailRequest;
import software.amazon.awssdk.services.sesv2.model.SesV2Exception;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class AccountEmailServiceTest {

    private static final Instant T0 = Instant.parse("2026-09-01T00:00:00Z");
    private static final String URL = "https://api.ones.events/v1/account-exports/u1.tok";
    private static final Instant EXPIRES = Instant.parse("2026-10-10T08:00:00Z");

    private static User user(String email) {
        return new User("u1", email, "Ana", null, null, null, "Ana", "google", "es", true, T0, T0,
                "DISABLED", T0, null);
    }

    private static AccountEmailService svc(SesV2Client ses, String from, String base, boolean enabled) {
        return new AccountEmailService(ses, new SimpleMeterRegistry(), from, base, "", enabled);
    }

    private static AccountEmailService svc(SesV2Client ses) {
        return svc(ses, "donotreply@ones.events", "https://ones.events", true);
    }

    private static SendEmailRequest captured(SesV2Client ses) {
        ArgumentCaptor<SendEmailRequest> req = ArgumentCaptor.forClass(SendEmailRequest.class);
        verify(ses).sendEmail(req.capture());
        return req.getValue();
    }

    @Test
    void deactivationEmail_keepsSubject_andCallsSesOnce() {
        SesV2Client ses = mock(SesV2Client.class);

        svc(ses).sendDeactivationEmail(user("ana@example.com"), T0, T0.plusSeconds(86400L * 30));

        SendEmailRequest r = captured(ses);
        assertEquals("Confirmación de desactivación de tu cuenta", r.content().simple().subject().data());
        verifyNoMoreInteractions(ses);
    }

    @Test
    void closureEmail_withPhotos_includesLinkAndExpiry() {
        SesV2Client ses = mock(SesV2Client.class);

        assertTrue(svc(ses).sendClosureEmail(user("ana@example.com"), URL, EXPIRES));

        SendEmailRequest r = captured(ses);
        assertEquals("Tu cuenta de Ones fue cerrada", r.content().simple().subject().data());
        String text = r.content().simple().body().text().data();
        assertTrue(text.contains(URL));
        assertTrue(text.contains("2026-10-10"));
        assertTrue(text.contains("8 días"));
        String html = r.content().simple().body().html().data();
        assertTrue(html.contains("account-closure-v1"));
        assertTrue(html.contains("Descargar mis fotos"));
        assertTrue(html.contains(URL));
    }

    @Test
    void closureEmail_withoutPhotos_saysSo_andHasNoLink() {
        SesV2Client ses = mock(SesV2Client.class);

        assertTrue(svc(ses).sendClosureEmail(user("ana@example.com"), null, null));

        SendEmailRequest r = captured(ses);
        String text = r.content().simple().body().text().data();
        assertTrue(text.contains("no tenía fotos"));
        assertFalse(text.contains("account-exports"));
        String html = r.content().simple().body().html().data();
        assertFalse(html.contains("account-exports"));
        assertFalse(html.contains("Descargar mis fotos"));
    }

    @Test
    void closureEmail_sesFails_returnsFalse() {
        SesV2Client ses = mock(SesV2Client.class);
        when(ses.sendEmail(any(SendEmailRequest.class))).thenThrow(SesV2Exception.builder().message("x").build());

        assertFalse(svc(ses).sendClosureEmail(user("ana@example.com"), URL, EXPIRES));
    }

    @Test
    void closureEmail_disabled_returnsTrue_withoutCallingSes() {
        SesV2Client ses = mock(SesV2Client.class);

        assertTrue(svc(ses, "donotreply@ones.events", "https://ones.events", false)
                .sendClosureEmail(user("ana@example.com"), URL, EXPIRES));

        verifyNoInteractions(ses);
    }

    @Test
    void closureEmail_userWithoutEmail_returnsTrue_withoutCallingSes() {
        SesV2Client ses = mock(SesV2Client.class);

        assertTrue(svc(ses).sendClosureEmail(user(" "), URL, EXPIRES));

        verifyNoInteractions(ses);
    }

    @Test
    void closureEmail_misconfigured_returnsFalse_withoutCallingSes() {
        SesV2Client ses = mock(SesV2Client.class);
        User u = user("ana@example.com");

        assertFalse(svc(ses, "", "https://ones.events", true).sendClosureEmail(u, URL, EXPIRES));
        assertFalse(svc(ses, "donotreply@ones.events", "", true).sendClosureEmail(u, URL, EXPIRES));

        verifyNoInteractions(ses);
    }
}
