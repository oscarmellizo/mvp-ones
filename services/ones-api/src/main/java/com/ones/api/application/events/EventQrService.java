package com.ones.api.application.events;

import java.awt.Color;
import java.awt.Font;
import java.awt.FontMetrics;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import javax.imageio.ImageIO;

import com.google.zxing.BarcodeFormat;
import com.google.zxing.EncodeHintType;
import com.google.zxing.client.j2se.MatrixToImageWriter;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel;
import com.google.zxing.qrcode.QRCodeWriter;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.ones.api.application.events.invitelink.EventInviteLinkClosedException;
import com.ones.api.application.events.invitelink.EventInviteLinkTokenService;
import com.ones.api.application.events.ports.ObjectStoragePresigner;
import com.ones.api.domain.events.Event;

import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.HeadObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.S3Exception;

@Service
public class EventQrService {

    private static final Logger log = LoggerFactory.getLogger(EventQrService.class);
    private static final Duration MAX_S3_PRESIGN_TTL = Duration.ofDays(7);

    private final S3Client s3;
    private final Clock clock;
    private final ObjectStoragePresigner objectStoragePresigner;
    private final EventInviteLinkTokenService tokenService;
    private final String appBaseUrl;
    private final String photosBucket;

    public EventQrService(
            S3Client s3,
            Clock clock,
            ObjectStoragePresigner objectStoragePresigner,
            EventInviteLinkTokenService tokenService,
            @Value("${ones.app.base-url}") String appBaseUrl,
            @Value("${ones.s3.events.photos.bucket}") String photosBucket
    ) {
        this.s3 = s3;
        this.clock = clock;
        this.objectStoragePresigner = objectStoragePresigner;
        this.tokenService = tokenService;
        this.appBaseUrl = appBaseUrl;
        this.photosBucket = photosBucket;
    }

    public QrResult generateAndUpload(Event event) {
        final String eventId = event.getEventId();
        final Instant eventEndsAt = event.getEndAt();
        final String url = buildInviteUrl(eventId);
        final String title = normalizeText(event.getTitle(), "Evento");
        final String eventCode = normalizeText(event.getEventCode(), "");
        final String hash = qrContentHash(url, title, eventCode);

        final String baseKey = "events/" + eventId + "/qr/";
        final String key1024 = baseKey + "qr-" + hash + "-1024.png";
        final String key256 = baseKey + "qr-" + hash + "-256.png";
        final String keyLatest = baseKey + "qr-latest.png";

        try {
            if (!exists(photosBucket, key1024)) {
                byte[] png1024 = renderQrPng(url, title, eventCode, 1024);
                putPng(photosBucket, key1024, png1024, Duration.ofDays(365), true);
                log.info("Uploaded event QR 1024: bucket={}, key={}", photosBucket, key1024);
            }

            if (!exists(photosBucket, key256)) {
                byte[] png256 = renderQrPng(url, title, eventCode, 256);
                putPng(photosBucket, key256, png256, Duration.ofDays(365), true);
                log.info("Uploaded event QR 256: bucket={}, key={}", photosBucket, key256);
            }

            // Always refresh latest with a short TTL to avoid staleness
            byte[] pngLatest = renderQrPng(url, title, eventCode, 1024);
            putPng(photosBucket, keyLatest, pngLatest, Duration.ofMinutes(5), false);

            return new QrResult(
                    presignedUrl(key1024, eventEndsAt),
                    presignedUrl(key256, eventEndsAt),
                    presignedUrl(keyLatest, eventEndsAt),
                    hash
            );
        } catch (RuntimeException e) {
            log.warn("Failed to generate/upload event QR: eventId={}", eventId, e);
            throw e;
        }
    }

    public String latestPublicUrl(Event event) {
        final String key = "events/" + event.getEventId() + "/qr/qr-latest.png";
        return presignedUrl(key, event.getEndAt());
    }

    private boolean exists(String bucket, String key) {
        try {
            s3.headObject(HeadObjectRequest.builder().bucket(bucket).key(key).build());
            return true;
        } catch (S3Exception e) {
            if (e.statusCode() == 404) return false;
            if (e.statusCode() == 403) {
                log.warn("Unable to verify event QR object; proceeding with upload: bucket={}, key={}", bucket, key);
                return false;
            }
            String code = (e.awsErrorDetails() != null) ? e.awsErrorDetails().errorCode() : null;
            if ("NotFound".equals(code) || "NoSuchKey".equals(code)) return false;
            throw e;
        }
    }

    private void putPng(String bucket, String key, byte[] png, Duration cacheTtl, boolean immutable) {
        PutObjectRequest put = PutObjectRequest.builder()
                .bucket(bucket)
                .key(key)
                .contentType("image/png")
                .cacheControl(buildCacheControl(cacheTtl, immutable))
                .build();
        s3.putObject(put, RequestBody.fromBytes(png));
    }

    private static String buildCacheControl(Duration ttl, boolean immutable) {
        long seconds = Math.max(0, ttl.getSeconds());
        return immutable
                ? "private, max-age=" + seconds + ", immutable"
                : "private, max-age=" + seconds;
    }

    private String presignedUrl(String key, Instant eventEndsAt) {
        Duration remaining = Duration.between(clock.instant(), eventEndsAt);
        if (remaining.isZero() || remaining.isNegative()) {
            throw new EventInviteLinkClosedException("Event has ended");
        }
        Duration ttl = remaining.compareTo(MAX_S3_PRESIGN_TTL) > 0 ? MAX_S3_PRESIGN_TTL : remaining;
        return objectStoragePresigner.presignGet(photosBucket, key, ttl).toString();
    }

    private static String sha256Hex(String data) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] digest = md.digest(data.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder(digest.length * 2);
            for (byte b : digest) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (Exception e) {
            throw new IllegalStateException("Unable to hash data", e);
        }
    }

    static byte[] renderQrPng(
            String text,
            String eventTitle,
            String eventCode,
            int qrSizePx
    ) {
        try {
            Map<EncodeHintType, Object> hints = new HashMap<>();
            hints.put(EncodeHintType.ERROR_CORRECTION, ErrorCorrectionLevel.Q);
            hints.put(EncodeHintType.MARGIN, 2); // quiet zone
            QRCodeWriter writer = new QRCodeWriter();
            BitMatrix matrix =
                    writer.encode(text, BarcodeFormat.QR_CODE, qrSizePx, qrSizePx, hints);
            BufferedImage qrImage = MatrixToImageWriter.toBufferedImage(matrix);

            String title = normalizeText(eventTitle, "Evento");
            String codeLabel = normalizeText(eventCode, "").isEmpty()
                    ? "Código de evento no disponible"
                    : "Código de evento: " + normalizeText(eventCode, "");
            int horizontalPadding = Math.max(8, qrSizePx / 16);
            int textWidth = qrSizePx - horizontalPadding * 2;
            Font titleFont = new Font(
                    Font.SANS_SERIF, Font.BOLD, Math.max(12, qrSizePx / 22));
            Font codeFont = new Font(
                    Font.SANS_SERIF, Font.PLAIN, Math.max(10, qrSizePx / 30));

            BufferedImage metricsImage =
                    new BufferedImage(1, 1, BufferedImage.TYPE_INT_RGB);
            Graphics2D metricsGraphics = metricsImage.createGraphics();
            metricsGraphics.setFont(titleFont);
            FontMetrics titleMetrics = metricsGraphics.getFontMetrics();
            List<String> titleLines = wrapText(title, titleMetrics, textWidth);
            metricsGraphics.setFont(codeFont);
            FontMetrics codeMetrics = metricsGraphics.getFontMetrics();
            List<String> codeLines = wrapText(codeLabel, codeMetrics, textWidth);
            metricsGraphics.dispose();

            int topPadding = Math.max(8, qrSizePx / 32);
            int sectionGap = Math.max(5, qrSizePx / 48);
            int bottomPadding = Math.max(8, qrSizePx / 32);
            int posterHeight = qrSizePx
                    + topPadding
                    + titleMetrics.getHeight() * titleLines.size()
                    + sectionGap
                    + codeMetrics.getHeight() * codeLines.size()
                    + bottomPadding;
            BufferedImage image = new BufferedImage(
                    qrSizePx, posterHeight, BufferedImage.TYPE_INT_RGB);
            Graphics2D graphics = image.createGraphics();
            graphics.setColor(Color.WHITE);
            graphics.fillRect(0, 0, image.getWidth(), image.getHeight());
            graphics.setRenderingHint(
                    RenderingHints.KEY_ANTIALIASING,
                    RenderingHints.VALUE_ANTIALIAS_ON);
            graphics.setRenderingHint(
                    RenderingHints.KEY_TEXT_ANTIALIASING,
                    RenderingHints.VALUE_TEXT_ANTIALIAS_ON);
            graphics.drawImage(qrImage, 0, 0, null);

            int baseline = qrSizePx + topPadding + titleMetrics.getAscent();
            graphics.setColor(Color.BLACK);
            graphics.setFont(titleFont);
            for (String line : titleLines) {
                graphics.drawString(
                        line,
                        (qrSizePx - titleMetrics.stringWidth(line)) / 2,
                        baseline);
                baseline += titleMetrics.getHeight();
            }

            baseline = qrSizePx
                    + topPadding
                    + titleMetrics.getHeight() * titleLines.size()
                    + sectionGap
                    + codeMetrics.getAscent();
            graphics.setFont(codeFont);
            for (String line : codeLines) {
                graphics.drawString(
                        line,
                        (qrSizePx - codeMetrics.stringWidth(line)) / 2,
                        baseline);
                baseline += codeMetrics.getHeight();
            }
            graphics.dispose();

            ByteArrayOutputStream out = new ByteArrayOutputStream();
            ImageIO.write(image, "PNG", out);
            return out.toByteArray();
        } catch (Exception e) {
            throw new IllegalStateException("Failed to render QR image", e);
        }
    }

    private static List<String> wrapText(
            String text,
            FontMetrics metrics,
            int maxWidth
    ) {
        List<String> lines = new ArrayList<>();
        StringBuilder line = new StringBuilder();
        for (String word : text.split("\\s+")) {
            String candidate = line.length() == 0
                    ? word
                    : line + " " + word;
            if (line.length() > 0 && metrics.stringWidth(candidate) > maxWidth) {
                lines.add(line.toString());
                line.setLength(0);
            }
            if (line.length() > 0) {
                line.append(' ');
            }
            line.append(word);
        }
        if (line.length() > 0) {
            lines.add(line.toString());
        }
        return lines;
    }

    private static String normalizeText(String value, String fallback) {
        if (value == null || value.isBlank()) {
            return fallback;
        }
        return value.trim().replaceAll("\\s+", " ");
    }

    static String qrContentHash(String inviteUrl, String title, String eventCode) {
        return sha256Hex("event-qr-poster-v1\n"
                + inviteUrl + "\n"
                + normalizeText(title, "Evento") + "\n"
                + normalizeText(eventCode, ""));
    }

    String buildInviteUrl(String eventId) {
        String base = appBaseUrl != null ? appBaseUrl.trim() : "";
        while (base.endsWith("/")) {
            base = base.substring(0, base.length() - 1);
        }
        if (base.isBlank()) {
            throw new IllegalStateException("Missing config: ones.app.base-url");
        }
        String sig = tokenService.signatureForEventId(eventId);
        return base
                + "/event-invite?eventId=" + urlEncode(eventId)
                + "&sig=" + urlEncode(sig);
    }

    private static String urlEncode(String s) {
        return URLEncoder.encode(s, StandardCharsets.UTF_8).replace("+", "%20");
    }

    public record QrResult(String urlLarge, String urlSmall, String urlLatest, String hash) {}
}
