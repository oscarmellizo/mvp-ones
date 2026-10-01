package com.ones.api.application.users.ports;

/** Operaciones administrativas sobre usuarios de Firebase Auth necesarias para migrar cuentas legadas. */
public interface FirebaseIdentityAdmin {

    boolean isConfigured();

    /** Borra el usuario de Firebase {@code newUid} e importa uno con uid = {@code legacy.userId()} vinculado a google.com. */
    void replaceWithLegacyGoogleUser(String newUid, LegacyGoogleUser legacy);

    record LegacyGoogleUser(String userId, String email, String displayName, String photoUrl) {
    }
}
