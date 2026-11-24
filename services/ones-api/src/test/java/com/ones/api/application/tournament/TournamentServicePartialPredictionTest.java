package com.ones.api.application.tournament;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import com.ones.api.adapters.outbound.dynamodb.DynamoDbTournamentRepository;
import com.ones.api.application.tournament.ports.TournamentScoringQueue;
import com.ones.api.domain.tournament.TournamentEngine;
import com.ones.api.domain.tournament.TournamentModels.Match;
import com.ones.api.domain.tournament.TournamentModels.MatchPhase;
import com.ones.api.domain.tournament.TournamentModels.MatchScore;
import com.ones.api.domain.tournament.TournamentModels.MatchStatus;
import com.ones.api.domain.tournament.TournamentModels.PredictionPeriod;
import com.ones.api.domain.tournament.TournamentModels.PredictionStatus;
import com.ones.api.domain.tournament.TournamentModels.Team;
import com.ones.api.domain.tournament.TournamentModels.TournamentState;
import com.ones.api.domain.tournament.TournamentModels.UserPrediction;

class TournamentServicePartialPredictionTest {

    @Test
    void normalizesPartialScoresAndMissingMatchesToZero() {
        DynamoDbTournamentRepository repository = mock(DynamoDbTournamentRepository.class);
        TournamentService service = new TournamentService(
                repository,
                mock(TournamentScoringQueue.class),
                Clock.fixed(Instant.EPOCH, ZoneOffset.UTC));
        List<Team> teams = List.of(
                new Team("team-1", "Team 1", null, List.of()),
                new Team("team-2", "Team 2", null, List.of()),
                new Team("team-3", "Team 3", null, List.of()),
                new Team("team-4", "Team 4", null, List.of()));
        List<Match> matches = new ArrayList<>(TournamentEngine.createRoundRobinMatches(teams));
        matches.add(new Match(
                "final", MatchPhase.FINAL, null, null, null, MatchStatus.PENDING, null, null, null));
        matches.add(new Match(
                "third-place", MatchPhase.THIRD_PLACE, null, null, null, MatchStatus.PENDING, null, null, null));
        PredictionPeriod open = new PredictionPeriod(PredictionStatus.OPEN, Instant.EPOCH, "owner", null, null);
        TournamentState state = new TournamentState(
                "event-1", "owner", "Torneo", teams, matches, List.of(), List.of(), List.of(),
                open, open, true, 1, Instant.EPOCH);
        when(repository.findStateForUser("event-1", "user-1")).thenReturn(Optional.of(state));
        when(repository.findPrediction("event-1", "user-1")).thenReturn(Optional.empty());
        when(repository.savePredictionIfOpen(any(UserPrediction.class), eq(0L))).thenReturn(true);

        service.savePrediction(
                "event-1",
                "user-1",
                "Participant",
                Map.of("rr-1", new MatchScore(2, null), "rr-3", new MatchScore(null, 1)),
                null,
                null);

        ArgumentCaptor<UserPrediction> predictionCaptor = ArgumentCaptor.forClass(UserPrediction.class);
        verify(repository).savePredictionIfOpen(predictionCaptor.capture(), eq(0L));
        UserPrediction prediction = predictionCaptor.getValue();
        assertEquals(6, prediction.roundRobinScores().size());
        assertEquals(new MatchScore(2, 0), prediction.roundRobinScores().get("rr-1"));
        assertEquals(new MatchScore(0, 0), prediction.roundRobinScores().get("rr-2"));
        assertEquals(new MatchScore(0, 1), prediction.roundRobinScores().get("rr-3"));
        assertEquals(new MatchScore(0, 0), prediction.finalScore());
        assertEquals(new MatchScore(0, 0), prediction.thirdPlaceScore());
    }
}
