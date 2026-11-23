package com.ones.api.application.tournament;

import org.springframework.stereotype.Component;

import com.ones.api.application.complements.EventComplementModule;

@Component
public class TournamentComplementModule implements EventComplementModule {

    private final TournamentService tournamentService;

    public TournamentComplementModule(TournamentService tournamentService) {
        this.tournamentService = tournamentService;
    }

    @Override
    public String id() {
        return tournamentService.id();
    }

    @Override
    public String displayName() {
        return tournamentService.displayName();
    }

    @Override
    public String defaultTabLabel() {
        return tournamentService.defaultTabLabel();
    }

    @Override
    public void initialize(String eventId, String ownerId) {
        tournamentService.initialize(eventId, ownerId);
    }
}
