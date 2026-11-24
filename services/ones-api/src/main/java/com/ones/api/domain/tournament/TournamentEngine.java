package com.ones.api.domain.tournament;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

import com.ones.api.domain.tournament.TournamentModels.LeaderboardEntry;
import com.ones.api.domain.tournament.TournamentModels.Match;
import com.ones.api.domain.tournament.TournamentModels.MatchPhase;
import com.ones.api.domain.tournament.TournamentModels.MatchScore;
import com.ones.api.domain.tournament.TournamentModels.MatchStatus;
import com.ones.api.domain.tournament.TournamentModels.Projection;
import com.ones.api.domain.tournament.TournamentModels.Standing;
import com.ones.api.domain.tournament.TournamentModels.Team;
import com.ones.api.domain.tournament.TournamentModels.TournamentState;
import com.ones.api.domain.tournament.TournamentModels.UserPrediction;

public final class TournamentEngine {

    private TournamentEngine() {
    }

    public static List<Match> createRoundRobinMatches(List<Team> teams) {
        if (teams == null || teams.size() != 4) {
            throw new IllegalArgumentException("The initial tournament format requires exactly four teams");
        }
        List<Match> matches = new ArrayList<>(6);
        int number = 1;
        for (int i = 0; i < teams.size(); i++) {
            for (int j = i + 1; j < teams.size(); j++) {
                matches.add(new Match(
                        "rr-" + number++,
                        MatchPhase.ROUND_ROBIN,
                        teams.get(i).id(),
                        teams.get(j).id(),
                        null,
                        MatchStatus.PENDING,
                        null,
                        null,
                        null));
            }
        }
        return List.copyOf(matches);
    }

    public static List<Standing> actualStandings(TournamentState state) {
        return calculateStandings(
                state.teams(),
                state.matches().stream()
                        .filter(m -> m.phase() == MatchPhase.ROUND_ROBIN && m.status() == MatchStatus.FINISHED)
                        .toList(),
                null,
                state.manualTieOrder());
    }

    public static Projection projectedStandings(TournamentState state, Map<String, MatchScore> forecasts) {
        List<Match> projectedMatches = state.matches().stream()
                .filter(m -> m.phase() == MatchPhase.ROUND_ROBIN)
                .map(m -> {
                    MatchScore score = forecasts == null ? null : forecasts.get(m.id());
                    if (score == null || !score.complete()) {
                        return new Match(
                                m.id(), m.phase(), m.homeTeamId(), m.awayTeamId(), m.scheduledAt(),
                                MatchStatus.PENDING, null, null, null);
                    }
                    return new Match(
                            m.id(), m.phase(), m.homeTeamId(), m.awayTeamId(), m.scheduledAt(),
                            MatchStatus.FINISHED, score.homeGoals(), score.awayGoals(), null);
                })
                .toList();

        List<Standing> standings = calculateStandings(state.teams(), projectedMatches, forecasts, List.of());
        boolean complete = state.matches().stream()
                .filter(m -> m.phase() == MatchPhase.ROUND_ROBIN)
                .allMatch(m -> {
                    MatchScore score = forecasts == null ? null : forecasts.get(m.id());
                    return score != null && score.complete();
                });
        return new Projection(
                standings,
                teamAt(standings, 0),
                teamAt(standings, 1),
                teamAt(standings, 2),
                teamAt(standings, 3),
                complete);
    }

    public static List<Match> assignKnockoutTeams(TournamentState state) {
        List<Standing> standings = actualStandings(state);
        if (standings.size() != 4 || standings.stream().mapToInt(Standing::played).sum() != 12) {
            throw new IllegalStateException("All six round-robin matches must be finished before creating knockout fixtures");
        }
        if (hasUnresolvedAbsoluteTie(standings, state.manualTieOrder())) {
            throw new IllegalStateException("Resolve the remaining standings tie before creating knockout fixtures");
        }

        String first = teamAt(standings, 0);
        String second = teamAt(standings, 1);
        String third = teamAt(standings, 2);
        String fourth = teamAt(standings, 3);
        return state.matches().stream()
                .map(match -> switch (match.phase()) {
                    case FINAL -> withTeams(match, first, second);
                    case THIRD_PLACE -> withTeams(match, third, fourth);
                    case ROUND_ROBIN -> match;
                })
                .toList();
    }

    public static int scoreMatch(MatchScore prediction, Integer actualHomeGoals, Integer actualAwayGoals) {
        if (prediction == null || !prediction.complete() || actualHomeGoals == null || actualAwayGoals == null) {
            return 0;
        }
        int predictedHome = prediction.homeGoals();
        int predictedAway = prediction.awayGoals();
        if (predictedHome == actualHomeGoals && predictedAway == actualAwayGoals) {
            return 10;
        }
        boolean oneTeamScoreExact = predictedHome == actualHomeGoals || predictedAway == actualAwayGoals;
        if (oneTeamScoreExact) {
            return 5;
        }
        return 0;
    }

    public static UserPrediction scorePrediction(
            TournamentState state,
            UserPrediction prediction,
            long resultVersion
    ) {
        if (prediction == null) {
            return null;
        }
        int points = 0;
        int exact = 0;
        int fives = 0;

        for (Match match : state.matches()) {
            if (match.status() != MatchStatus.FINISHED) {
                continue;
            }
            MatchScore forecast;
            if (match.phase() == MatchPhase.ROUND_ROBIN) {
                forecast = prediction.roundRobinScores().get(match.id());
            } else {
                Projection projected = projectedStandings(state, prediction.roundRobinScores());
                String expectedHome = match.phase() == MatchPhase.FINAL
                        ? projected.finalHomeTeamId()
                        : projected.thirdHomeTeamId();
                String expectedAway = match.phase() == MatchPhase.FINAL
                        ? projected.finalAwayTeamId()
                        : projected.thirdAwayTeamId();
                if (!Objects.equals(expectedHome, match.homeTeamId())
                        || !Objects.equals(expectedAway, match.awayTeamId())) {
                    continue;
                }
                forecast = match.phase() == MatchPhase.FINAL
                        ? prediction.finalScore()
                        : prediction.thirdPlaceScore();
            }
            int earned = scoreMatch(forecast, match.homeGoals(), match.awayGoals());
            points += earned;
            if (earned == 10) exact++;
            if (earned == 5) fives++;
        }

        return new UserPrediction(
                prediction.eventId(),
                prediction.userId(),
                prediction.displayName(),
                prediction.roundRobinScores(),
                prediction.finalScore(),
                prediction.thirdPlaceScore(),
                points,
                exact,
                fives,
                resultVersion,
                prediction.version(),
                prediction.updatedAt());
    }

    public static List<LeaderboardEntry> leaderboard(List<UserPrediction> predictions) {
        List<UserPrediction> sorted = predictions.stream()
                .sorted(Comparator.comparingInt(UserPrediction::points).reversed()
                        .thenComparing(Comparator.comparingInt(UserPrediction::exactCount).reversed())
                        .thenComparing(Comparator.comparingInt(UserPrediction::fivePointCount).reversed())
                        .thenComparing(UserPrediction::userId))
                .toList();
        List<LeaderboardEntry> result = new ArrayList<>(sorted.size());
        int place = 0;
        UserPrediction previous = null;
        for (int i = 0; i < sorted.size(); i++) {
            UserPrediction current = sorted.get(i);
            if (previous == null
                    || current.points() != previous.points()
                    || current.exactCount() != previous.exactCount()
                    || current.fivePointCount() != previous.fivePointCount()) {
                place = i + 1;
            }
            result.add(new LeaderboardEntry(
                    current.userId(),
                    current.displayName(),
                    current.points(),
                    current.exactCount(),
                    current.fivePointCount(),
                    place));
            previous = current;
        }
        return List.copyOf(result);
    }

    public static boolean hasUnresolvedAbsoluteTie(List<Standing> standings, List<String> manualOrder) {
        Map<String, Integer> manualRank = new HashMap<>();
        for (int i = 0; i < manualOrder.size(); i++) {
            manualRank.put(manualOrder.get(i), i);
        }
        for (int i = 0; i < standings.size() - 1; i++) {
            Standing current = standings.get(i);
            Standing next = standings.get(i + 1);
            if (current.points() == next.points()
                    && current.goalDifference() == next.goalDifference()
                    && current.goalsFor() == next.goalsFor()
                    && (!manualRank.containsKey(current.teamId())
                    || !manualRank.containsKey(next.teamId()))) {
                return true;
            }
        }
        return false;
    }

    private static List<Standing> calculateStandings(
            List<Team> teams,
            List<Match> matches,
            Map<String, MatchScore> partialScores,
            List<String> manualOrder
    ) {
        Map<String, MutableStanding> table = new HashMap<>();
        for (Team team : teams) {
            table.put(team.id(), new MutableStanding(team));
        }

        for (Match match : matches) {
            if (match.phase() != MatchPhase.ROUND_ROBIN) {
                continue;
            }
            Integer homeGoals = match.homeGoals();
            Integer awayGoals = match.awayGoals();
            if (match.status() != MatchStatus.FINISHED && partialScores != null) {
                MatchScore score = partialScores.get(match.id());
                if (score != null && score.complete()) {
                    homeGoals = score.homeGoals();
                    awayGoals = score.awayGoals();
                }
            }
            if (homeGoals == null || awayGoals == null) {
                continue;
            }
            MutableStanding home = table.get(match.homeTeamId());
            MutableStanding away = table.get(match.awayTeamId());
            if (home == null || away == null) {
                continue;
            }
            home.played++;
            away.played++;
            home.goalsFor += homeGoals;
            home.goalsAgainst += awayGoals;
            away.goalsFor += awayGoals;
            away.goalsAgainst += homeGoals;
            if (homeGoals > awayGoals) {
                home.wins++;
                away.losses++;
                home.points += 3;
            } else if (homeGoals < awayGoals) {
                away.wins++;
                home.losses++;
                away.points += 3;
            } else {
                home.draws++;
                away.draws++;
                home.points++;
                away.points++;
            }
        }

        Map<String, Integer> manualRank = new HashMap<>();
        for (int i = 0; i < manualOrder.size(); i++) {
            manualRank.put(manualOrder.get(i), i);
        }
        Map<String, Integer> seedRank = new HashMap<>();
        for (int i = 0; i < teams.size(); i++) {
            seedRank.put(teams.get(i).id(), i);
        }

        return table.values().stream()
                .sorted(Comparator.comparingInt((MutableStanding s) -> s.points).reversed()
                        .thenComparing(Comparator.comparingInt(MutableStanding::goalDifference).reversed())
                        .thenComparing(Comparator.comparingInt((MutableStanding s) -> s.goalsFor).reversed())
                        .thenComparingInt(s -> manualRank.getOrDefault(
                                s.team.id(),
                                manualOrder.isEmpty() ? seedRank.getOrDefault(s.team.id(), 0) : Integer.MAX_VALUE))
                        .thenComparing(s -> s.team.id()))
                .map(MutableStanding::toStanding)
                .toList();
    }

    private static Match withTeams(Match match, String homeTeamId, String awayTeamId) {
        return new Match(
                match.id(), match.phase(), homeTeamId, awayTeamId, match.scheduledAt(),
                MatchStatus.PENDING, null, null, null);
    }

    private static String teamAt(List<Standing> standings, int index) {
        return standings.size() > index ? standings.get(index).teamId() : null;
    }

    private static final class MutableStanding {
        private final Team team;
        private int played;
        private int wins;
        private int draws;
        private int losses;
        private int goalsFor;
        private int goalsAgainst;
        private int points;

        private MutableStanding(Team team) {
            this.team = team;
        }

        private int goalDifference() {
            return goalsFor - goalsAgainst;
        }

        private Standing toStanding() {
            return new Standing(
                    team.id(),
                    team.name(),
                    played,
                    wins,
                    draws,
                    losses,
                    goalsFor,
                    goalsAgainst,
                    goalDifference(),
                    points);
        }
    }
}
