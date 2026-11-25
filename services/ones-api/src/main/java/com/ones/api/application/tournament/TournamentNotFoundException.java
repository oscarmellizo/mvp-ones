package com.ones.api.application.tournament;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

@ResponseStatus(HttpStatus.NOT_FOUND)
public class TournamentNotFoundException extends RuntimeException {

    public TournamentNotFoundException(String eventId) {
        super("Tournament is not enabled for event " + eventId);
    }
}
