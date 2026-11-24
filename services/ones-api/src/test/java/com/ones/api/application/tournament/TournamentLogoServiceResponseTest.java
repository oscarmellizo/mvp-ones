package com.ones.api.application.tournament;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

import com.fasterxml.jackson.databind.ObjectMapper;

class TournamentLogoServiceResponseTest {

    @Test
    void readsStableImageCoreImageArray() throws Exception {
        var payload = new ObjectMapper().readTree("""
                {"images":["encoded-image"],"seeds":[123],"finish_reasons":[null]}
                """);

        assertEquals("encoded-image", TournamentLogoService.extractImage(payload));
    }
}
