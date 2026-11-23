package com.ones.api.application.tournament;

import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.function.UnaryOperator;

import org.springframework.stereotype.Service;

import com.ones.api.adapters.outbound.dynamodb.DynamoDbTournamentRepository;
import com.ones.api.application.tournament.ports.TournamentScoringQueue;
import com.ones.api.domain.tournament.TournamentEngine;
import com.ones.api.domain.tournament.TournamentModels.LeaderboardEntry;
import com.ones.api.domain.tournament.TournamentModels.Match;
import com.ones.api.domain.tournament.TournamentModels.MatchPhase;
import com.ones.api.domain.tournament.TournamentModels.MatchScore;
import com.ones.api.domain.tournament.TournamentModels.MatchStatus;
import com.ones.api.domain.tournament.TournamentModels.PredictionPeriod;
import com.ones.api.domain.tournament.TournamentModels.PredictionStatus;
import com.ones.api.domain.tournament.TournamentModels.Projection;
import com.ones.api.domain.tournament.TournamentModels.Standing;
import com.ones.api.domain.tournament.TournamentModels.Team;
import com.ones.api.domain.tournament.TournamentModels.TournamentState;
import com.ones.api.domain.tournament.TournamentModels.UserPrediction;

@Service
public class TournamentService {

    private final DynamoDbTournamentRepository repository;
    private final TournamentScoringQueue scoringQueue;
    private final Clock clock;

    public TournamentService(
            DynamoDbTournamentRepository repository,
            TournamentScoringQueue scoringQueue,
            Clock clock
    ) {
        this.repository = repository;
        this.scoringQueue = scoringQueue;
        this.clock = clock;
    }

    public void initialize(String eventId, String ownerId, String tabLabel) {
        Instant now = Instant.now(clock);
        TournamentState state = new TournamentState(
                eventId,
                ownerId,
                tabLabel,
                List.of(),
                List.of(),
                List.of(),
                List.of(),
                List.of(),
                PredictionPeriod.notStarted(),
                PredictionPeriod.notStarted(),
                false,
                1,
                now);
        repository.createState(state);
    }

    public TournamentState getState(String eventId) {
        return repository.findState(eventId).orElseThrow(() -> new TournamentNotFoundException(eventId));
    }

    public TournamentView view(String eventId, String userId) {
        TournamentState state = repository.findStateForUser(eventId, userId)
                .orElseThrow(() -> new TournamentNotFoundException(eventId));
        UserPrediction prediction = repository.findPrediction(eventId, userId).orElse(null);
        boolean isOwner = state.ownerId().equals(userId);
        boolean isDelegate = state.delegateUserIds().contains(userId);
        boolean predictionsRevealed = state.groupPredictionPeriod().status() == PredictionStatus.CLOSED
                && state.knockoutPredictionPeriod().status() == PredictionStatus.CLOSED;
        List<LeaderboardEntry> leaderboard = predictionsRevealed
                ? repository.listLeaderboard(eventId, 100)
                : List.of();
        Projection projection = prediction == null
                ? TournamentEngine.projectedStandings(state, Map.of())
                : TournamentEngine.projectedStandings(state, prediction.roundRobinScores());
        return new TournamentView(
                state,
                TournamentEngine.actualStandings(state),
                prediction,
                projection,
                isOwner,
                isDelegate,
                predictionsRevealed,
                leaderboard);
    }

    public TournamentState saveSetup(String eventId, String requesterId, List<TeamInput> teamInputs) {
        TournamentState current = requireOwner(getState(eventId), requesterId);
        if (teamInputs == null || teamInputs.size() != 4) {
            throw new IllegalArgumentException("Exactly four teams are required");
        }
        if (current.matches().stream().anyMatch(m -> m.status() != MatchStatus.PENDING)) {
            throw new TournamentConflictException("Teams cannot be changed after a match has started");
        }

        Set<String> normalizedNames = new HashSet<>();
        List<Team> teams = new ArrayList<>(4);
        for (int i = 0; i < teamInputs.size(); i++) {
            TeamInput input = teamInputs.get(i);
            String name = input.name() == null ? "" : input.name().trim();
            if (name.isEmpty()) {
                throw new IllegalArgumentException("Team names are required");
            }
            if (!normalizedNames.add(name.toLowerCase(Locale.ROOT))) {
                throw new IllegalArgumentException("Team names must be unique");
            }
            String id = input.id() == null || input.id().isBlank()
                    ? UUID.randomUUID().toString()
                    : input.id().trim();
            teams.add(new Team(id, name, input.logoKey(), normalizedMembers(input.members())));
        }

        List<Match> matches = new ArrayList<>(TournamentEngine.createRoundRobinMatches(teams));
        matches.add(new Match("final", MatchPhase.FINAL, null, null, null, MatchStatus.PENDING, null, null, null));
        matches.add(new Match("third-place", MatchPhase.THIRD_PLACE, null, null, null,
                MatchStatus.PENDING, null, null, null));
        boolean configured = teams.size() == 4;
        TournamentState next = new TournamentState(
                current.eventId(), current.ownerId(), normalizedTabName(current.shortName()),
                List.copyOf(teams), List.copyOf(matches), current.delegateUserIds(), current.delegateEmails(),
                List.of(), current.groupPredictionPeriod(), current.knockoutPredictionPeriod(),
                configured, current.version() + 1, Instant.now(clock));
        saveVersion(current, next);
        return next;
    }

    public TournamentState setTeamLogo(String eventId, String requesterId, String teamId, String logoKey) {
        TournamentState current = requireOwner(getState(eventId), requesterId);
        if (logoKey == null || !logoKey.startsWith("tournament/" + eventId + "/teams/" + teamId + "/")) {
            throw new IllegalArgumentException("Logo key is outside the tournament team namespace");
        }
        List<Team> teams = current.teams().stream()
                .map(team -> team.id().equals(teamId)
                        ? new Team(team.id(), team.name(), logoKey, team.members())
                        : team)
                .toList();
        if (teams.stream().noneMatch(team -> team.id().equals(teamId))) {
            throw new IllegalArgumentException("Unknown team");
        }
        boolean configured = teams.size() == 4
                && teams.stream().allMatch(team -> team.name() != null && !team.name().isBlank());
        TournamentState next = copy(
                current, teams, current.matches(), current.delegateUserIds(), current.delegateEmails(),
                current.manualTieOrder(), current.groupPredictionPeriod(), current.knockoutPredictionPeriod(),
                configured);
        saveVersion(current, next);
        return next;
    }

    public TournamentState setDelegates(
            String eventId,
            String requesterId,
            List<String> delegateUserIds,
            List<String> delegateEmails
    ) {
        TournamentState current = requireOwner(getState(eventId), requesterId);
        List<String> ids = delegateUserIds == null ? List.of() : delegateUserIds.stream()
                .filter(Objects::nonNull).map(String::trim).filter(s -> !s.isEmpty()).distinct().toList();
        List<String> emails = delegateEmails == null ? List.of() : delegateEmails.stream()
                .filter(Objects::nonNull).map(s -> s.trim().toLowerCase(Locale.ROOT))
                .filter(s -> !s.isEmpty()).distinct().toList();
        TournamentState next = copy(
                current, current.teams(), current.matches(), ids, emails, current.manualTieOrder(),
                current.groupPredictionPeriod(), current.knockoutPredictionPeriod(), current.configured());
        saveVersion(current, next);
        return next;
    }

    public TournamentState schedule(String eventId, String requesterId, Map<String, Instant> schedule) {
        TournamentState current = requireManager(getState(eventId), requesterId);
        Map<String, Instant> times = schedule == null ? Map.of() : schedule;
        List<Match> matches = current.matches().stream()
                .map(match -> {
                    if (match.status() != MatchStatus.PENDING) return match;
                    Instant time = times.get(match.id());
                    return time == null ? match : new Match(
                            match.id(), match.phase(), match.homeTeamId(), match.awayTeamId(), time,
                            match.status(), match.homeGoals(), match.awayGoals(), match.penaltyWinnerTeamId());
                })
                .toList();
        TournamentState next = copy(
                current, current.teams(), matches, current.delegateUserIds(), current.delegateEmails(),
                current.manualTieOrder(), current.groupPredictionPeriod(), current.knockoutPredictionPeriod(),
                current.configured());
        saveVersion(current, next);
        return next;
    }

    public TournamentState startPredictions(String eventId, String requesterId) {
        TournamentState current = requireManager(getState(eventId), requesterId);
        if (!current.configured()) throw new TournamentConflictException("Complete tournament setup first");
        if (current.groupPredictionPeriod().status() == PredictionStatus.OPEN
                || current.knockoutPredictionPeriod().status() == PredictionStatus.OPEN) {
            return current;
        }
        Instant now = Instant.now(clock);
        PredictionPeriod open = new PredictionPeriod(PredictionStatus.OPEN, now, requesterId, null, null);
        TournamentState next = copy(
                current, current.teams(), current.matches(), current.delegateUserIds(), current.delegateEmails(),
                current.manualTieOrder(), open, open, current.configured());
        savePeriodState(current, next);
        return next;
    }

    public TournamentState closePredictions(String eventId, String requesterId) {
        TournamentState current = requireManager(getState(eventId), requesterId);
        if (current.groupPredictionPeriod().status() == PredictionStatus.CLOSED
                && current.knockoutPredictionPeriod().status() == PredictionStatus.CLOSED) {
            scoringQueue.enqueue(eventId);
            return current;
        }
        if (current.groupPredictionPeriod().status() != PredictionStatus.OPEN
                && current.knockoutPredictionPeriod().status() != PredictionStatus.OPEN) {
            throw new TournamentConflictException("Predictions are not open");
        }
        Instant now = Instant.now(clock);
        PredictionPeriod closed = new PredictionPeriod(
                PredictionStatus.CLOSED,
                current.groupPredictionPeriod().startedAt(),
                current.groupPredictionPeriod().startedBy(),
                now,
                requesterId);
        TournamentState next = copy(
                current, current.teams(), current.matches(), current.delegateUserIds(), current.delegateEmails(),
                current.manualTieOrder(), closed, closed, current.configured());
        savePeriodState(current, next);
        scoringQueue.enqueue(eventId);
        return next;
    }

    public UserPrediction savePrediction(
            String eventId,
            String userId,
            String displayName,
            Map<String, MatchScore> roundRobinScores,
            MatchScore finalScore,
            MatchScore thirdPlaceScore
    ) {
        TournamentState state = repository.findStateForUser(eventId, userId)
                .orElseThrow(() -> new TournamentNotFoundException(eventId));
        if (state.groupPredictionPeriod().status() != PredictionStatus.OPEN
                || state.knockoutPredictionPeriod().status() != PredictionStatus.OPEN) {
            throw new TournamentConflictException("Predictions are not open");
        }
        validatePredictionScores(roundRobinScores, finalScore, thirdPlaceScore);
        UserPrediction previous = repository.findPrediction(eventId, userId).orElse(null);
        if (previous != null
                && Objects.equals(previous.roundRobinScores(), roundRobinScores)
                && Objects.equals(previous.finalScore(), finalScore)
                && Objects.equals(previous.thirdPlaceScore(), thirdPlaceScore)) {
            return previous;
        }
        UserPrediction candidate = new UserPrediction(
                eventId,
                userId,
                displayName == null || displayName.isBlank() ? userId : displayName.trim(),
                roundRobinScores == null ? Map.of() : Map.copyOf(roundRobinScores),
                finalScore,
                thirdPlaceScore,
                0,
                0,
                0,
                -1,
                previous == null ? 1 : previous.version() + 1,
                Instant.now(clock));
        UserPrediction scored = TournamentEngine.scorePrediction(state, candidate, state.version());
        long previousVersion = previous == null ? 0 : previous.version();
        if (!repository.savePredictionIfOpen(scored, previousVersion)) {
            throw new TournamentConflictException("Tournament changed while saving predictions; refresh and retry");
        }
        return scored;
    }

    public TournamentState startMatch(String eventId, String requesterId, String matchId) {
        TournamentState current = requireManager(getState(eventId), requesterId);
        Match target = findMatch(current, matchId);
        if (target.status() != MatchStatus.PENDING) {
            throw new TournamentConflictException("Only pending matches can be started");
        }
        if (target.homeTeamId() == null || target.awayTeamId() == null) {
            throw new TournamentConflictException("Match teams have not been determined");
        }
        List<Match> matches = current.matches().stream()
                .map(match -> match.id().equals(matchId)
                        ? new Match(match.id(), match.phase(), match.homeTeamId(), match.awayTeamId(),
                        match.scheduledAt(), MatchStatus.IN_PROGRESS, null, null, null)
                        : match)
                .toList();
        TournamentState next = copy(
                current, current.teams(), matches, current.delegateUserIds(), current.delegateEmails(),
                current.manualTieOrder(), current.groupPredictionPeriod(), current.knockoutPredictionPeriod(),
                current.configured());
        saveVersion(current, next);
        return next;
    }

    public TournamentState finishMatch(
            String eventId,
            String requesterId,
            String matchId,
            int homeGoals,
            int awayGoals,
            String penaltyWinnerTeamId
    ) {
        return finishMatch(eventId, requesterId, matchId, homeGoals, awayGoals, penaltyWinnerTeamId, false);
    }

    public TournamentState finishMatch(
            String eventId,
            String requesterId,
            String matchId,
            int homeGoals,
            int awayGoals,
            String penaltyWinnerTeamId,
            boolean confirmKnockoutReset
    ) {
        TournamentState current = requireManager(getState(eventId), requesterId);
        Match target = findMatch(current, matchId);
        if (target.status() == MatchStatus.FINISHED
                && Objects.equals(target.homeGoals(), homeGoals)
                && Objects.equals(target.awayGoals(), awayGoals)
                && Objects.equals(target.penaltyWinnerTeamId(), penaltyWinnerTeamId)) {
            scoringQueue.enqueue(eventId);
            return current;
        }
        boolean correcting = target.status() == MatchStatus.FINISHED;
        if (target.status() != MatchStatus.IN_PROGRESS && !correcting) {
            throw new TournamentConflictException("Only in-progress matches can be finalized");
        }
        if (homeGoals < 0 || awayGoals < 0 || homeGoals > 99 || awayGoals > 99) {
            throw new IllegalArgumentException("Scores must be between 0 and 99");
        }
        if (target.phase() == MatchPhase.ROUND_ROBIN && penaltyWinnerTeamId != null) {
            throw new IllegalArgumentException("Round-robin matches do not use penalties");
        }
        if (target.phase() != MatchPhase.ROUND_ROBIN && homeGoals == awayGoals
                && !Objects.equals(penaltyWinnerTeamId, target.homeTeamId())
                && !Objects.equals(penaltyWinnerTeamId, target.awayTeamId())) {
            throw new IllegalArgumentException("A penalty shootout winner is required for a knockout draw");
        }
        if (homeGoals != awayGoals && penaltyWinnerTeamId != null) {
            throw new IllegalArgumentException("Penalty winner is only valid for a drawn knockout match");
        }

        boolean knockoutHasResults = target.phase() == MatchPhase.ROUND_ROBIN
                && current.matches().stream()
                .anyMatch(match -> match.phase() != MatchPhase.ROUND_ROBIN
                        && match.status() != MatchStatus.PENDING);
        if (correcting && target.phase() == MatchPhase.ROUND_ROBIN
                && knockoutHasResults && !confirmKnockoutReset) {
            throw new TournamentConflictException(
                    "Confirm resetting the final and third-place results before correcting this group match");
        }

        List<Match> matches = current.matches().stream()
                .map(match -> correcting && target.phase() == MatchPhase.ROUND_ROBIN
                        && match.phase() != MatchPhase.ROUND_ROBIN
                        && knockoutHasResults
                        ? new Match(match.id(), match.phase(), null, null, match.scheduledAt(),
                                MatchStatus.PENDING, null, null, null)
                        : match.id().equals(matchId)
                        ? new Match(match.id(), match.phase(), match.homeTeamId(), match.awayTeamId(),
                        match.scheduledAt(), MatchStatus.FINISHED, homeGoals, awayGoals, penaltyWinnerTeamId)
                        : match)
                .toList();
        boolean reopenPredictions = correcting
                && target.phase() == MatchPhase.ROUND_ROBIN
                && current.groupPredictionPeriod().status() == PredictionStatus.CLOSED;
        PredictionPeriod reopened = reopenPredictions
                ? new PredictionPeriod(PredictionStatus.OPEN,
                        current.groupPredictionPeriod().startedAt(),
                        requesterId, null, null)
                : current.groupPredictionPeriod();
        TournamentState next = copy(
                current, current.teams(), matches, current.delegateUserIds(), current.delegateEmails(),
                current.manualTieOrder(), reopened,
                reopenPredictions ? reopened : current.knockoutPredictionPeriod(),
                current.configured());
        if (target.phase() == MatchPhase.ROUND_ROBIN
                && matches.stream().filter(m -> m.phase() == MatchPhase.ROUND_ROBIN)
                .allMatch(m -> m.status() == MatchStatus.FINISHED)) {
            try {
                List<Match> withKnockoutTeams = TournamentEngine.assignKnockoutTeams(next);
                next = copy(
                        next, next.teams(), withKnockoutTeams, next.delegateUserIds(), next.delegateEmails(),
                        next.manualTieOrder(), next.groupPredictionPeriod(), next.knockoutPredictionPeriod(),
                        next.configured());
            } catch (IllegalStateException ignored) {
                // The owner/delegate must resolve an absolute standings tie before knockout fixtures are assigned.
            }
        }
        if (reopenPredictions) {
            savePeriodState(current, next);
        } else {
            saveVersion(current, next);
        }
        repository.appendAudit(
                eventId,
                next.version(),
                correcting ? "MATCH_RESULT_CORRECTED" : "MATCH_RESULT",
                requesterId,
                correcting ? "Match result corrected by event manager"
                        : "Match result finalized by event manager",
                Map.of("matchId", matchId, "status", target.status().name()),
                Map.of("matchId", matchId, "homeGoals", homeGoals, "awayGoals", awayGoals,
                        "penaltyWinnerTeamId", penaltyWinnerTeamId == null ? "" : penaltyWinnerTeamId));
        scoringQueue.enqueue(eventId);
        return next;
    }

    public TournamentState setTieBreakOrder(String eventId, String requesterId, List<String> teamIds) {
        return setTieBreakOrder(eventId, requesterId, teamIds, "Manual tie-break resolution");
    }

    public TournamentState setTieBreakOrder(
            String eventId,
            String requesterId,
            List<String> teamIds,
            String reason
    ) {
        TournamentState current = requireManager(getState(eventId), requesterId);
        Set<String> valid = current.teams().stream().map(Team::id).collect(java.util.stream.Collectors.toSet());
        List<String> order = teamIds == null ? List.of() : teamIds.stream()
                .filter(Objects::nonNull).map(String::trim).filter(valid::contains).distinct().toList();
        if (order.size() != 4) {
            throw new IllegalArgumentException("Tie-break order must include each tournament team once");
        }
        TournamentState next = copy(
                current, current.teams(), current.matches(), current.delegateUserIds(), current.delegateEmails(),
                order, current.groupPredictionPeriod(), current.knockoutPredictionPeriod(), current.configured());
        if (next.matches().stream().filter(m -> m.phase() == MatchPhase.ROUND_ROBIN)
                .allMatch(m -> m.status() == MatchStatus.FINISHED)) {
            List<Match> withKnockoutTeams = TournamentEngine.assignKnockoutTeams(next);
            next = copy(
                    next, next.teams(), withKnockoutTeams, next.delegateUserIds(), next.delegateEmails(),
                    next.manualTieOrder(), next.groupPredictionPeriod(), next.knockoutPredictionPeriod(),
                    next.configured());
        }
        saveVersion(current, next);
        repository.appendAudit(
                eventId,
                next.version(),
                "MANUAL_TIE_BREAK",
                requesterId,
                reason,
                Map.of("teamIds", current.manualTieOrder()),
                Map.of("teamIds", order));
        return next;
    }

    public List<UserPrediction> forecastsForMembers(String eventId, int limit) {
        TournamentState state = getState(eventId);
        if (state.groupPredictionPeriod().status() != PredictionStatus.CLOSED
                || state.knockoutPredictionPeriod().status() != PredictionStatus.CLOSED) {
            throw new TournamentConflictException("Forecasts are hidden until predictions close");
        }
        return repository.listPredictions(eventId, limit);
    }

    public List<LeaderboardEntry> leaderboard(String eventId) {
        getState(eventId);
        return repository.listLeaderboard(eventId, 100);
    }

    public void purge(String eventId) {
        repository.deleteByEventId(eventId);
    }

    private TournamentState requireOwner(TournamentState state, String requesterId) {
        if (!state.ownerId().equals(requesterId)) {
            throw new org.springframework.web.server.ResponseStatusException(
                    org.springframework.http.HttpStatus.FORBIDDEN, "Owner permission required");
        }
        return state;
    }

    private TournamentState requireManager(TournamentState state, String requesterId) {
        if (!state.ownerId().equals(requesterId) && !state.delegateUserIds().contains(requesterId)) {
            throw new org.springframework.web.server.ResponseStatusException(
                    org.springframework.http.HttpStatus.FORBIDDEN, "Tournament manager permission required");
        }
        return state;
    }

    private void saveVersion(TournamentState current, TournamentState next) {
        if (!repository.saveState(next, current.version())) {
            throw new TournamentConflictException("Tournament changed concurrently; reload and retry");
        }
    }

    private void savePeriodState(TournamentState current, TournamentState next) {
        if (!repository.saveStateAndGates(
                next,
                current.version(),
                next.groupPredictionPeriod().status().name())) {
            throw new TournamentConflictException("Tournament period changed concurrently; reload and retry");
        }
    }

    private TournamentState copy(
            TournamentState source,
            List<Team> teams,
            List<Match> matches,
            List<String> delegateUserIds,
            List<String> delegateEmails,
            List<String> tieOrder,
            PredictionPeriod groupPeriod,
            PredictionPeriod knockoutPeriod,
            boolean configured
    ) {
        return new TournamentState(
                source.eventId(), source.ownerId(), source.shortName(),
                List.copyOf(teams), List.copyOf(matches), List.copyOf(delegateUserIds),
                List.copyOf(delegateEmails), List.copyOf(tieOrder), groupPeriod, knockoutPeriod,
                configured, source.version() + 1, Instant.now(clock));
    }

    private static Match findMatch(TournamentState state, String matchId) {
        return state.matches().stream()
                .filter(match -> match.id().equals(matchId))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Unknown match"));
    }

    private static void validatePredictionScores(
            Map<String, MatchScore> roundRobin,
            MatchScore finalScore,
            MatchScore thirdScore
    ) {
        if (roundRobin == null) return;
        for (Map.Entry<String, MatchScore> entry : roundRobin.entrySet()) {
            if (entry.getKey() == null || !entry.getKey().matches("rr-[1-6]")) {
                throw new IllegalArgumentException("Unknown round-robin match");
            }
            validateScore(entry.getValue());
        }
        validateScore(finalScore);
        validateScore(thirdScore);
    }

    private static void validateScore(MatchScore score) {
        if (score == null) return;
        if ((score.homeGoals() != null && (score.homeGoals() < 0 || score.homeGoals() > 99))
                || (score.awayGoals() != null && (score.awayGoals() < 0 || score.awayGoals() > 99))) {
            throw new IllegalArgumentException("Forecast scores must be between 0 and 99");
        }
    }

    private static List<String> normalizedMembers(List<String> members) {
        if (members == null) return List.of();
        return members.stream().filter(Objects::nonNull).map(String::trim)
                .filter(value -> !value.isEmpty()).distinct().limit(30).toList();
    }

    private static String normalizedTabName(String name) {
        String result = name == null ? "" : name.trim();
        return result.isEmpty() ? "Torneo" : result.substring(0, Math.min(result.length(), 24));
    }

    public record TeamInput(String id, String name, String logoKey, List<String> members) {
    }

    public record TournamentView(
            TournamentState tournament,
            List<Standing> standings,
            UserPrediction myPrediction,
            Projection myProjection,
            boolean owner,
            boolean delegate,
            boolean forecastsRevealed,
            List<LeaderboardEntry> leaderboard
    ) {
    }
}
