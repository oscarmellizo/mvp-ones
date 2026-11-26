package com.ones.api.application.events;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.lang.reflect.Method;

import org.junit.jupiter.api.Test;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PathVariable;

import com.ones.api.adapters.inbound.rest.tournament.TournamentController;

class TournamentControllerParameterNamesTest {

    @Test
    void retainsPathVariableNamesForSpringMvcBinding() throws Exception {
        Method get = TournamentController.class.getMethod("get", Authentication.class, String.class);

        PathVariable pathVariable = get.getParameters()[1].getAnnotation(PathVariable.class);
        assertEquals("eventId", pathVariable.value());
    }
}
