package com.ones.api.application;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

import com.ones.api.application.complements.EventComplementModule;
import com.ones.api.application.tournament.TournamentComplementModule;
import com.ones.api.application.tournament.TournamentService;

class EventComplementModuleRegistrationTest {

    @Test
    void tournamentServiceIsRegisteredThroughItsComplementAdapterOnly() {
        assertFalse(EventComplementModule.class.isAssignableFrom(TournamentService.class));
        assertTrue(EventComplementModule.class.isAssignableFrom(TournamentComplementModule.class));
    }
}
