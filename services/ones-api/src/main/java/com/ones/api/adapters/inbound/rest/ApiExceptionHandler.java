package com.ones.api.adapters.inbound.rest;

import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import com.ones.api.application.events.CoverPreviewNotFoundException;
import com.ones.api.application.events.CoverReservationExpiredException;
import com.ones.api.application.events.CoverReservationNotFoundException;
import com.ones.api.application.events.EventCoverNotFoundException;
import com.ones.api.application.events.EventForbiddenException;
import com.ones.api.application.events.EventNotFoundException;
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

    @ExceptionHandler(CoverReservationExpiredException.class)
    public ResponseEntity<Map<String, Object>> badRequest(CoverReservationExpiredException ex) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of(
                "error", "bad_request",
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

    @ExceptionHandler(IllegalStateException.class)
    public ResponseEntity<Map<String, Object>> unauthorized(IllegalStateException ex) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of(
                "error", "unauthorized",
                "message", ex.getMessage()
        ));
    }
}
