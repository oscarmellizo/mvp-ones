package com.ones.api.domain.tournament;

import java.time.Instant;
import java.util.List;
import java.util.Map;

public final class TournamentModels {

    private TournamentModels() {
    }

    public enum MatchPhase {
        ROUND_ROBIN,
        FINAL,
        THIRD_PLACE
    }

    public enum MatchStatus {
        PENDING,
        IN_PROGRESS,
        FINISHED
    }

    public enum PredictionStatus {
        NOT_STARTED,
        OPEN,
        CLOSED
    }

    public record Team(
            String id,
            String name,
            String logoKey,
            List<String> members
    ) {
    }

    public record Match(
            String id,
            MatchPhase phase,
            String homeTeamId,
            String awayTeamId,
            Instant scheduledAt,
            MatchStatus status,
            Integer homeGoals,
            Integer awayGoals,
            String penaltyWinnerTeamId
    ) {
    }

    public record PredictionPeriod(
            PredictionStatus status,
            Instant startedAt,
            String startedBy,
            Instant closedAt,
            String closedBy
    ) {
        public static PredictionPeriod notStarted() {
            return new PredictionPeriod(PredictionStatus.NOT_STARTED, null, null, null, null);
        }
    }

    public record TournamentState(
            String eventId,
            String ownerId,
            String shortName,
            List<Team> teams,
            List<Match> matches,
            List<String> delegateUserIds,
            List<String> delegateEmails,
            List<String> manualTieOrder,
            PredictionPeriod groupPredictionPeriod,
            PredictionPeriod knockoutPredictionPeriod,
            boolean configured,
            long version,
            Instant updatedAt
    ) {
    }

    public record MatchScore(Integer homeGoals, Integer awayGoals) {
        public boolean complete() {
            return homeGoals != null && awayGoals != null;
        }
    }

    public record UserPrediction(
            String eventId,
            String userId,
            String displayName,
            Map<String, MatchScore> roundRobinScores,
            MatchScore finalScore,
            MatchScore thirdPlaceScore,
            int points,
            int exactCount,
            int fivePointCount,
            long scoredVersion,
            long version,
            Instant updatedAt
    ) {
    }

    public record Standing(
            String teamId,
            String teamName,
            int played,
            int wins,
            int draws,
            int losses,
            int goalsFor,
            int goalsAgainst,
            int goalDifference,
            int points
    ) {
    }

    public record Projection(
            List<Standing> standings,
            String finalHomeTeamId,
            String finalAwayTeamId,
            String thirdHomeTeamId,
            String thirdAwayTeamId,
            boolean complete
    ) {
    }

    public record LeaderboardEntry(
            String userId,
            String displayName,
            int points,
            int exactCount,
            int fivePointCount,
            int place
    ) {
    }
}
