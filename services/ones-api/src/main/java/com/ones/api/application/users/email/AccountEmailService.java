package com.ones.api.application.users.email;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import software.amazon.awssdk.services.sesv2.SesV2Client;
import software.amazon.awssdk.services.sesv2.model.Body;
import software.amazon.awssdk.services.sesv2.model.Content;
import software.amazon.awssdk.services.sesv2.model.Destination;
import software.amazon.awssdk.services.sesv2.model.EmailContent;
import software.amazon.awssdk.services.sesv2.model.Message;
import software.amazon.awssdk.services.sesv2.model.SendEmailRequest;

import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;

import com.ones.api.domain.users.User;

@Component
public class AccountEmailService {

    private static final Logger log = LoggerFactory.getLogger(AccountEmailService.class);

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm").withZone(ZoneId.of("UTC"));

    private final SesV2Client ses;
    private final String fromAddress;
    private final String publicBaseUrl;
    private final String logoUrl;
    private final boolean enabled;

    private final Counter sentCounter;
    private final Counter failedCounter;

    public AccountEmailService(
            SesV2Client ses,
            MeterRegistry meterRegistry,
            @Value("${ones.email.from:}") String fromAddress,
            @Value("${ones.email.public-base-url:${ones.app.base-url:}}") String publicBaseUrl,
            @Value("${ones.email.logo-url:}") String logoUrl,
            @Value("${ones.email.enabled:false}") boolean enabled
    ) {
        this.ses = ses;
        this.fromAddress = fromAddress;
        this.publicBaseUrl = publicBaseUrl;
        this.logoUrl = logoUrl;
        this.enabled = enabled;
        this.sentCounter = Counter.builder("ones.email.account_deactivation.sent").register(meterRegistry);
        this.failedCounter = Counter.builder("ones.email.account_deactivation.failed").register(meterRegistry);
        log.info("[AccountEmailService] enabled={} from='{}' publicBaseUrl='{}' logoUrl='{}'", enabled, fromAddress, publicBaseUrl, logoUrl);
    }

    public void sendDeactivationEmail(User user, Instant disabledAt, Instant scheduledPhotoDeliveryAt) {
        if (!enabled) return;
        if (user == null) return;
        if (fromAddress == null || fromAddress.isBlank()) return;
        if (publicBaseUrl == null || publicBaseUrl.isBlank()) return;
        final String to = user.getEmail();
        if (to == null || to.isBlank()) return;

        final String subject = "Confirmación de desactivación de tu cuenta";
        final String html = renderHtml(user, disabledAt, scheduledPhotoDeliveryAt);
        final String text = renderText(user, disabledAt, scheduledPhotoDeliveryAt);

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
            log.error("[AccountEmailService] SES error sending to={} userId={} awsErrorCode={} message={}",
                    to, user.getUserId(), e.awsErrorDetails() != null ? e.awsErrorDetails().errorCode() : "unknown", e.getMessage());
        } catch (Exception e) {
            failedCounter.increment();
            log.error("[AccountEmailService] Unexpected error sending to={} userId={} errorType={} message={}",
                    to, user.getUserId(), e.getClass().getSimpleName(), e.getMessage());
        }
    }

    private String renderText(User user, Instant disabledAt, Instant scheduledPhotoDeliveryAt) {
        return "Hola " + safe(user.getPreferredName()) + ",\n\n" +
                "Confirmamos que tu cuenta ha sido desactivada el " + DATE_FMT.format(disabledAt) + " UTC.\n" +
                "Si vuelves a iniciar sesión dentro de los próximos 30 días, tu cuenta se reactivará automáticamente.\n" +
                "Pasados 30 días (estimado: " + DATE_FMT.format(scheduledPhotoDeliveryAt) + ") te enviaremos tus fotos al correo registrado y procederemos al cierre definitivo de tu cuenta.\n\n" +
                "Para reactivar, inicia sesión: " + normalizeBase(publicBaseUrl) + "/login\n";
    }

    private String renderHtml(User user, Instant disabledAt, Instant scheduledPhotoDeliveryAt) {
        String resolvedLogoUrl = (logoUrl != null && !logoUrl.isBlank()) ? logoUrl.trim() : null;
        if (resolvedLogoUrl == null || resolvedLogoUrl.isBlank()) {
            String base = publicBaseUrl != null ? publicBaseUrl.trim() : "";
            if (!base.isBlank()) {
                while (base.endsWith("/")) base = base.substring(0, base.length() - 1);
                resolvedLogoUrl = base + "/assets/assets/branding/ones-logo.png";
            }
        }
        String loginUrl = normalizeBase(publicBaseUrl) + "/login";
        String logoBlock = (resolvedLogoUrl != null && !resolvedLogoUrl.isBlank())
                ? ("<div style=\"margin-bottom:10px\"><img src=\"" + escapeHtml(resolvedLogoUrl) +
                "\" alt=\"Ones\" width=\"48\" height=\"48\" style=\"display:block;border-radius:12px;background:#FFFFFF\"/></div>")
                : "";

        return "<!doctype html>" +
                "<html data-ones-template=\"account-deactivation-v1\"><head><meta charset=\"utf-8\"></head>" +
                "<body style=\"margin:0;padding:0;background:#F5F5F7;font-family:Arial,sans-serif\">" +
                "<div style=\"max-width:600px;margin:0 auto;padding:24px\">" +
                "<div style=\"background:#4A036E;color:#fff;padding:18px 20px;border-radius:12px\">" +
                logoBlock +
                "<div style=\"font-size:20px;font-weight:700;margin-top:6px\">Desactivación de cuenta</div>" +
                "</div>" +
                "<div style=\"background:#ffffff;padding:20px;border-radius:12px;margin-top:12px\">" +
                "<div style=\"color:#111827;font-size:16px;font-weight:700\">Hola " + escapeHtml(safe(user.getPreferredName())) + ",</div>" +
                "<div style=\"margin-top:10px;color:#374151;font-size:14px\">Confirmamos que tu cuenta ha sido <b>desactivada</b> el " + escapeHtml(DATE_FMT.format(disabledAt)) + " UTC.</div>" +
                "<div style=\"margin-top:10px;color:#374151;font-size:14px\">Si vuelves a iniciar sesión dentro de los próximos <b>30 días</b>, tu cuenta se <b>reactivará automáticamente</b>.</div>" +
                "<div style=\"margin-top:10px;color:#374151;font-size:14px\">Pasados 30 días (estimado: <b>" + escapeHtml(DATE_FMT.format(scheduledPhotoDeliveryAt)) + "</b>), te <b>enviaremos tus fotos</b> al correo registrado y procederemos al cierre definitivo de tu cuenta.</div>" +
                "<div style=\"margin-top:16px\"><a href=\"" + escapeHtml(loginUrl) + "\" style=\"display:inline-block;width:100%;text-align:center;padding:12px 14px;border-radius:10px;background:#6C47FF;color:#fff;text-decoration:none;font-weight:700\">Reactivar cuenta</a></div>" +
                "<div style=\"margin-top:12px;color:#6b7280;font-size:12px\">Si el botón no funciona, copia y pega este enlace en tu navegador:<br/><a href=\"" + escapeHtml(loginUrl) + "\" style=\"color:#6C47FF\">" + escapeHtml(loginUrl) + "</a></div>" +
                "</div>" +
                "</div>" +
                "</body></html>";
    }

    private static String safe(String s) { return s != null ? s : ""; }

    private static String escapeHtml(String in) {
        if (in == null) return "";
        return in.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;");
    }

    private static String normalizeBase(String base) {
        String b = base.trim();
        while (b.endsWith("/")) b = b.substring(0, b.length() - 1);
        return b;
    }
}
