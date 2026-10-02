package com.ones.api.application.users.ports;

/** Operaciones administrativas sobre usuarios de Firebase Auth necesarias para migrar cuentas legadas. */
public interface FirebaseIdentityAdmin {

    boolean isConfigured();

    /** Borra el usuario de Firebase {@code newUid} e importa uno con uid = {@code legacy.userId()} vinculado a google.com. */
    void replaceWithLegacyGoogleUser(String newUid, LegacyGoogleUser legacy);

    /** Borra el usuario de Firebase; idempotente (si no existe, no falla). Lanza IllegalStateException si no está configurado. */
    void deleteUser(String uid);

    record LegacyGoogleUser(String userId, String email, String displayName, String photoUrl) {
    }
}
