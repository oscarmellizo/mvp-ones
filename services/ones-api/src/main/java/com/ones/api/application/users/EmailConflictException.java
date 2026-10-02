package com.ones.api.application.users;

/** El correo del token ya pertenece a otro usuario real (no stub) con distinto userId. */
public class EmailConflictException extends RuntimeException {

    public EmailConflictException() {
        super("El correo ya está asociado a otra cuenta");
    }
}
