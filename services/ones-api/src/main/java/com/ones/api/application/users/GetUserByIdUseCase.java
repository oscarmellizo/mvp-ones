package com.ones.api.application.users;

import java.util.Optional;

import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

public class GetUserByIdUseCase {

    private final UsersRepository usersRepository;

    public GetUserByIdUseCase(UsersRepository usersRepository) {
        this.usersRepository = usersRepository;
    }

    public Optional<User> execute(String userId) {
        return usersRepository.findById(userId);
    }
}
