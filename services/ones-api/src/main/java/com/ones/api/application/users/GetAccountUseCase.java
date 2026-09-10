package com.ones.api.application.users;

import java.util.Optional;

import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

public class GetAccountUseCase {

    private final UsersRepository usersRepository;

    public GetAccountUseCase(UsersRepository usersRepository) {
        this.usersRepository = usersRepository;
    }

    public Optional<User> execute(String userId) {
        if (userId == null || userId.isBlank()) return Optional.empty();
        return usersRepository.findById(userId);
    }
}
