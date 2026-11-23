package com.ones.api.application.tournament;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

@ResponseStatus(HttpStatus.CONFLICT)
public class TournamentConflictException extends RuntimeException {

    public TournamentConflictException(String message) {
        super(message);
    }
}
