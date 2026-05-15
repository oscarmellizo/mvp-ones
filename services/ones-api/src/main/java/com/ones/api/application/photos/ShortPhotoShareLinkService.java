package com.ones.api.application.photos;

import java.time.Instant;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.ones.api.application.photos.PhotoShortLinksService;

@Service
public class ShortPhotoShareLinkService {

    private final PhotoShortLinksService photoShortLinksService;
    private final String appBaseUrl;

    public ShortPhotoShareLinkService(
            PhotoShortLinksService photoShortLinksService,
            @Value("${ones.app.base-url:}") String appBaseUrl,
            @Value("${ones.photos.social-share-ttl-days:7}") long ttlDays
    ) {
        this.photoShortLinksService = photoShortLinksService;
        this.appBaseUrl = appBaseUrl;
    }

    public SocialShareLink create(String eventId, String photoId, String variant) {
        if (appBaseUrl == null || appBaseUrl.isBlank()) {
            throw new IllegalStateException("Missing config: ones.app.base-url");
        }

        var link = photoShortLinksService.create(eventId, photoId, variant);
        String base = appBaseUrl.trim();
        while (base.endsWith("/")) {
            base = base.substring(0, base.length() - 1);
        }

        String url = base + "/p/" + link.code();
        return new SocialShareLink(url, link.expiresAt());
    }

    public record SocialShareLink(String url, Instant expiresAt) {
    }
}
