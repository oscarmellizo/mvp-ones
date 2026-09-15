package com.ones.api.application.users;

/** Resultado de evaluar si una cuenta puede usar el API. */
public enum AccountAccess {
    /** Cuenta activa (o aún no registrada). */
    ACTIVE,
    /** Desactivada por el usuario y todavía dentro de la ventana de reactivación. */
    DISABLED,
    /** Desactivada y fuera de la ventana de reactivación: pendiente de cierre definitivo. */
    CLOSED
}
