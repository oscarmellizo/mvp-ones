package com.ones.api.application.users;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

/** Fake en memoria compartido por los tests del paquete. */
public class InMemoryUsersRepository implements UsersRepository {

    private final Map<String, User> store = new HashMap<>();

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
        return user;
    }

    @Override
    public void deleteById(String userId) {
        store.remove(userId);
    }

    @Override
    public List<User> findByStatusIn(Set<String> statuses) {
        return store.values().stream()
                .filter(u -> u.getStatus() != null && statuses.contains(u.getStatus().toUpperCase()))
                .toList();
    }
}
