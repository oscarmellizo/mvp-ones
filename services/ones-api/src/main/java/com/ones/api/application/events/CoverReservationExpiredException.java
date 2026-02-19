package com.ones.api.application.events;

public class CoverReservationExpiredException extends RuntimeException {

    public CoverReservationExpiredException(String reservationId) {
        super("Cover reservation expired: " + reservationId);
    }
}
