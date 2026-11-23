package com.ones.api.adapters.inbound.rest.tournament;

import java.time.Instant;
import java.util.List;
import java.util.Map;

import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.adapters.inbound.rest.AuthClaims;
import com.ones.api.application.events.GetEventUseCase;
import com.ones.api.application.invitations.ports.InvitationsRepository;
import com.ones.api.application.tournament.TournamentService;
import com.ones.api.application.tournament.TournamentLogoService;
import com.ones.api.application.tournament.TournamentService.TeamInput;
import com.ones.api.application.tournament.TournamentService.TournamentView;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.invitations.Invitation;
import com.ones.api.domain.tournament.TournamentModels.MatchScore;
import com.ones.api.domain.tournament.TournamentModels.TournamentState;
import com.ones.api.domain.tournament.TournamentModels.UserPrediction;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

@RestController
@RequestMapping("/v1/events/{eventId}/tournament")
public class TournamentController {

    private final TournamentService tournamentService;
    private final TournamentLogoService logoService;
    private final GetEventUseCase getEventUseCase;
    private final InvitationsRepository invitationsRepository;

    public TournamentController(
            TournamentService tournamentService,
            TournamentLogoService logoService,
            GetEventUseCase getEventUseCase,
            InvitationsRepository invitationsRepository
    ) {
        this.tournamentService = tournamentService;
        this.logoService = logoService;
        this.getEventUseCase = getEventUseCase;
        this.invitationsRepository = invitationsRepository;
    }

    @GetMapping
    public TournamentView get(Authentication authentication, @PathVariable String eventId) {
        requireEvent(authentication, eventId);
        return tournamentService.view(eventId, authentication.getName());
    }

    @PutMapping("/setup")
    public TournamentState setup(
            Authentication authentication,
            @PathVariable String eventId,
            @Valid @RequestBody SetupRequest request
    ) {
        Event event = requireEvent(authentication, eventId);
        return tournamentService.saveSetup(eventId, event.getOwnerId(), request.teams());
    }

    @PostMapping("/teams/{teamId}/logos/upload")
    public TournamentLogoService.LogoPreview uploadLogo(
            Authentication authentication,
            @PathVariable String eventId,
            @PathVariable String teamId,
            @Valid @RequestBody LogoUploadRequest request
    ) {
        requireEvent(authentication, eventId);
        return logoService.upload(eventId, authentication.getName(), teamId, request.imageBase64());
    }

    @PostMapping("/teams/{teamId}/logos/generate")
    public TournamentLogoService.LogoPreview generateLogo(
            Authentication authentication,
            @PathVariable String eventId,
            @PathVariable String teamId,
            @Valid @RequestBody LogoGenerateRequest request
    ) {
        requireEvent(authentication, eventId);
        return logoService.generate(eventId, authentication.getName(), teamId, request.prompt());
    }

    @PostMapping("/teams/{teamId}/logos/accept")
    public LogoAcceptedResponse acceptLogo(
            Authentication authentication,
            @PathVariable String eventId,
            @PathVariable String teamId,
            @Valid @RequestBody LogoAcceptRequest request
    ) {
        requireEvent(authentication, eventId);
        String key = logoService.accept(eventId, authentication.getName(), teamId, request.previewKey());
        return new LogoAcceptedResponse(key);
    }

    @GetMapping("/teams/{teamId}/logo")
    public LogoUrlResponse logoUrl(
            Authentication authentication,
            @PathVariable String eventId,
            @PathVariable String teamId
    ) {
        requireEvent(authentication, eventId);
        return new LogoUrlResponse(logoService.logoUrl(eventId, teamId).toString());
    }

    @PutMapping("/delegates")
    public TournamentState setDelegates(
            Authentication authentication,
            @PathVariable String eventId,
            @Valid @RequestBody DelegatesRequest request
    ) {
        Event event = requireEvent(authentication, eventId);
        if (!event.getOwnerId().equals(authentication.getName())) {
            throw new org.springframework.web.server.ResponseStatusException(
                    org.springframework.http.HttpStatus.FORBIDDEN, "Owner permission required");
        }
        List<String> acceptedUserIds = invitationsRepository.listByEventId(eventId, 500).stream()
                .filter(i -> i.getStatus() == Invitation.Status.accepted)
                .map(Invitation::getInviteeUserId)
                .filter(id -> id != null && !id.isBlank())
                .toList();
        List<String> requested = request.userIds() == null ? List.of() : request.userIds();
        if (requested.stream().anyMatch(id -> !acceptedUserIds.contains(id))) {
            throw new IllegalArgumentException("Delegates must already be accepted event members");
        }
        return tournamentService.setDelegates(eventId, event.getOwnerId(), requested, request.emails());
    }

    @PutMapping("/schedule")
    public TournamentState schedule(
            Authentication authentication,
            @PathVariable String eventId,
            @Valid @RequestBody ScheduleRequest request
    ) {
        requireEvent(authentication, eventId);
        return tournamentService.schedule(eventId, authentication.getName(), request.matchTimes());
    }

    @PostMapping("/predictions/start")
    public TournamentState startPredictions(Authentication authentication, @PathVariable String eventId) {
        requireEvent(authentication, eventId);
        return tournamentService.startPredictions(eventId, authentication.getName());
    }

    @PostMapping("/predictions/close")
    public TournamentState closePredictions(Authentication authentication, @PathVariable String eventId) {
        requireEvent(authentication, eventId);
        return tournamentService.closePredictions(eventId, authentication.getName());
    }

    @PutMapping("/predictions")
    public UserPrediction savePredictions(
            Authentication authentication,
            @PathVariable String eventId,
            @Valid @RequestBody PredictionRequest request
    ) {
        requireEvent(authentication, eventId);
        String displayName = AuthClaims.preferredName(authentication);
        return tournamentService.savePrediction(
                eventId,
                authentication.getName(),
                displayName,
                request.roundRobinScores(),
                request.finalScore(),
                request.thirdPlaceScore());
    }

    @PostMapping("/matches/{matchId}/start")
    public TournamentState startMatch(
            Authentication authentication,
            @PathVariable String eventId,
            @PathVariable String matchId
    ) {
        requireEvent(authentication, eventId);
        return tournamentService.startMatch(eventId, authentication.getName(), matchId);
    }

    @PutMapping("/matches/{matchId}/result")
    public TournamentState finishMatch(
            Authentication authentication,
            @PathVariable String eventId,
            @PathVariable String matchId,
            @Valid @RequestBody ResultRequest request
    ) {
        requireEvent(authentication, eventId);
        return tournamentService.finishMatch(
                eventId,
                authentication.getName(),
                matchId,
                request.homeGoals(),
                request.awayGoals(),
                request.penaltyWinnerTeamId(),
                request.confirmKnockoutReset());
    }

    @PutMapping("/standings/tie-break")
    public TournamentState setTieBreakOrder(
            Authentication authentication,
            @PathVariable String eventId,
            @Valid @RequestBody TieBreakRequest request
    ) {
        requireEvent(authentication, eventId);
        return tournamentService.setTieBreakOrder(
                eventId, authentication.getName(), request.teamIds(), request.reason());
    }

    @GetMapping("/predictions/leaderboard")
    public List<com.ones.api.domain.tournament.TournamentModels.LeaderboardEntry> leaderboard(
            Authentication authentication,
            @PathVariable String eventId
    ) {
        requireEvent(authentication, eventId);
        return tournamentService.leaderboard(eventId);
    }

    @GetMapping("/predictions/revealed")
    public List<UserPrediction> revealedPredictions(
            Authentication authentication,
            @PathVariable String eventId,
            @RequestParam(defaultValue = "100") int limit
    ) {
        requireEvent(authentication, eventId);
        return tournamentService.forecastsForMembers(eventId, Math.min(500, Math.max(1, limit)));
    }

    private Event requireEvent(Authentication authentication, String eventId) {
        String email = null;
        try {
            email = AuthClaims.requireEmail(authentication);
        } catch (RuntimeException ignored) {
            // Legacy owner tokens can still access their own event.
        }
        return getEventUseCase.execute(authentication.getName(), email, eventId);
    }

    public record SetupRequest(@NotNull List<TeamInput> teams) {
    }

    public record DelegatesRequest(List<String> userIds, List<String> emails) {
    }

    public record ScheduleRequest(@NotNull Map<String, Instant> matchTimes) {
    }

    public record PredictionRequest(
            @NotNull Map<String, MatchScore> roundRobinScores,
            MatchScore finalScore,
            MatchScore thirdPlaceScore
    ) {
    }

    public record ResultRequest(
            @NotNull Integer homeGoals,
            @NotNull Integer awayGoals,
            String penaltyWinnerTeamId,
            boolean confirmKnockoutReset
    ) {
    }

    public record TieBreakRequest(
            @NotNull List<String> teamIds,
            @NotBlank @Size(max = 500) String reason
    ) {
    }

    public record LogoUploadRequest(@NotBlank @Size(max = 5_600_000) String imageBase64) {
    }

    public record LogoGenerateRequest(@NotBlank @Size(max = 300) String prompt) {
    }

    public record LogoAcceptRequest(@NotBlank @Size(max = 1024) String previewKey) {
    }

    public record LogoAcceptedResponse(String logoKey) {
    }

    public record LogoUrlResponse(String url) {
    }
}
