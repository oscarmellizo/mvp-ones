package com.ones.api.configuration;

import java.time.Clock;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.ones.api.application.invitations.InvitationsService;
import com.ones.api.application.invitations.ports.InvitationsRepository;
import com.ones.api.application.events.CreateEventUseCase;
import com.ones.api.application.events.EventCoversService;
import com.ones.api.application.events.GetEventUseCase;
import com.ones.api.application.events.InviteEventGuestsUseCase;
import com.ones.api.application.events.ListEventGuestsUseCase;
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
            InvitationsRepository invitationsRepository,
            UsersRepository usersRepository,
            Clock clock,
            EventCoversService coversService
    ) {
        return new CreateEventUseCase(repository, invitationsRepository, usersRepository, clock, coversService);
    }

    @Bean
    ListEventsUseCase listEventsUseCase(EventsRepository repository, InvitationsRepository invitationsRepository, Clock clock) {
        return new ListEventsUseCase(repository, invitationsRepository, clock);
    }

    @Bean
    GetEventUseCase getEventUseCase(EventsRepository repository, InvitationsRepository invitationsRepository) {
        return new GetEventUseCase(repository, invitationsRepository);
    }

    @Bean
    InviteEventGuestsUseCase inviteEventGuestsUseCase(
            EventsRepository eventsRepository,
            InvitationsRepository invitationsRepository,
            UsersRepository usersRepository,
            Clock clock
    ) {
        return new InviteEventGuestsUseCase(eventsRepository, invitationsRepository, usersRepository, clock);
    }

    @Bean
    ListEventGuestsUseCase listEventGuestsUseCase(InvitationsRepository invitationsRepository, UsersRepository usersRepository) {
        return new ListEventGuestsUseCase(invitationsRepository, usersRepository);
    }

    @Bean
    EnsureUserUseCase ensureUserUseCase(UsersRepository repository, Clock clock) {
        return new EnsureUserUseCase(repository, clock);
    }

    @Bean
    InvitationsService invitationsService(InvitationsRepository invitationsRepository, Clock clock) {
        return new InvitationsService(invitationsRepository, clock);
    }
}
