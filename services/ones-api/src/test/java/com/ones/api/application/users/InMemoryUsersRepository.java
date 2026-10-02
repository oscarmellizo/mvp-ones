package com.ones.api.application.users;

import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;

import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

/** Fake en memoria compartido por los tests; las escrituras condicionales se comportan como en DynamoDB. */
public class InMemoryUsersRepository implements UsersRepository {

    private final Map<String, User> store = new HashMap<>();
    private int writes;

    @Override
    public Optional<User> findById(String userId) {
        return Optional.ofNullable(store.get(userId));
    }

    @Override
    public Optional<User> findByEmail(String email) {
        return store.values().stream().filter(u -> email != null && email.equals(u.getEmail())).findFirst();
    }

    @Override
    public User upsert(User user) {
        store.put(user.getUserId(), user);
        writes++;
        return user;
    }

    @Override
    public boolean upsertIfStatus(User user, String expectedStatus) {
        User current = store.get(user.getUserId());
        if (current == null || !Objects.equals(current.getStatus(), expectedStatus)) return false;
        upsert(user);
        return true;
    }

    @Override
    public boolean upsertIfClosing(User user, Instant expectedClosingAt) {
        User current = store.get(user.getUserId());
        if (current == null || !User.STATUS_CLOSING.equals(current.getStatus())
                || !Objects.equals(current.getClosingAt(), expectedClosingAt)) return false;
        upsert(user);
        return true;
    }

    @Override
    public void deleteById(String userId) {
        store.remove(userId);
        writes++;
    }

    @Override
    public List<User> findByStatusIn(Set<String> statuses) {
        return store.values().stream()
                .filter(u -> u.getStatus() != null && statuses.contains(u.getStatus().toUpperCase()))
                .toList();
    }

    /** Cantidad de escrituras (upsert/delete) hechas sobre el fake. */
    public int writes() {
        return writes;
    }
}
