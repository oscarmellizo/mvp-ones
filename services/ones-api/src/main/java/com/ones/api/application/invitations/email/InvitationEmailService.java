package com.ones.api.application.invitations.email;

import java.time.ZoneId;
import java.time.format.DateTimeFormatter;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;

import com.ones.api.domain.invitations.Invitation;

import software.amazon.awssdk.services.sesv2.SesV2Client;
import software.amazon.awssdk.services.sesv2.model.Body;
import software.amazon.awssdk.services.sesv2.model.Content;
import software.amazon.awssdk.services.sesv2.model.Destination;
import software.amazon.awssdk.services.sesv2.model.EmailContent;
import software.amazon.awssdk.services.sesv2.model.Message;
import software.amazon.awssdk.services.sesv2.model.SendEmailRequest;

@Component
public class InvitationEmailService {

    private static final Logger log = LoggerFactory.getLogger(InvitationEmailService.class);

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm").withZone(ZoneId.of("UTC"));

    private final SesV2Client ses;
    private final InvitationActionTokenService tokenService;
    private final String fromAddress;
    private final String publicBaseUrl;
    private final String logoUrl;
    private final boolean enabled;

    private final Counter sentCounter;
    private final Counter failedCounter;

    public InvitationEmailService(
            SesV2Client ses,
            InvitationActionTokenService tokenService,
            MeterRegistry meterRegistry,
            @Value("${ones.email.from:}") String fromAddress,
            @Value("${ones.email.public-base-url:${ones.app.base-url:}}") String publicBaseUrl,
            @Value("${ones.email.logo-url:}") String logoUrl,
            @Value("${ones.email.enabled:false}") boolean enabled
    ) {
        this.ses = ses;
        this.tokenService = tokenService;
        this.fromAddress = fromAddress;
        this.publicBaseUrl = publicBaseUrl;
        this.logoUrl = logoUrl;
        this.enabled = enabled;

        log.info(
                "[InvitationEmailService] enabled={} from='{}' publicBaseUrl='{}' logoUrl='{}'",
                enabled,
                fromAddress,
                publicBaseUrl,
                logoUrl
        );

        this.sentCounter = Counter.builder("ones.email.invitation.sent").register(meterRegistry);
        this.failedCounter = Counter.builder("ones.email.invitation.failed").register(meterRegistry);
    }

    @Async("emailExecutor")
    public void sendInvitation(Invitation invitation) {
        if (!enabled) {
            return;
        }
        if (invitation == null) {
            return;
        }
        if (fromAddress == null || fromAddress.isBlank()) {
            return;
        }
        if (publicBaseUrl == null || publicBaseUrl.isBlank()) {
            return;
        }

        String to = invitation.getInviteeEmail();
        if (to == null || to.isBlank()) {
            return;
        }

        String acceptToken = tokenService.create(invitation.getEventId(), invitation.getInviteeEmail(), InvitationActionTokenService.Action.accept);
        String rejectToken = tokenService.create(invitation.getEventId(), invitation.getInviteeEmail(), InvitationActionTokenService.Action.reject);

        String acceptUrl = normalizeBase(publicBaseUrl) + "/invitation?token=" + acceptToken + "&action=accept";
        String rejectUrl = normalizeBase(publicBaseUrl) + "/invitation?token=" + rejectToken + "&action=reject";
        String viewUrl = normalizeBase(publicBaseUrl) + "/invitation?token=" + acceptToken;

        String subject = "Invitación: " + safe(invitation.getEventTitle());

        String html = renderHtml(invitation, viewUrl, acceptUrl, rejectUrl);
        String text = renderText(invitation, viewUrl, acceptUrl, rejectUrl);

        try {
            SendEmailRequest req = SendEmailRequest.builder()
                    .fromEmailAddress(fromAddress)
                    .destination(Destination.builder().toAddresses(to).build())
                    .content(EmailContent.builder()
                            .simple(Message.builder()
                                    .subject(Content.builder().data(subject).charset("UTF-8").build())
                                    .body(Body.builder()
                                            .html(Content.builder().data(html).charset("UTF-8").build())
                                            .text(Content.builder().data(text).charset("UTF-8").build())
                                            .build())
                                    .build())
                            .build())
                    .build();

            ses.sendEmail(req);
            sentCounter.increment();
        } catch (software.amazon.awssdk.services.sesv2.model.SesV2Exception e) {
            failedCounter.increment();
            log.error("[InvitationEmailService] SES error sending to={} eventId={} awsErrorCode={} message={}",
                    to, invitation.getEventId(), e.awsErrorDetails() != null ? e.awsErrorDetails().errorCode() : "unknown", e.getMessage());
        } catch (Exception e) {
            failedCounter.increment();
            log.error("[InvitationEmailService] Unexpected error sending to={} eventId={} errorType={} message={}",
                    to, invitation.getEventId(), e.getClass().getSimpleName(), e.getMessage());
        }
    }

    private String renderText(Invitation inv, String viewUrl, String acceptUrl, String rejectUrl) {
        String when = DATE_FMT.format(inv.getEventStartAt());
        String where = inv.getEventLocation() != null ? inv.getEventLocation() : "";
        return "Te han invitado a un evento\n\n"
                + "Evento: " + safe(inv.getEventTitle()) + "\n"
                + "Cuándo: " + when + " UTC\n"
                + (where.isBlank() ? "" : ("Dónde: " + where + "\n"))
                + "\n"
                + "Ver evento: " + viewUrl + "\n"
                + "Aceptar: " + acceptUrl + "\n"
                + "Rechazar: " + rejectUrl + "\n";
    }

    private String renderHtml(Invitation inv, String viewUrl, String acceptUrl, String rejectUrl) {
        String when = DATE_FMT.format(inv.getEventStartAt());
        String title = escapeHtml(safe(inv.getEventTitle()));
        String where = inv.getEventLocation() != null ? escapeHtml(inv.getEventLocation()) : "";

        String logoBlock = "";
        String resolvedLogoUrl = (logoUrl != null && !logoUrl.isBlank()) ? logoUrl.trim() : null;
        if (resolvedLogoUrl == null || resolvedLogoUrl.isBlank()) {
            String base = publicBaseUrl != null ? publicBaseUrl.trim() : "";
            if (!base.isBlank()) {
                while (base.endsWith("/")) {
                    base = base.substring(0, base.length() - 1);
                }
                resolvedLogoUrl = base + "/assets/assets/branding/ones-logo.png";
            }
        }

        if (resolvedLogoUrl != null && !resolvedLogoUrl.isBlank()) {
            logoBlock = "<div style=\"margin-bottom:10px\"><img src=\"" + escapeHtml(resolvedLogoUrl) + "\" alt=\"Ones\" width=\"48\" height=\"48\" style=\"display:block;border-radius:12px;background:#FFFFFF\"/></div>";
        }

        String whereBlock = where.isBlank() ? "" : ("<div style=\"margin-top:6px;color:#374151;font-size:14px\"><b>Dónde:</b> " + where + "</div>");

        return "<!doctype html>"
                + "<html data-ones-template=\"invitation-v2\"><head><meta charset=\"utf-8\"></head><body style=\"margin:0;padding:0;background:#FAB14E;font-family:Arial,sans-serif\">"
                + "<div style=\"max-width:600px;margin:0 auto;padding:24px\">"
                + "<div style=\"background:#4A036E;color:#fff;padding:18px 20px;border-radius:12px\">"
                + logoBlock
                + "<div style=\"font-size:14px;opacity:0.9\">Ones Events</div>"
                + "<div style=\"font-size:20px;font-weight:700;margin-top:6px\">Invitación a: " + title + "</div>"
                + "</div>"
                + "<div style=\"background:#ffffff;padding:20px;border-radius:12px;margin-top:12px\">"
                + "<div style=\"color:#111827;font-size:16px;font-weight:700\">Detalles</div>"
                + "<div style=\"margin-top:10px;color:#374151;font-size:14px\"><b>Cuándo:</b> " + escapeHtml(when) + " UTC</div>"
                + whereBlock
                + "<div style=\"margin-top:16px\">"
                + button("Ver evento", viewUrl, "#5C036E")
                + "</div>"
                + "<div style=\"margin-top:14px\">"
                + button("Aceptar", acceptUrl, "#4A036E")
                + "</div>"
                + "<div style=\"margin-top:10px\">"
                + button("Rechazar", rejectUrl, "#E25555")
                + "</div>"
                + "<div style=\"margin-top:16px;color:#6b7280;font-size:12px\">Si no esperabas esta invitación, puedes ignorar este correo.</div>"
                + "</div>"
                + "</div>"
                + "</body></html>";
    }

    private static String button(String label, String href, String color) {
        return "<a href=\"" + escapeHtml(href) + "\" style=\"display:inline-block;width:100%;text-align:center;padding:12px 14px;border-radius:10px;background:"
                + color
                + ";color:#fff;text-decoration:none;font-weight:700\">" + escapeHtml(label) + "</a>";
    }

    private static String normalizeBase(String base) {
        String b = base.trim();
        while (b.endsWith("/")) {
            b = b.substring(0, b.length() - 1);
        }
        return b;
    }

    private static String safe(String s) {
        return s != null ? s : "";
    }

    private static String escapeHtml(String in) {
        if (in == null) return "";
        return in.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;");
    }
}
