package com.ones.api.adapters.inbound.rest;

import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import com.ones.api.adapters.inbound.rest.events.EventsController;
import com.ones.api.application.events.CreateEventUseCase;
import com.ones.api.application.events.EventsMetadataService;
import com.ones.api.application.events.GetEventUseCase;
import com.ones.api.application.events.InviteEventGuestsUseCase;
import com.ones.api.application.events.ListEventsUseCase;
import com.ones.api.application.invitations.ports.InvitationsRepository;
import com.ones.api.application.users.ports.UsersRepository;

@WebMvcTest(controllers = EventsController.class)
@AutoConfigureMockMvc(addFilters = false)
@Import(ApiExceptionHandler.class)
class ApiExceptionHandlerValidationTest {

    @Autowired
    private MockMvc mvc;

    @MockBean
    private CreateEventUseCase createEventUseCase;

    @MockBean
    private ListEventsUseCase listEventsUseCase;

    @MockBean
    private GetEventUseCase getEventUseCase;

    @MockBean
    private EventsMetadataService eventsMetadataService;

    @MockBean
    private InvitationsRepository invitationsRepository;

    @MockBean
    private UsersRepository usersRepository;

    @MockBean
    private InviteEventGuestsUseCase inviteEventGuestsUseCase;

    @Test
    void createEvent_whenInvalidBody_returnsBadRequestWithDetails() throws Exception {
        // Missing required fields: title/objective/location/startAt/endAt
        mvc.perform(
                        post("/v1/events")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("{}")
                )
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("bad_request"))
                .andExpect(jsonPath("$.message").value("Validation failed"))
                .andExpect(jsonPath("$.details").isArray())
                .andExpect(jsonPath("$.details[0].field").exists())
                .andExpect(jsonPath("$.details[0].message").value(containsString("must")));
    }
}
