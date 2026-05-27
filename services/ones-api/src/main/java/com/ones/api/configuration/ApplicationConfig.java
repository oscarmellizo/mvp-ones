package com.ones.api.configuration;

import java.time.Clock;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.ones.api.application.invitations.InvitationsService;
import com.ones.api.application.invitations.ports.InvitationsRepository;
import com.ones.api.application.invitations.email.InvitationActionTokenService;
import com.ones.api.application.invitations.email.InvitationEmailService;
import com.ones.api.application.events.CreateEventUseCase;
import com.ones.api.application.events.EventCoversService;
import com.ones.api.application.events.GetEventUseCase;
import com.ones.api.application.events.InviteEventGuestsUseCase;
import com.ones.api.application.events.ListEventGuestsUseCase;
import com.ones.api.application.events.ListEventsUseCase;
import com.ones.api.application.events.UpdateEventUseCase;
import com.ones.api.application.events.invitelink.AcceptEventInviteLinkUseCase;
import com.ones.api.application.events.invitelink.PreviewEventInviteLinkUseCase;
import com.ones.api.application.events.invitelink.SetEventInviteLinkEnabledUseCase;
import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.application.users.EnsureUserUseCase;
import com.ones.api.application.users.GetUserByIdUseCase;
import com.ones.api.application.users.LookupUserByEmailUseCase;
import com.ones.api.application.users.UpdateUserPreferencesUseCase;
import com.ones.api.application.users.ports.PreferredNamesCacheRepository;
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
            EventCoversService coversService,
            InvitationEmailService invitationEmailService
    ) {
        return new CreateEventUseCase(repository, invitationsRepository, usersRepository, clock, coversService, invitationEmailService);
    }

    @Bean
    UpdateEventUseCase updateEventUseCase(
            EventsRepository repository,
            EventCoversService coversService
    ) {
        return new UpdateEventUseCase(repository, coversService);
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
    PreviewEventInviteLinkUseCase previewEventInviteLinkUseCase(EventsRepository repository, Clock clock) {
        return new PreviewEventInviteLinkUseCase(repository, clock);
    }

    @Bean
    AcceptEventInviteLinkUseCase acceptEventInviteLinkUseCase(InvitationsRepository invitationsRepository, Clock clock) {
        return new AcceptEventInviteLinkUseCase(invitationsRepository, clock);
    }

    @Bean
    SetEventInviteLinkEnabledUseCase setEventInviteLinkEnabledUseCase(EventsRepository repository) {
        return new SetEventInviteLinkEnabledUseCase(repository);
    }

    @Bean
    InviteEventGuestsUseCase inviteEventGuestsUseCase(
            EventsRepository eventsRepository,
            InvitationsRepository invitationsRepository,
            UsersRepository usersRepository,
            Clock clock,
            InvitationEmailService invitationEmailService
    ) {
        return new InviteEventGuestsUseCase(eventsRepository, invitationsRepository, usersRepository, clock, invitationEmailService);
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
    GetUserByIdUseCase getUserByIdUseCase(UsersRepository repository) {
        return new GetUserByIdUseCase(repository);
    }

    @Bean
    LookupUserByEmailUseCase lookupUserByEmailUseCase(UsersRepository repository) {
        return new LookupUserByEmailUseCase(repository);
    }

    @Bean
    UpdateUserPreferencesUseCase updateUserPreferencesUseCase(
            UsersRepository repository,
            PreferredNamesCacheRepository preferredNamesCacheRepository,
            Clock clock
    ) {
        return new UpdateUserPreferencesUseCase(repository, preferredNamesCacheRepository, clock);
    }

    @Bean
    InvitationsService invitationsService(
            InvitationsRepository invitationsRepository,
            Clock clock,
            InvitationActionTokenService tokenService
    ) {
        return new InvitationsService(invitationsRepository, clock, tokenService);
    }
}
