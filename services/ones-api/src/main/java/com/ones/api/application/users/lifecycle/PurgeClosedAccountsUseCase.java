package com.ones.api.application.users.lifecycle;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.function.Consumer;
import java.util.function.Function;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.ones.api.application.events.EventPurger;
import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.application.events.ports.ObjectStorage;
import com.ones.api.application.invitations.ports.InvitationsRepository;
import com.ones.api.application.photos.ports.PhotoLikesRepository;
import com.ones.api.application.photos.ports.PhotosRepository;
import com.ones.api.application.subscriptions.ports.PaymentProfilesRepository;
import com.ones.api.application.subscriptions.ports.SubscriptionPaymentsRepository;
import com.ones.api.application.users.AccountAccessService;
import com.ones.api.application.users.ports.FirebaseIdentityAdmin;
import com.ones.api.application.users.ports.PreferredNamesCacheRepository;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.invitations.Invitation;
import com.ones.api.domain.photos.Photo;
import com.ones.api.domain.subscriptions.PaymentProfile;
import com.ones.api.domain.subscriptions.SubscriptionPayment;
import com.ones.api.domain.users.User;

/**
 * Borra definitivamente todo lo que posee una cuenta CLOSED pasada la gracia y deja una lápida.
 * Cada paso propaga sus fallos: la cuenta sigue CLOSED y la próxima corrida reintenta desde el principio.
 */
public class PurgeClosedAccountsUseCase {

    private static final Logger log = LoggerFactory.getLogger(PurgeClosedAccountsUseCase.class);

    /** Tiempo desde el cierre antes del borrado (igual a la vigencia del enlace de descarga). */
    public static final Duration GRACE = Duration.ofDays(8);

    private static final int EVENTS_PAGE = 200;
    private static final int PHOTOS_PAGE = 50;
    private static final int INVITATIONS_PAGE = 500;
    private static final int STALE_RETRIES = 3;
    private static final Duration STALE_BACKOFF = Duration.ofMillis(500);

    private final UsersRepository usersRepository;
    private final EventsRepository eventsRepository;
    private final PhotosRepository photosRepository;
    private final PhotoLikesRepository photoLikesRepository;
    private final InvitationsRepository invitationsRepository;
    private final PaymentProfilesRepository paymentProfilesRepository;
    private final SubscriptionPaymentsRepository subscriptionPaymentsRepository;
    private final PreferredNamesCacheRepository preferredNamesCacheRepository;
    private final ObjectStorage objectStorage;
    private final FirebaseIdentityAdmin firebaseIdentityAdmin;
    private final EventPurger eventPurger;
    private final AccountAccessService accountAccessService;
    private final Clock clock;
    private final String exportsBucket;
    private final Sleeper sleeper;

    public PurgeClosedAccountsUseCase(UsersRepository usersRepository, EventsRepository eventsRepository,
                                      PhotosRepository photosRepository, PhotoLikesRepository photoLikesRepository,
                                      InvitationsRepository invitationsRepository,
                                      PaymentProfilesRepository paymentProfilesRepository,
                                      SubscriptionPaymentsRepository subscriptionPaymentsRepository,
                                      PreferredNamesCacheRepository preferredNamesCacheRepository,
                                      ObjectStorage objectStorage, FirebaseIdentityAdmin firebaseIdentityAdmin,
                                      EventPurger eventPurger, AccountAccessService accountAccessService,
                                      Clock clock, String exportsBucket) {
        this(usersRepository, eventsRepository, photosRepository, photoLikesRepository, invitationsRepository,
                paymentProfilesRepository, subscriptionPaymentsRepository, preferredNamesCacheRepository,
                objectStorage, firebaseIdentityAdmin, eventPurger, accountAccessService, clock, exportsBucket,
                PurgeClosedAccountsUseCase::sleep);
    }

    /** Pausa entre reintentos de listados obsoletos; inyectable para que los tests no esperen. */
    @FunctionalInterface
    interface Sleeper {
        void sleep(Duration d) throws InterruptedException;
    }

    PurgeClosedAccountsUseCase(UsersRepository usersRepository, EventsRepository eventsRepository,
                               PhotosRepository photosRepository, PhotoLikesRepository photoLikesRepository,
                               InvitationsRepository invitationsRepository,
                               PaymentProfilesRepository paymentProfilesRepository,
                               SubscriptionPaymentsRepository subscriptionPaymentsRepository,
                               PreferredNamesCacheRepository preferredNamesCacheRepository,
                               ObjectStorage objectStorage, FirebaseIdentityAdmin firebaseIdentityAdmin,
                               EventPurger eventPurger, AccountAccessService accountAccessService,
                               Clock clock, String exportsBucket, Sleeper sleeper) {
        this.sleeper = sleeper;
        this.usersRepository = usersRepository;
        this.eventsRepository = eventsRepository;
        this.photosRepository = photosRepository;
        this.photoLikesRepository = photoLikesRepository;
        this.invitationsRepository = invitationsRepository;
        this.paymentProfilesRepository = paymentProfilesRepository;
        this.subscriptionPaymentsRepository = subscriptionPaymentsRepository;
        this.preferredNamesCacheRepository = preferredNamesCacheRepository;
        this.objectStorage = objectStorage;
        this.firebaseIdentityAdmin = firebaseIdentityAdmin;
        this.eventPurger = eventPurger;
        this.accountAccessService = accountAccessService;
        this.clock = clock;
        this.exportsBucket = exportsBucket;
    }

    /** @return cantidad de cuentas borradas en esta corrida. */
    public int execute() {
        Instant now = Instant.now(clock);
        int purged = 0;
        for (User u : usersRepository.findByStatusIn(Set.of(User.STATUS_CLOSED))) {
            if (u.getClosedAt() == null || !now.isAfter(u.getClosedAt().plus(GRACE))) continue;
            try {
                purge(u);
                usersRepository.upsert(u.tombstone(now));
                accountAccessService.evict(u.getUserId());
                purged++;
            } catch (Exception e) {
                // Todo lo anterior es idempotente: la próxima corrida retoma desde el principio.
                log.warn("[PurgeClosedAccounts] userId={} err={}", u.getUserId(), e.toString());
            }
        }
        return purged;
    }

    private void purge(User u) {
        String userId = u.getUserId();

        // Eventos propios: listByOwnerId tiene tope, así que se repite hasta que no queden.
        drain("eventos de userId=" + userId, EVENTS_PAGE,
                () -> eventsRepository.listByOwnerId(userId, EVENTS_PAGE), Event::getEventId, eventPurger::purge);

        // Fotos subidas por la persona en eventos ajenos.
        String next = null;
        do {
            PhotosRepository.PageResult<Photo> page = photosRepository.listByGuestId(userId, PHOTOS_PAGE, next);
            page.items().forEach(eventPurger::purgePhoto);
            next = page.nextToken();
        } while (next != null && !next.isBlank());

        photoLikesRepository.deleteAllByUserId(userId);

        // Invitaciones recibidas.
        if (u.getEmail() != null) {
            String email = u.getEmail();
            drain("invitaciones de userId=" + userId, INVITATIONS_PAGE, () -> invitationsRepository.listByInviteeEmail(email, INVITATIONS_PAGE),
                    inv -> inv.getInviteeEmail() + "|" + inv.getEventId(),
                    inv -> invitationsRepository.delete(inv.getInviteeEmail(), inv.getEventId()));
        }

        if (u.getExportKey() != null) objectStorage.delete(exportsBucket, u.getExportKey());

        // Datos de pago personales; payerId (id interno de Mercado Pago) se conserva para contabilidad.
        paymentProfilesRepository.findByUserId(userId).ifPresent(p -> paymentProfilesRepository.upsert(
                new PaymentProfile(p.getUserId(), null, p.getCountry(), p.getDocumentType(), null, null, null,
                        p.getCreatedAt(), Instant.now(clock), p.getVerifiedAt())));
        for (SubscriptionPayment sp : subscriptionPaymentsRepository.listByUserId(userId)) {
            subscriptionPaymentsRepository.upsert(sp.withoutPayerEmail());
        }

        preferredNamesCacheRepository.delete(userId);
        firebaseIdentityAdmin.deleteUser(userId); // último: si falla, la cuenta sigue CLOSED y se reintenta
    }

    /**
     * Lista y borra por lotes hasta terminar. Los listados salen de un índice eventualmente consistente, así
     * que pueden seguir devolviendo filas ya borradas: solo se procesan ids nuevos. Sin ids nuevos, un listado
     * incompleto significa que terminamos; uno completo (== limit) de ids ya procesados se reintenta con pausa
     * y, si no se despeja, se aborta por falta de progreso.
     */
    private <T> void drain(String what, int limit, java.util.function.Supplier<List<T>> lister,
                           Function<T, String> idOf, Consumer<T> remover) {
        Set<String> processed = new HashSet<>();
        int retries = 0;
        while (true) {
            List<T> batch = lister.get();
            boolean progressed = false;
            for (T item : batch) {
                if (!processed.add(idOf.apply(item))) continue;
                remover.accept(item);
                progressed = true;
            }
            if (progressed) {
                retries = 0;
                continue;
            }
            if (batch.size() < limit) return;
            if (retries >= STALE_RETRIES) throw new IllegalStateException("Borrado sin progreso: " + what);
            retries++;
            try {
                sleeper.sleep(STALE_BACKOFF);
            } catch (InterruptedException ie) {
                Thread.currentThread().interrupt();
                throw new IllegalStateException("Interrumpido: " + what, ie);
            }
        }
    }

    private static void sleep(Duration d) throws InterruptedException {
        Thread.sleep(d.toMillis());
    }
}
