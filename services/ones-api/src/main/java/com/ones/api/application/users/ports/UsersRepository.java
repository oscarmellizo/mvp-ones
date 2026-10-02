package com.ones.api.application.users.ports;

import java.util.List;
import java.util.Optional;
import java.util.Set;

import com.ones.api.domain.users.User;

public interface UsersRepository {

    Optional<User> findById(String userId);

    Optional<User> findByEmail(String email);

    User upsert(User user);

    void deleteById(String userId);

    List<User> findByStatusIn(Set<String> statuses);
}
