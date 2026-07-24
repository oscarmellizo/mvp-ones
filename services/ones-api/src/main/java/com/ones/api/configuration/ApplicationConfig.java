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
import com.ones.api.application.subscriptions.CheckPlanLimitUseCase;
import com.ones.api.application.subscriptions.CreateMercadoPagoSubscriptionUseCase;
import com.ones.api.application.subscriptions.GetOrCreateUserSubscriptionUseCase;
import com.ones.api.application.subscriptions.GetSubscriptionPlansUseCase;
import com.ones.api.application.subscriptions.ProcessMercadoPagoWebhookUseCase;
import com.ones.api.application.subscriptions.ports.MercadoPagoGateway;
import com.ones.api.application.subscriptions.ports.PaymentProfilesRepository;
import com.ones.api.application.subscriptions.ports.CheckoutAttemptsRepository;
import com.ones.api.application.subscriptions.ports.SubscriptionPaymentsRepository;
import com.ones.api.application.subscriptions.ports.SubscriptionPlansRepository;
import com.ones.api.application.subscriptions.ports.UserSubscriptionsRepository;

import org.springframework.beans.factory.annotation.Value;

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
            InvitationEmailService invitationEmailService,
            CheckPlanLimitUseCase checkPlanLimitUseCase
    ) {
        return new CreateEventUseCase(repository, invitationsRepository, usersRepository, clock, coversService, invitationEmailService, checkPlanLimitUseCase);
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

    @Bean
    GetSubscriptionPlansUseCase getSubscriptionPlansUseCase(SubscriptionPlansRepository plansRepository) {
        return new GetSubscriptionPlansUseCase(plansRepository);
    }

    @Bean
    GetOrCreateUserSubscriptionUseCase getOrCreateUserSubscriptionUseCase(
            UserSubscriptionsRepository subscriptionsRepository,
            Clock clock
    ) {
        return new GetOrCreateUserSubscriptionUseCase(subscriptionsRepository, clock);
    }

    @Bean
    CheckPlanLimitUseCase checkPlanLimitUseCase(
            UserSubscriptionsRepository subscriptionsRepository,
            SubscriptionPlansRepository plansRepository
    ) {
        return new CheckPlanLimitUseCase(subscriptionsRepository, plansRepository);
    }

    @Bean
    CreateMercadoPagoSubscriptionUseCase createMercadoPagoSubscriptionUseCase(
            UserSubscriptionsRepository subscriptionsRepository,
            SubscriptionPlansRepository plansRepository,
            UsersRepository usersRepository,
            PaymentProfilesRepository paymentProfilesRepository,
            CheckoutAttemptsRepository checkoutAttemptsRepository,
            MercadoPagoGateway mercadoPagoGateway,
            Clock clock,
            @Value("${ones.mercadopago.app-base-url:}") String appBaseUrl,
            @Value("${ones.mercadopago.test-payer-email:}") String testPayerEmail
    ) {
        return new CreateMercadoPagoSubscriptionUseCase(
                subscriptionsRepository, plansRepository, usersRepository,
                paymentProfilesRepository, checkoutAttemptsRepository,
                mercadoPagoGateway, clock, appBaseUrl, testPayerEmail
        );
    }

    @Bean
    ProcessMercadoPagoWebhookUseCase processMercadoPagoWebhookUseCase(
            UserSubscriptionsRepository subscriptionsRepository,
            MercadoPagoGateway mercadoPagoGateway,
            UsersRepository usersRepository,
            CheckoutAttemptsRepository checkoutAttemptsRepository,
            SubscriptionPaymentsRepository subscriptionPaymentsRepository,
            Clock clock,
            @Value("${ones.mercadopago.test-payer-email:}") String testPayerEmail
    ) {
        return new ProcessMercadoPagoWebhookUseCase(
                subscriptionsRepository, mercadoPagoGateway, usersRepository,
                checkoutAttemptsRepository, subscriptionPaymentsRepository,
                clock, testPayerEmail
        );
    }
}
