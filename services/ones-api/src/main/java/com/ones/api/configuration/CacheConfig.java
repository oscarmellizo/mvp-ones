package com.ones.api.configuration;

import java.time.Duration;

import org.springframework.cache.CacheManager;
import org.springframework.cache.caffeine.CaffeineCacheManager;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.github.benmanes.caffeine.cache.Caffeine;

@Configuration
public class CacheConfig {

    public static final String EVENTS_METADATA_CACHE = "eventsMetadata";

    @Bean
    CacheManager cacheManager() {
        CaffeineCacheManager manager = new CaffeineCacheManager(EVENTS_METADATA_CACHE);
        manager.setCaffeine(Caffeine.newBuilder().expireAfterWrite(Duration.ofHours(6)));
        return manager;
    }
}
