package com.ones.api.application.users;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.configuration.CacheConfig;
import com.ones.api.domain.users.User;

/**
 * Decide si una cuenta puede seguir usando el API según su estado de desactivación.
 * El resultado se cachea por userId; los endpoints que cambian el estado deben llamar a {@link #evict(String)}.
 */
@Service
public class AccountAccessService {

    private final UsersRepository usersRepository;
    private final Clock clock;
    private final Duration reactivationWindow;

    @Autowired
    public AccountAccessService(
            UsersRepository usersRepository,
            Clock clock,
            @Value("${ones.account.reactivate-window-days:30}") int windowDays
    ) {
        this(usersRepository, clock, Duration.ofDays(Math.max(1, windowDays)));
    }

    public AccountAccessService(UsersRepository usersRepository, Clock clock, Duration reactivationWindow) {
        this.usersRepository = usersRepository;
        this.clock = clock;
        this.reactivationWindow = reactivationWindow;
    }

    @Cacheable(cacheNames = CacheConfig.ACCOUNT_ACCESS_CACHE)
    public AccountAccess check(String userId) {
        Optional<User> user = usersRepository.findById(userId);
        if (user.isEmpty()) return AccountAccess.ACTIVE;
        User u = user.get();
        if (!"DISABLED".equalsIgnoreCase(u.getStatus())) return AccountAccess.ACTIVE;
        Instant disabledAt = u.getDisabledAt();
        if (disabledAt == null) return AccountAccess.DISABLED;
        Instant now = Instant.now(clock);
        return now.isAfter(disabledAt.plus(reactivationWindow)) ? AccountAccess.CLOSED : AccountAccess.DISABLED;
    }

    @CacheEvict(cacheNames = CacheConfig.ACCOUNT_ACCESS_CACHE)
    public void evict(String userId) {
        // La anotación se encarga de invalidar la entrada.
    }
}
