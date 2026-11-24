package com.ones.api.domain.tournament;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;

import com.ones.api.domain.tournament.TournamentModels.Match;
import com.ones.api.domain.tournament.TournamentModels.MatchPhase;
import com.ones.api.domain.tournament.TournamentModels.MatchScore;
import com.ones.api.domain.tournament.TournamentModels.MatchStatus;
import com.ones.api.domain.tournament.TournamentModels.PredictionPeriod;
import com.ones.api.domain.tournament.TournamentModels.Team;
import com.ones.api.domain.tournament.TournamentModels.TournamentState;

class TournamentEngineTest {

    private final List<Team> teams = List.of(
            new Team("a", "A", List.of()),
            new Team("b", "B", List.of()),
            new Team("c", "C", List.of()),
            new Team("d", "D", List.of()));

    @Test
    void projectedStandingsAutomaticallyAssignFinalAndThirdPlaceSlots() {
        TournamentState state = initialState(TournamentEngine.createRoundRobinMatches(teams));
        Map<String, MatchScore> forecasts = Map.of(
                "rr-1", new MatchScore(2, 0),
                "rr-2", new MatchScore(2, 0),
                "rr-3", new MatchScore(2, 0),
                "rr-4", new MatchScore(1, 0),
                "rr-5", new MatchScore(1, 0),
                "rr-6", new MatchScore(1, 0));

        var projection = TournamentEngine.projectedStandings(state, forecasts);

        assertTrue(projection.complete());
        assertEquals(List.of("a", "b", "c", "d"),
                projection.standings().stream().map(row -> row.teamId()).toList());
        assertEquals("a", projection.finalHomeTeamId());
        assertEquals("b", projection.finalAwayTeamId());
        assertEquals("c", projection.thirdHomeTeamId());
        assertEquals("d", projection.thirdAwayTeamId());
    }

    @Test
    void matchScoringAwardsOnlyExactOrOneTeamGoalHits() {
        assertEquals(10, TournamentEngine.scoreMatch(new MatchScore(2, 1), 2, 1));
        assertEquals(5, TournamentEngine.scoreMatch(new MatchScore(2, 0), 2, 1));
        assertEquals(5, TournamentEngine.scoreMatch(new MatchScore(0, 2), 1, 2));
        assertEquals(0, TournamentEngine.scoreMatch(new MatchScore(3, 3), 1, 1));
        assertEquals(0, TournamentEngine.scoreMatch(new MatchScore(2, 1), 1, 0));
        assertEquals(0, TournamentEngine.scoreMatch(new MatchScore(0, 2), 2, 1));
        assertEquals(0, TournamentEngine.scoreMatch(new MatchScore(null, 1), 2, 1));
    }

    @Test
    void actualKnockoutSlotsRequireAllSixFinishedGroupMatches() {
        List<Match> group = TournamentEngine.createRoundRobinMatches(teams).stream()
                .map(match -> new Match(
                        match.id(), match.phase(), match.homeTeamId(), match.awayTeamId(),
                        null, MatchStatus.FINISHED, 1, 0, null))
                .toList();
        TournamentState state = initialState(group);

        List<Match> assigned = TournamentEngine.assignKnockoutTeams(state);
        Match finalMatch = assigned.stream().filter(m -> m.phase() == MatchPhase.FINAL).findFirst().orElseThrow();
        Match thirdPlace = assigned.stream().filter(m -> m.phase() == MatchPhase.THIRD_PLACE)
                .findFirst().orElseThrow();

        assertEquals(12, TournamentEngine.actualStandings(state).stream()
                .mapToInt(row -> row.played()).sum());
        assertEquals("a", finalMatch.homeTeamId());
        assertEquals("b", finalMatch.awayTeamId());
        assertEquals("c", thirdPlace.homeTeamId());
        assertEquals("d", thirdPlace.awayTeamId());
    }

    private static TournamentState initialState(List<Match> groupMatches) {
        List<Match> matches = new ArrayList<>(groupMatches);
        matches.add(new Match(
                "final", MatchPhase.FINAL, null, null, null, MatchStatus.PENDING, null, null, null));
        matches.add(new Match(
                "third-place", MatchPhase.THIRD_PLACE, null, null, null, MatchStatus.PENDING, null, null, null));
        return new TournamentState(
                "event", "owner", "Torneo", List.of(
                        new Team("a", "A", List.of()),
                        new Team("b", "B", List.of()),
                        new Team("c", "C", List.of()),
                        new Team("d", "D", List.of())),
                matches, List.of(), List.of(), List.of(),
                PredictionPeriod.notStarted(), PredictionPeriod.notStarted(),
                true, 1, Instant.EPOCH);
    }
}
