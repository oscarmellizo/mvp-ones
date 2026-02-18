package com.ones.api.application.users.ports;

import java.util.Optional;

import com.ones.api.domain.users.User;

public interface UsersRepository {

    Optional<User> findById(String userId);

    User upsert(User user);
}
