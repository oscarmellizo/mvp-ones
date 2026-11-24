package com.ones.api.application.events;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.lang.reflect.Method;

import org.junit.jupiter.api.Test;
import org.springframework.security.core.Authentication;

import com.ones.api.adapters.inbound.rest.tournament.TournamentController;

class TournamentControllerParameterNamesTest {

    @Test
    void retainsPathVariableNamesForSpringMvcBinding() throws Exception {
        Method get = TournamentController.class.getMethod("get", Authentication.class, String.class);

        assertTrue(get.getParameters()[1].isNamePresent());
        assertEquals("eventId", get.getParameters()[1].getName());
    }
}
