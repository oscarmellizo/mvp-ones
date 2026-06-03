package com.ones.api.configuration;

import java.time.Duration;
import java.util.List;

import org.springframework.cache.CacheManager;
import org.springframework.cache.caffeine.CaffeineCacheManager;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.github.benmanes.caffeine.cache.Caffeine;

@Configuration
public class CacheConfig {

    public static final String EVENTS_METADATA_CACHE = "eventsMetadata";
    public static final String ADMIN_ACCESS_CACHE = "adminAccess";
    public static final String TRANSLATIONS_BY_LANGUAGE_CACHE = "translationsByLanguage";
    public static final String PHOTOS_BY_EVENT_FIRST_PAGE_CACHE = "photosByEventFirstPage";
    public static final String INVITATIONS_BY_EVENT_CACHE = "invitationsByEvent";

    @Bean
    CacheManager cacheManager() {
        CaffeineCacheManager manager = new CaffeineCacheManager();
        manager.setCacheNames(List.of(
                EVENTS_METADATA_CACHE,
                ADMIN_ACCESS_CACHE,
                TRANSLATIONS_BY_LANGUAGE_CACHE,
                PHOTOS_BY_EVENT_FIRST_PAGE_CACHE,
                INVITATIONS_BY_EVENT_CACHE
        ));
        manager.registerCustomCache(
                EVENTS_METADATA_CACHE,
                java.util.Objects.requireNonNull(
                        Caffeine.<Object, Object>newBuilder().expireAfterWrite(Duration.ofHours(6)).build()
                )
        );
        manager.registerCustomCache(
                ADMIN_ACCESS_CACHE,
                java.util.Objects.requireNonNull(
                        Caffeine.<Object, Object>newBuilder().expireAfterWrite(Duration.ofMinutes(5)).build()
                )
        );
        manager.registerCustomCache(
                TRANSLATIONS_BY_LANGUAGE_CACHE,
                java.util.Objects.requireNonNull(
                        Caffeine.<Object, Object>newBuilder().maximumSize(50).build()
                )
        );
        manager.registerCustomCache(
                PHOTOS_BY_EVENT_FIRST_PAGE_CACHE,
                java.util.Objects.requireNonNull(
                        Caffeine.<Object, Object>newBuilder().maximumSize(5_000).expireAfterWrite(Duration.ofSeconds(10)).build()
                )
        );
        manager.registerCustomCache(
                INVITATIONS_BY_EVENT_CACHE,
                java.util.Objects.requireNonNull(
                        Caffeine.<Object, Object>newBuilder().maximumSize(5_000).expireAfterWrite(Duration.ofSeconds(30)).build()
                )
        );
        return manager;
    }
}
