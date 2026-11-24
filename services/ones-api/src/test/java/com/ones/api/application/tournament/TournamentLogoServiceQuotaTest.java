package com.ones.api.application.tournament;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.LocalDate;
import java.util.Map;

import org.junit.jupiter.api.Test;

class TournamentLogoServiceQuotaTest {

    @Test
    void escapesReservedUsageAttributeInQuotaUpdate() {
        var request = TournamentLogoService.quotaUpdateRequest(
                "ones-dev-tournaments",
                "owner-1",
                LocalDate.of(2026, 11, 24),
                5);

        assertEquals("SET expiresAt = :expiry ADD #usage :one", request.updateExpression());
        assertEquals(
                "attribute_not_exists(#usage) OR #usage < :limit",
                request.conditionExpression());
        assertEquals(Map.of("#usage", "usage"), request.expressionAttributeNames());
    }
}
