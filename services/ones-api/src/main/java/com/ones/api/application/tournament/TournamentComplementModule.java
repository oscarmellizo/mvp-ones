package com.ones.api.application.tournament;

import org.springframework.stereotype.Component;

import com.ones.api.application.complements.EventComplementModule;

@Component
public class TournamentComplementModule implements EventComplementModule {

    private static final String ID = "tournament";
    private static final String DISPLAY_NAME = "Torneo 4 Equipos";
    private static final String DEFAULT_TAB_LABEL = "Torneo";

    private final TournamentService tournamentService;

    public TournamentComplementModule(TournamentService tournamentService) {
        this.tournamentService = tournamentService;
    }

    @Override
    public String id() {
        return ID;
    }

    @Override
    public String displayName() {
        return DISPLAY_NAME;
    }

    @Override
    public String defaultTabLabel() {
        return DEFAULT_TAB_LABEL;
    }

    @Override
    public void initialize(String eventId, String ownerId) {
        tournamentService.initialize(eventId, ownerId, DEFAULT_TAB_LABEL);
    }
}
