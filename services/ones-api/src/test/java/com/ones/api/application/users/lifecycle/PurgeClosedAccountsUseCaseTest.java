package com.ones.api.application.users.lifecycle;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

import java.io.InputStream;
import java.nio.file.Path;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.ones.api.application.events.EventPurger;
import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.application.events.ports.ObjectStorage;
import com.ones.api.application.invitations.ports.InvitationsRepository;
import com.ones.api.application.photos.ports.PhotoLikesRepository;
import com.ones.api.application.photos.ports.PhotosRepository;
import com.ones.api.application.subscriptions.ports.PaymentProfilesRepository;
import com.ones.api.application.subscriptions.ports.SubscriptionPaymentsRepository;
import com.ones.api.application.users.AccountAccessService;
import com.ones.api.application.users.InMemoryUsersRepository;
import com.ones.api.application.users.ports.FirebaseIdentityAdmin;
import com.ones.api.application.users.ports.PreferredNamesCacheRepository;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.invitations.Invitation;
import com.ones.api.domain.photos.Photo;
import com.ones.api.domain.subscriptions.PaymentProfile;
import com.ones.api.domain.subscriptions.SubscriptionPayment;
import com.ones.api.domain.users.User;

class PurgeClosedAccountsUseCaseTest {

    private static final Instant NOW = Instant.parse("2026-10-02T08:00:00Z");

    private InMemoryUsersRepository repo;
    private FakeEvents events;
    private FakePhotos photos;
    private FakeInvitations invitations;
    private FakeProfiles profiles;
    private FakePayments payments;
    private FakeStorage storage;
    private EventPurger purger;
    private PhotoLikesRepository likes;
    private PreferredNamesCacheRepository names;
    private FirebaseIdentityAdmin firebase;
    private AccountAccessService access;
    private PurgeClosedAccountsUseCase useCase;

    @BeforeEach
    void setUp() {
        repo = new InMemoryUsersRepository();
        events = new FakeEvents();
        photos = new FakePhotos();
        invitations = new FakeInvitations();
        profiles = new FakeProfiles();
        payments = new FakePayments();
        storage = new FakeStorage();
        purger = mock(EventPurger.class);
        likes = mock(PhotoLikesRepository.class);
        names = mock(PreferredNamesCacheRepository.class);
        firebase = mock(FirebaseIdentityAdmin.class);
        access = mock(AccountAccessService.class);
        // El purger real borra el evento y la foto; el mock lo imita sobre los fakes.
        doAnswer(i -> { events.deleteById(((Event) i.getArgument(0)).getEventId()); return 0; }).when(purger).purge(any(Event.class));
        doAnswer(i -> { photos.deleteById(((Photo) i.getArgument(0)).getPhotoId()); return null; }).when(purger).purgePhoto(any(Photo.class));
        useCase = new PurgeClosedAccountsUseCase(repo, events, photos, likes, invitations, profiles, payments,
                names, storage, firebase, purger, access, Clock.fixed(NOW, ZoneOffset.UTC), "exports", d -> { });
    }

    private static User closed(String id, Instant closedAt) {
        return new User(id, "ana@example.com", "Ana", "Ana", "Pérez", null, null, "google", "es", true,
                NOW.minus(Duration.ofDays(400)), NOW.minus(Duration.ofDays(400)), "DISABLED",
                NOW.minus(Duration.ofDays(40)), null)
                .withLifecycle(User.STATUS_CLOSED, closedAt, "tok", "exports/" + id + "/ones-fotos.zip");
    }

    private static Event event(String id, String owner) {
        return new Event(id, owner, NOW, "T", "O", "L", NOW, NOW, null, false, false, List.of());
    }

    private static Photo photo(String id, String eventId, String guest) {
        return new Photo(id, eventId, guest, NOW, NOW, "READY", "k/" + id + ".jpg", null, null);
    }

    private static Invitation invitation(String email, String eventId) {
        return new Invitation(eventId, email, null, "owner", Invitation.Status.invited, NOW, NOW, "T", "L", NOW, NOW);
    }

    private static SubscriptionPayment payment(String id, String userId, String email) {
        return new SubscriptionPayment(id, NOW, null, "approved", null, 1000L, "COP", email, "payer-1", null, null,
                userId, "plan", null);
    }

    @Test
    void day7AfterClosure_isNotPurged() {
        repo.upsert(closed("u1", NOW.minus(Duration.ofDays(7))));
        assertEquals(0, useCase.execute());
        verifyNoInteractions(firebase);
    }

    @Test
    void day8_purgesEverything_andLeavesTombstone() {
        repo.upsert(closed("u1", NOW.minus(Duration.ofDays(8)).minusSeconds(1)));
        events.save(event("e1", "u1"));
        photos.upsert(photo("p9", "e9", "u1"));
        invitations.upsert(invitation("ana@example.com", "e9"));
        profiles.upsert(new PaymentProfile("u1", "ana@mp.com", "CO", "CC", "123", "3001234567", "Ana Pérez", NOW, NOW, NOW));
        payments.upsert(payment("pay1", "u1", "ana@mp.com"));

        assertEquals(1, useCase.execute());

        verify(purger).purge(argThat(e -> e.getEventId().equals("e1")));
        verify(purger).purgePhoto(argThat(p -> p.getPhotoId().equals("p9")));
        verify(likes).deleteAllByUserId("u1");
        assertTrue(invitations.listByInviteeEmail("ana@example.com", 10).isEmpty());
        assertTrue(storage.deleted.contains("exports/exports/u1/ones-fotos.zip"));
        PaymentProfile p = profiles.findByUserId("u1").get();
        assertNull(p.getMercadoPagoEmail());
        assertNull(p.getDocumentNumber());
        assertNull(p.getPhoneNumber());
        assertNull(p.getFullName());
        assertEquals("CO", p.getCountry());
        SubscriptionPayment sp = payments.findByPaymentId("pay1").get();
        assertNull(sp.getPayerEmail());
        assertEquals("payer-1", sp.getPayerId());
        assertEquals(1000L, sp.getTransactionAmountCents());
        verify(names).delete("u1");
        verify(firebase).deleteUser("u1");
        verify(access).evict("u1");
        User t = repo.findById("u1").get();
        assertEquals("DELETED", t.getStatus());
        assertNull(t.getEmail());
    }

    @Test
    void firebaseFails_staysClosed_andNextRunFinishes() {
        repo.upsert(closed("u1", NOW.minus(Duration.ofDays(9))));
        doThrow(new IllegalStateException("no configurado")).doNothing().when(firebase).deleteUser("u1");

        assertEquals(0, useCase.execute());
        assertEquals("CLOSED", repo.findById("u1").get().getStatus());

        assertEquals(1, useCase.execute());
        assertEquals("DELETED", repo.findById("u1").get().getStatus());
    }

    @Test
    void purgerFails_firebaseNotCalled_staysClosed() {
        repo.upsert(closed("u1", NOW.minus(Duration.ofDays(9))));
        events.save(event("e1", "u1"));
        doThrow(new IllegalStateException("s3")).when(purger).purge(any(Event.class));

        assertEquals(0, useCase.execute());
        assertEquals("CLOSED", repo.findById("u1").get().getStatus());
        verify(firebase, never()).deleteUser(any());
    }

    @Test
    void alreadyDeleted_isIgnored() {
        repo.upsert(closed("u1", NOW.minus(Duration.ofDays(20))).tombstone(NOW));
        assertEquals(0, useCase.execute());
    }

    @Test
    void ownedEventsBeyondOnePage_areAllPurged() {
        repo.upsert(closed("u1", NOW.minus(Duration.ofDays(9))));
        for (int i = 0; i < 250; i++) events.save(event("e" + i, "u1"));

        assertEquals(1, useCase.execute());

        verify(purger, times(250)).purge(any(Event.class));
        assertTrue(events.listByOwnerId("u1", 1000).isEmpty());
        assertEquals("DELETED", repo.findById("u1").get().getStatus());
    }

    @Test
    void purgeThatRemovesNothing_failsInsteadOfLooping() {
        repo.upsert(closed("u1", NOW.minus(Duration.ofDays(9))));
        for (int i = 0; i < 200; i++) events.save(event("e" + i, "u1")); // página completa
        doAnswer(i -> 0).when(purger).purge(any(Event.class)); // no borra el evento

        assertEquals(0, useCase.execute());
        assertEquals("CLOSED", repo.findById("u1").get().getStatus());
        verify(firebase, never()).deleteUser(any());
    }

    @Test
    void inviteesBeyondOnePage_areAllDeleted() {
        repo.upsert(closed("u1", NOW.minus(Duration.ofDays(9))));
        for (int i = 0; i < 1200; i++) invitations.upsert(invitation("ana@example.com", "ev" + i));

        assertEquals(1, useCase.execute());
        assertTrue(invitations.listByInviteeEmail("ana@example.com", 10).isEmpty());
    }

    @Test
    void staleEventListing_afterPurge_stillSucceeds_andPurgesEachOnce() {
        repo.upsert(closed("u1", NOW.minus(Duration.ofDays(9))));
        events.stale = true;
        for (int i = 0; i < 3; i++) events.save(event("e" + i, "u1"));

        assertEquals(1, useCase.execute());

        verify(purger, times(3)).purge(any(Event.class));
        assertEquals("DELETED", repo.findById("u1").get().getStatus());
    }

    @Test
    void fullStalePageOfEvents_neverClearing_failsAndStaysClosed() {
        repo.upsert(closed("u1", NOW.minus(Duration.ofDays(9))));
        events.stale = true;
        for (int i = 0; i < 200; i++) events.save(event("e" + i, "u1"));

        assertEquals(0, useCase.execute());

        assertEquals("CLOSED", repo.findById("u1").get().getStatus());
        verify(firebase, never()).deleteUser(any());
    }

    @Test
    void staleInvitationListing_afterDelete_stillSucceeds() {
        repo.upsert(closed("u1", NOW.minus(Duration.ofDays(9))));
        invitations.stale = true;
        for (int i = 0; i < 3; i++) invitations.upsert(invitation("ana@example.com", "ev" + i));

        assertEquals(1, useCase.execute());
        assertEquals("DELETED", repo.findById("u1").get().getStatus());
    }

    @Test
    void fullStalePageOfInvitations_neverClearing_failsAndStaysClosed() {
        repo.upsert(closed("u1", NOW.minus(Duration.ofDays(9))));
        invitations.stale = true;
        for (int i = 0; i < 500; i++) invitations.upsert(invitation("ana@example.com", "ev" + i));

        assertEquals(0, useCase.execute());

        assertEquals("CLOSED", repo.findById("u1").get().getStatus());
        verify(firebase, never()).deleteUser(any());
    }

    @Test
    void accountWithoutExportZip_purgesWithoutTouchingExportsBucket() {
        repo.upsert(closed("u1", NOW.minus(Duration.ofDays(9))).withLifecycle(User.STATUS_CLOSED,
                NOW.minus(Duration.ofDays(9)), "tok", null));

        assertEquals(1, useCase.execute());

        assertTrue(storage.deleted.isEmpty());
        assertEquals("DELETED", repo.findById("u1").get().getStatus());
    }

    // ---- fakes ----

    static class FakeEvents implements EventsRepository {
        final Map<String, Event> store = new LinkedHashMap<>();
        boolean stale; // simula el GSI: sigue devolviendo filas ya borradas
        final List<Event> ghosts = new ArrayList<>();
        public Event save(Event e) { store.put(e.getEventId(), e); return e; }
        public Optional<Event> findById(String id) { return Optional.ofNullable(store.get(id)); }
        public List<Event> findByIds(List<String> ids) { return ids.stream().map(store::get).filter(x -> x != null).toList(); }
        public List<Event> listByOwnerId(String owner, int limit) {
            List<Event> all = new ArrayList<>(store.values());
            all.addAll(ghosts);
            return all.stream().filter(e -> e.getOwnerId().equals(owner)).limit(Math.min(limit, 200)).toList();
        }
        public long countByOwnerId(String owner) { return listByOwnerId(owner, 1000).size(); }
        public void deleteById(String id) {
            Event e = store.remove(id);
            if (stale && e != null) ghosts.add(e);
        }
    }

    static class FakePhotos implements PhotosRepository {
        final Map<String, Photo> store = new LinkedHashMap<>();
        public Optional<Photo> findById(String id) { return Optional.ofNullable(store.get(id)); }
        public Photo upsert(Photo p) { store.put(p.getPhotoId(), p); return p; }
        public PageResult<Photo> listByEventId(String eventId, int limit, String next) {
            return new PageResult<>(store.values().stream().filter(p -> p.getEventId().equals(eventId)).toList(), null);
        }
        public PageResult<Photo> listByGuestId(String guestId, int limit, String next) {
            return new PageResult<>(store.values().stream().filter(p -> p.getGuestId().equals(guestId)).toList(), null);
        }
        public PageResult<Photo> listAll(int limit, String next) { return new PageResult<>(new ArrayList<>(store.values()), null); }
        public long countByEventId(String eventId) { return listByEventId(eventId, 0, null).items().size(); }
        public void deleteById(String id) { store.remove(id); }
    }

    static class FakeInvitations implements InvitationsRepository {
        final Map<String, Invitation> store = new LinkedHashMap<>();
        boolean stale; // simula el GSI: sigue devolviendo filas ya borradas
        final List<Invitation> ghosts = new ArrayList<>();
        private static String k(String email, String eventId) { return email + "|" + eventId; }
        public Optional<Invitation> findByInviteeEmailAndEventId(String e, String ev) { return Optional.ofNullable(store.get(k(e, ev))); }
        public Invitation upsert(Invitation i) { store.put(k(i.getInviteeEmail(), i.getEventId()), i); return i; }
        public List<Invitation> listByInviteeEmail(String email, int limit) {
            List<Invitation> all = new ArrayList<>(store.values());
            all.addAll(ghosts);
            return all.stream().filter(i -> i.getInviteeEmail().equals(email)).limit(limit).toList();
        }
        public List<Invitation> listByEventId(String ev, int limit) {
            return store.values().stream().filter(i -> i.getEventId().equals(ev)).limit(limit).toList();
        }
        public List<Invitation> listAcceptedByInviteeEmail(String email, int limit) { return List.of(); }
        public void delete(String email, String ev) {
            Invitation i = store.remove(k(email, ev));
            if (stale && i != null) ghosts.add(i);
        }
        public void deleteAllByEventId(String ev) { store.values().removeIf(i -> i.getEventId().equals(ev)); }
    }

    static class FakeProfiles implements PaymentProfilesRepository {
        final Map<String, PaymentProfile> store = new LinkedHashMap<>();
        public Optional<PaymentProfile> findByUserId(String id) { return Optional.ofNullable(store.get(id)); }
        public PaymentProfile upsert(PaymentProfile p) { store.put(p.getUserId(), p); return p; }
    }

    static class FakePayments implements SubscriptionPaymentsRepository {
        final Map<String, SubscriptionPayment> store = new LinkedHashMap<>();
        public Optional<SubscriptionPayment> findByPaymentId(String id) { return Optional.ofNullable(store.get(id)); }
        public SubscriptionPayment upsert(SubscriptionPayment p) { store.put(p.getPaymentId(), p); return p; }
        public List<SubscriptionPayment> listByUserId(String id) {
            return store.values().stream().filter(p -> id.equals(p.getUserId())).toList();
        }
    }

    static class FakeStorage implements ObjectStorage {
        final List<String> deleted = new ArrayList<>();
        public void putPng(String b, String k, byte[] png) { }
        public void copy(String sb, String sk, String db, String dk) { }
        public InputStream open(String b, String k) { throw new UnsupportedOperationException(); }
        public void putFile(String b, String k, Path f, String ct) { }
        public void delete(String bucket, String key) { deleted.add(bucket + "/" + key); }
    }
}
