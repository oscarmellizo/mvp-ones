package com.ones.api.adapters.inbound.rest;

import java.net.URI;
import java.util.concurrent.TimeUnit;
import java.util.regex.Pattern;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.photos.PhotoShortLinksService;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;

@RestController
public class PhotoShortLinksController {

    private static final Logger log = LoggerFactory.getLogger(PhotoShortLinksController.class);
    private static final Pattern CODE_PATTERN = Pattern.compile("^[A-Za-z0-9_-]{8,64}$");

    private final PhotoShortLinksService service;
    private final MeterRegistry meterRegistry;
    private final Timer resolveTimer;
    private final Counter resolveCounter;
    private final Counter outcomeRedirect;
    private final Counter outcomeNotFound;
    private final Counter outcomeInvalid;

    public PhotoShortLinksController(PhotoShortLinksService service, MeterRegistry meterRegistry) {
        this.service = service;
        this.meterRegistry = meterRegistry;
        this.resolveTimer = Timer.builder("ones.photo_shortlink.resolve")
                .publishPercentileHistogram()
                .register(meterRegistry);
        this.resolveCounter = Counter.builder("ones.photo_shortlink.resolve.count")
                .register(meterRegistry);

        this.outcomeRedirect = Counter.builder("ones.photo_shortlink.resolve.outcome")
                .tag("outcome", "redirect")
                .register(meterRegistry);
        this.outcomeNotFound = Counter.builder("ones.photo_shortlink.resolve.outcome")
                .tag("outcome", "not_found")
                .register(meterRegistry);
        this.outcomeInvalid = Counter.builder("ones.photo_shortlink.resolve.outcome")
                .tag("outcome", "invalid")
                .register(meterRegistry);
    }

    @GetMapping("/p/{code}")
    public ResponseEntity<Void> resolve(@PathVariable("code") String code) {
        long startNanos = System.nanoTime();
        String outcome = "not_found";
        try {
            if (code == null || code.isBlank() || !CODE_PATTERN.matcher(code.trim()).matches()) {
                outcome = "invalid";
                return ResponseEntity.notFound().build();
            }

            var resolved = service.resolve(code.trim()).orElse(null);
            if (resolved == null) {
                outcome = "not_found";
                return ResponseEntity.notFound().build();
            }

            String target = resolved.imageUrl();

            HttpHeaders headers = new HttpHeaders();
            headers.setLocation(URI.create(target));
            headers.setCacheControl("public, max-age=60");
            outcome = "redirect";
            return new ResponseEntity<>(headers, HttpStatus.FOUND);
        } finally {
            long tookNanos = System.nanoTime() - startNanos;
            resolveTimer.record(tookNanos, TimeUnit.NANOSECONDS);
            resolveCounter.increment();

            if ("redirect".equals(outcome)) {
                outcomeRedirect.increment();
            } else if ("invalid".equals(outcome)) {
                outcomeInvalid.increment();
            } else {
                outcomeNotFound.increment();
            }

            int codeLen = code == null ? 0 : code.length();
            log.info("[PhotoShortLinksController.resolve] outcome={} codeLen={} tookMs={}", outcome, codeLen, tookNanos / 1_000_000.0);
        }
    }

    private static String urlEncode(String s) {
        if (s == null) return "";
        return java.net.URLEncoder.encode(s, java.nio.charset.StandardCharsets.UTF_8);
    }
}
