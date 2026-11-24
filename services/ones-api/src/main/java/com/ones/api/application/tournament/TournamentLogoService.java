package com.ones.api.application.tournament;

import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.net.URL;
import java.time.Duration;
import java.util.Base64;
import java.util.UUID;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Map;

import javax.imageio.ImageIO;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ones.api.application.events.AiImageGenerationException;
import com.ones.api.application.events.ports.ObjectStorage;
import com.ones.api.application.events.ports.ObjectStoragePresigner;
import com.ones.api.domain.tournament.TournamentModels.Team;

import software.amazon.awssdk.core.SdkBytes;
import software.amazon.awssdk.services.bedrockruntime.BedrockRuntimeClient;
import software.amazon.awssdk.services.bedrockruntime.model.InvokeModelRequest;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.ConditionalCheckFailedException;
import software.amazon.awssdk.services.dynamodb.model.UpdateItemRequest;

@Service
public class TournamentLogoService {

    private static final int LOGO_SIZE = 512;
    private static final int MAX_UPLOAD_BYTES = 4 * 1024 * 1024;

    private final TournamentService tournamentService;
    private final ObjectStorage objectStorage;
    private final ObjectStoragePresigner presigner;
    private final BedrockRuntimeClient bedrock;
    private final DynamoDbClient dynamoDb;
    private final ObjectMapper objectMapper;
    private final String assetsBucket;
    private final String modelId;
    private final long previewTtlMinutes;
    private final int dailyGenerationQuota;
    private final String tournamentsTable;

    public TournamentLogoService(
            TournamentService tournamentService,
            ObjectStorage objectStorage,
            ObjectStoragePresigner presigner,
            BedrockRuntimeClient bedrock,
            DynamoDbClient dynamoDb,
            ObjectMapper objectMapper,
            @Value("${ones.s3.events.covers.final-bucket}") String assetsBucket,
            @Value("${ones.ai.bedrock.logo-model-id:stability.stable-image-core-v1:1}") String modelId,
            @Value("${ones.ai.bedrock.logo-preview-ttl-minutes:30}") long previewTtlMinutes,
            @Value("${ones.tournament.logo-daily-generation-quota:5}") int dailyGenerationQuota,
            @Value("${ones.dynamodb.tournaments-table-name:ones-dev-tournaments}") String tournamentsTable
    ) {
        this.tournamentService = tournamentService;
        this.objectStorage = objectStorage;
        this.presigner = presigner;
        this.bedrock = bedrock;
        this.dynamoDb = dynamoDb;
        this.objectMapper = objectMapper;
        this.assetsBucket = assetsBucket;
        this.modelId = modelId;
        this.previewTtlMinutes = previewTtlMinutes;
        this.dailyGenerationQuota = dailyGenerationQuota;
        this.tournamentsTable = tournamentsTable;
    }

    public LogoPreview upload(String eventId, String requesterId, String teamId, String base64Image) {
        requireOwner(eventId, requesterId);
        byte[] decoded;
        try {
            decoded = Base64.getDecoder().decode(base64Image);
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("Logo must be valid base64 image data");
        }
        if (decoded.length == 0 || decoded.length > MAX_UPLOAD_BYTES) {
            throw new IllegalArgumentException("Logo image must be no larger than 4 MB");
        }
        return savePreview(eventId, teamId, normalize(decoded));
    }

    public LogoPreview generate(String eventId, String requesterId, String teamId, String prompt) {
        var state = requireOwner(eventId, requesterId);
        Team team = state.teams().stream()
                .filter(value -> value.id().equals(teamId))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Unknown team"));
        String cleanedPrompt = prompt == null ? "" : prompt.trim();
        if (cleanedPrompt.isEmpty() || cleanedPrompt.length() > 300) {
            throw new IllegalArgumentException("Logo prompt must contain 1 to 300 characters");
        }
        consumeDailyGenerationQuota(requesterId);

        try {
            String fullPrompt = "Create a clean original sports tournament team logo, " +
                    "square composition, no text or lettering, for team \"" +
                    team.name().replace("\"", "") + "\". " + cleanedPrompt;
            String body = objectMapper.writeValueAsString(java.util.Map.of(
                    "prompt", fullPrompt,
                    "aspect_ratio", "1:1",
                    "output_format", "png"));
            var response = bedrock.invokeModel(InvokeModelRequest.builder()
                    .modelId(modelId)
                    .contentType("application/json")
                    .accept("application/json")
                    .body(SdkBytes.fromUtf8String(body))
                    .build());
            JsonNode payload = objectMapper.readTree(response.body().asUtf8String());
            String image = extractImage(payload);
            if (image.isBlank()) {
                throw new IllegalStateException("Bedrock returned no image");
            }
            return savePreview(eventId, teamId, normalize(Base64.getDecoder().decode(image)));
        } catch (Exception e) {
            throw new AiImageGenerationException("Unable to generate the team logo with Bedrock", e);
        }
    }

    static String extractImage(JsonNode payload) {
        String image = payload.path("images").path(0).asText();
        return image.isBlank()
                ? payload.path("artifacts").path(0).path("base64").asText()
                : image;
    }

    public String accept(String eventId, String requesterId, String teamId, String previewKey) {
        requireOwner(eventId, requesterId);
        String expectedPrefix = pendingPrefix(eventId, teamId);
        if (previewKey == null || !previewKey.startsWith(expectedPrefix)) {
            throw new IllegalArgumentException("Logo preview does not belong to this team");
        }
        String acceptedKey = "tournament/" + eventId + "/teams/" + teamId + "/logo-" +
                UUID.randomUUID() + ".png";
        objectStorage.copy(assetsBucket, previewKey, assetsBucket, acceptedKey);
        Team previous = tournamentService.getState(eventId).teams().stream()
                .filter(team -> team.id().equals(teamId))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Unknown team"));
        try {
            tournamentService.setTeamLogo(eventId, requesterId, teamId, acceptedKey);
        } catch (RuntimeException e) {
            objectStorage.delete(assetsBucket, acceptedKey);
            throw e;
        }
        objectStorage.delete(assetsBucket, previewKey);
        if (previous.logoKey() != null && !previous.logoKey().isBlank()) {
            objectStorage.delete(assetsBucket, previous.logoKey());
        }
        return acceptedKey;
    }

    public URL logoUrl(String eventId, String teamId) {
        Team team = tournamentService.getState(eventId).teams().stream()
                .filter(value -> value.id().equals(teamId))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Unknown team"));
        if (team.logoKey() == null || team.logoKey().isBlank()) {
            throw new IllegalArgumentException("Team does not have a logo");
        }
        return presigner.presignGet(assetsBucket, team.logoKey(), Duration.ofMinutes(previewTtlMinutes));
    }

    private com.ones.api.domain.tournament.TournamentModels.TournamentState requireOwner(
            String eventId,
            String requesterId
    ) {
        var state = tournamentService.getState(eventId);
        if (!state.ownerId().equals(requesterId)) {
            throw new org.springframework.web.server.ResponseStatusException(
                    org.springframework.http.HttpStatus.FORBIDDEN, "Owner permission required");
        }
        return state;
    }

    private LogoPreview savePreview(String eventId, String teamId, byte[] png) {
        Team team = tournamentService.getState(eventId).teams().stream()
                .filter(value -> value.id().equals(teamId))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Unknown team"));
        String key = pendingPrefix(eventId, teamId) + UUID.randomUUID() + ".png";
        objectStorage.putPng(assetsBucket, key, png);
        URL url = presigner.presignGet(assetsBucket, key, Duration.ofMinutes(previewTtlMinutes));
        return new LogoPreview(team.id(), team.name(), key, url.toString(), LOGO_SIZE, LOGO_SIZE);
    }

    private static String pendingPrefix(String eventId, String teamId) {
        return "tournament-previews/" + eventId + "/teams/" + teamId + "/";
    }

    private void consumeDailyGenerationQuota(String requesterId) {
        LocalDate today = LocalDate.now(ZoneOffset.UTC);
        try {
            dynamoDb.updateItem(quotaUpdateRequest(
                    tournamentsTable, requesterId, today, dailyGenerationQuota));
        } catch (ConditionalCheckFailedException e) {
            throw new org.springframework.web.server.ResponseStatusException(
                    org.springframework.http.HttpStatus.TOO_MANY_REQUESTS,
                    "Daily team-logo generation quota reached");
        }
    }

    static UpdateItemRequest quotaUpdateRequest(
            String tableName,
            String requesterId,
            LocalDate today,
            int dailyGenerationQuota
    ) {
        int shard = Math.floorMod(requesterId.hashCode(), 16);
        long expiresAt = today.plusDays(2).atStartOfDay().toEpochSecond(ZoneOffset.UTC);
        return UpdateItemRequest.builder()
                .tableName(tableName)
                .key(Map.of(
                        "pk", AttributeValue.fromS("LOGOQUOTA#" + today + "#" + String.format("%02d", shard)),
                        "sk", AttributeValue.fromS("USER#" + requesterId)))
                .updateExpression("SET expiresAt = :expiry ADD #usage :one")
                .conditionExpression("attribute_not_exists(#usage) OR #usage < :limit")
                .expressionAttributeNames(Map.of("#usage", "usage"))
                .expressionAttributeValues(Map.of(
                        ":expiry", AttributeValue.fromN(Long.toString(expiresAt)),
                        ":one", AttributeValue.fromN("1"),
                        ":limit", AttributeValue.fromN(Integer.toString(dailyGenerationQuota))))
                .build();
    }

    private static byte[] normalize(byte[] imageBytes) {
        try {
            BufferedImage source = ImageIO.read(new ByteArrayInputStream(imageBytes));
            if (source == null) {
                throw new IllegalArgumentException("Unsupported image; use PNG or JPEG");
            }
            int side = Math.min(source.getWidth(), source.getHeight());
            int left = (source.getWidth() - side) / 2;
            int top = (source.getHeight() - side) / 2;
            BufferedImage output = new BufferedImage(LOGO_SIZE, LOGO_SIZE, BufferedImage.TYPE_INT_ARGB);
            Graphics2D graphics = output.createGraphics();
            try {
                graphics.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BICUBIC);
                graphics.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
                graphics.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
                graphics.drawImage(
                        source,
                        0, 0, LOGO_SIZE, LOGO_SIZE,
                        left, top, left + side, top + side,
                        null);
            } finally {
                graphics.dispose();
            }
            ByteArrayOutputStream outputBytes = new ByteArrayOutputStream();
            ImageIO.write(output, "png", outputBytes);
            return outputBytes.toByteArray();
        } catch (java.io.IOException e) {
            throw new IllegalArgumentException("Unable to read logo image", e);
        }
    }

    public record LogoPreview(
            String teamId,
            String teamName,
            String previewKey,
            String previewUrl,
            int width,
            int height
    ) {
    }
}
