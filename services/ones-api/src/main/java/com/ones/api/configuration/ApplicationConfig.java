package com.ones.api.configuration;

import java.time.Clock;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.ones.api.application.events.CreateEventUseCase;
import com.ones.api.application.events.GetEventUseCase;
import com.ones.api.application.events.ListEventsUseCase;
import com.ones.api.application.events.ports.EventsRepository;

@Configuration
public class ApplicationConfig {

    @Bean
    Clock clock() {
        return Clock.systemUTC();
    }

    @Bean
    CreateEventUseCase createEventUseCase(EventsRepository repository, Clock clock) {
        return new CreateEventUseCase(repository, clock);
    }

    @Bean
    ListEventsUseCase listEventsUseCase(EventsRepository repository) {
        return new ListEventsUseCase(repository);
    }

    @Bean
    GetEventUseCase getEventUseCase(EventsRepository repository) {
        return new GetEventUseCase(repository);
    }
}
