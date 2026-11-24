package com.ones.api.application.events;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.lang.reflect.Method;

import org.junit.jupiter.api.Test;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PathVariable;

import com.ones.api.adapters.inbound.rest.complements.EventComplementsController;

class EventComplementsControllerPathBindingTest {

    @Test
    void declaresPathVariableNamesWithoutRequiringReflectionMetadata() throws Exception {
        Method list = EventComplementsController.class.getMethod(
                "list", Authentication.class, String.class);
        assertEquals("eventId", list.getParameters()[1].getAnnotation(PathVariable.class).value());

        Method setEnabled = EventComplementsController.class.getMethod(
                "setEnabled",
                Authentication.class,
                String.class,
                String.class,
                EventComplementsController.SetComplementRequest.class);
        assertEquals("eventId", setEnabled.getParameters()[1].getAnnotation(PathVariable.class).value());
        assertEquals("complementId", setEnabled.getParameters()[2].getAnnotation(PathVariable.class).value());
    }
}
