package com.ones.api.application.users;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;

import org.junit.jupiter.api.Test;

import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

class UpdateUserTimeZoneUseCaseTest {
    @Test
    void storesOnlyValidIanaZoneAndPreservesExistingProfile() {
        UsersRepository repository = mock(UsersRepository.class);
        Instant now = Instant.parse("2026-02-01T12:00:00Z");
        User existing = new User(
                "u-1", "user@example.com", "User", "User", null, null, "Ana", "google",
                "es", true, now.minusSeconds(3600), now, User.STATUS_ACTIVE,
                null, null, null, null, null, null, null
        );
        when(repository.findById("u-1")).thenReturn(Optional.of(existing));
        when(repository.upsertIfStatus(any(User.class), any())).thenReturn(true);

        UpdateUserTimeZoneUseCase useCase = new UpdateUserTimeZoneUseCase(
                repository, Clock.fixed(now, ZoneOffset.UTC)
        );
        User updated = useCase.execute("u-1", "America/Mexico_City").orElseThrow();

        assertEquals("America/Mexico_City", updated.getTimeZone());
        assertEquals("Ana", updated.getPreferredName());
        assertEquals("es", updated.getLanguagePreference());
        verify(repository).upsertIfStatus(any(User.class), any());
    }

    @Test
    void rejectsNonIanaZoneBeforeWriting() {
        UsersRepository repository = mock(UsersRepository.class);
        UpdateUserTimeZoneUseCase useCase = new UpdateUserTimeZoneUseCase(
                repository, Clock.systemUTC()
        );

        assertThrows(IllegalArgumentException.class, () -> useCase.execute("u-1", "PST"));
        verify(repository, never()).upsertIfStatus(any(User.class), any());
    }
}
