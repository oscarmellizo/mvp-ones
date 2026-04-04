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

    @Bean
    CacheManager cacheManager() {
        CaffeineCacheManager manager = new CaffeineCacheManager();
        manager.setCacheNames(List.of(EVENTS_METADATA_CACHE, ADMIN_ACCESS_CACHE));
        manager.registerCustomCache(
                EVENTS_METADATA_CACHE,
                Caffeine.newBuilder().expireAfterWrite(Duration.ofHours(6)).build()
        );
        manager.registerCustomCache(
                ADMIN_ACCESS_CACHE,
                Caffeine.newBuilder().expireAfterWrite(Duration.ofMinutes(5)).build()
        );
        return manager;
    }
}
