package com.ones.api.adapters.inbound.rest;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import jakarta.validation.ConstraintViolation;
import jakarta.validation.ConstraintViolationException;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.HandlerMethodValidationException;

import com.ones.api.application.events.CoverPreviewNotFoundException;
import com.ones.api.application.events.CoverReservationExpiredException;
import com.ones.api.application.events.CoverReservationNotFoundException;
import com.ones.api.application.events.AiConfigurationException;
import com.ones.api.application.events.AiImageGenerationException;
import com.ones.api.application.events.EventCoverNotFoundException;
import com.ones.api.application.events.EventForbiddenException;
import com.ones.api.application.events.EventNotFoundException;
import com.ones.api.application.frames.FrameAssetNotFoundException;
import com.ones.api.application.frames.FrameNotFoundException;
import com.ones.api.application.invitations.InvitationClosedException;
import com.ones.api.application.invitations.InvitationNotFoundException;

@RestControllerAdvice
public class ApiExceptionHandler {

    @ExceptionHandler(EventNotFoundException.class)
    public ResponseEntity<Map<String, Object>> notFound(EventNotFoundException ex) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of(
                "error", "not_found",
                "message", ex.getMessage()
        ));
    }

    @ExceptionHandler(EventForbiddenException.class)
    public ResponseEntity<Map<String, Object>> forbidden(EventForbiddenException ex) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of(
                "error", "forbidden",
                "message", ex.getMessage()
        ));
    }

    @ExceptionHandler({CoverPreviewNotFoundException.class, CoverReservationNotFoundException.class, EventCoverNotFoundException.class})
    public ResponseEntity<Map<String, Object>> notFound(RuntimeException ex) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of(
                "error", "not_found",
                "message", ex.getMessage()
        ));
    }

    @ExceptionHandler({FrameNotFoundException.class, FrameAssetNotFoundException.class})
    public ResponseEntity<Map<String, Object>> frameNotFound(RuntimeException ex) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of(
                "error", "not_found",
                "message", ex.getMessage()
        ));
    }

    @ExceptionHandler(CoverReservationExpiredException.class)
    public ResponseEntity<Map<String, Object>> badRequest(CoverReservationExpiredException ex) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of(
                "error", "bad_request",
                "message", ex.getMessage()
        ));
    }

    @ExceptionHandler({AiConfigurationException.class, AiImageGenerationException.class})
    public ResponseEntity<Map<String, Object>> aiUnavailable(RuntimeException ex) {
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(Map.of(
                "error", "ai_unavailable",
                "message", ex.getMessage()
        ));
    }

    @ExceptionHandler(InvitationNotFoundException.class)
    public ResponseEntity<Map<String, Object>> invitationNotFound(InvitationNotFoundException ex) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of(
                "error", "not_found",
                "message", ex.getMessage()
        ));
    }

    @ExceptionHandler(InvitationClosedException.class)
    public ResponseEntity<Map<String, Object>> invitationClosed(InvitationClosedException ex) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of(
                "error", "bad_request",
                "message", ex.getMessage()
        ));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> validation(MethodArgumentNotValidException ex) {
        List<Map<String, Object>> details = ex.getBindingResult()
                .getFieldErrors()
                .stream()
                .map(ApiExceptionHandler::toFieldErrorDetail)
                .toList();

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("error", "bad_request");
        body.put("message", "Validation failed");
        body.put("details", details);
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, Object>> illegalArgument(IllegalArgumentException ex) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of(
                "error", "bad_request",
                "message", ex.getMessage()
        ));
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<Map<String, Object>> constraintViolation(ConstraintViolationException ex) {
        List<Map<String, Object>> details = ex.getConstraintViolations()
                .stream()
                .map(ApiExceptionHandler::toConstraintViolationDetail)
                .toList();

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("error", "bad_request");
        body.put("message", "Validation failed");
        body.put("details", details);
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
    }

    @ExceptionHandler(HandlerMethodValidationException.class)
    public ResponseEntity<Map<String, Object>> handlerMethodValidation(HandlerMethodValidationException ex) {
        List<Map<String, Object>> details = ex.getAllValidationResults()
                .stream()
                .flatMap(r -> r.getResolvableErrors().stream())
                .map(err -> Map.<String, Object>of(
                        "field", "",
                        "message", err.getDefaultMessage() == null ? "Invalid value" : err.getDefaultMessage()
                ))
                .toList();

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("error", "bad_request");
        body.put("message", "Validation failed");
        body.put("details", details);
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
    }

    @ExceptionHandler(IllegalStateException.class)
    public ResponseEntity<Map<String, Object>> unauthorized(IllegalStateException ex) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of(
                "error", "unauthorized",
                "message", ex.getMessage()
        ));
    }

    private static Map<String, Object> toFieldErrorDetail(FieldError e) {
        return Map.of(
                "field", e.getField(),
                "message", e.getDefaultMessage() == null ? "Invalid value" : e.getDefaultMessage()
        );
    }

    private static Map<String, Object> toConstraintViolationDetail(ConstraintViolation<?> v) {
        String path = v.getPropertyPath() != null ? v.getPropertyPath().toString() : "";
        return Map.of(
                "field", path,
                "message", v.getMessage() == null ? "Invalid value" : v.getMessage()
        );
    }
}
