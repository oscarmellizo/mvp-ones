package com.ones.api.application.users.ports;

import java.util.Optional;

import com.ones.api.domain.users.User;

public interface UsersRepository {

    Optional<User> findById(String userId);

    Optional<User> findByEmail(String email);

    User upsert(User user);

    void deleteById(String userId);
}
