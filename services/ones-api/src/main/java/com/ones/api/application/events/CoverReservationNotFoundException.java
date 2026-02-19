package com.ones.api.application.events;

public class CoverReservationNotFoundException extends RuntimeException {

    public CoverReservationNotFoundException(String reservationId) {
        super("Cover reservation not found: " + reservationId);
    }
}
