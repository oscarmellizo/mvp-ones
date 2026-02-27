package com.ones.api.application.users;

import java.util.Optional;

import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

public class LookupUserByEmailUseCase {

    private final UsersRepository usersRepository;

    public LookupUserByEmailUseCase(UsersRepository usersRepository) {
        this.usersRepository = usersRepository;
    }

    public Optional<User> execute(String email) {
        if (email == null || email.trim().isEmpty()) {
            return Optional.empty();
        }
        return usersRepository.findByEmail(email.trim().toLowerCase());
    }
}
