package com.ones.api.application.tournament.ports;

public interface TournamentScoringQueue {

    void enqueue(String eventId);

    default void enqueueRecalculation(String eventId) {
        enqueue(eventId);
    }
}
