package com.ones.api.configuration;

import java.time.Clock;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.ones.api.application.events.CreateEventUseCase;
import com.ones.api.application.events.EventCoversService;
import com.ones.api.application.events.GetEventUseCase;
import com.ones.api.application.events.ListEventsUseCase;
import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.application.users.EnsureUserUseCase;
import com.ones.api.application.users.ports.UsersRepository;

@Configuration
public class ApplicationConfig {

    @Bean
    Clock clock() {
        return Clock.systemUTC();
    }

    @Bean
    CreateEventUseCase createEventUseCase(
            EventsRepository repository,
            Clock clock,
            EventCoversService coversService
    ) {
        return new CreateEventUseCase(repository, clock, coversService);
    }

    @Bean
    ListEventsUseCase listEventsUseCase(EventsRepository repository) {
        return new ListEventsUseCase(repository);
    }

    @Bean
    GetEventUseCase getEventUseCase(EventsRepository repository) {
        return new GetEventUseCase(repository);
    }

    @Bean
    EnsureUserUseCase ensureUserUseCase(UsersRepository repository, Clock clock) {
        return new EnsureUserUseCase(repository, clock);
    }
}
