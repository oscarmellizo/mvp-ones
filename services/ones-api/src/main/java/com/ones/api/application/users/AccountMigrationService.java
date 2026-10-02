package com.ones.api.application.users;

import java.util.Optional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import com.ones.api.application.users.ports.FirebaseIdentityAdmin;
import com.ones.api.application.users.ports.FirebaseIdentityAdmin.LegacyGoogleUser;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

/**
 * Migra bajo demanda a usuarios de Google anteriores a Firebase: si Firebase les asignó un uid nuevo,
 * se reemplaza ese usuario por uno con uid = sub de Google (el userId que ya usan todas las tablas).
 * La identidad google.com del token la firma Firebase, lo que prueba que es la misma cuenta.
 */
@Service
public class AccountMigrationService {

    public enum Outcome { NONE, MIGRATED, NOT_CONFIGURED }

    private static final Logger log = LoggerFactory.getLogger(AccountMigrationService.class);

    private final UsersRepository usersRepository;
    private final FirebaseIdentityAdmin firebaseIdentityAdmin;

    public AccountMigrationService(UsersRepository usersRepository, FirebaseIdentityAdmin firebaseIdentityAdmin) {
        this.usersRepository = usersRepository;
        this.firebaseIdentityAdmin = firebaseIdentityAdmin;
    }

    public Outcome migrateIfLegacy(String uid, String googleSub) {
        if (googleSub == null || googleSub.isBlank() || googleSub.equals(uid)) {
            return Outcome.NONE;
        }
        if (usersRepository.findById(uid).isPresent()) {
            return Outcome.NONE;
        }
        Optional<User> legacy = usersRepository.findById(googleSub);
        if (legacy.isEmpty() || User.STATUS_DELETED.equalsIgnoreCase(legacy.get().getStatus())) {
            // Una lápida no es una cuenta migrable: el uid nuevo arranca como cuenta nueva.
            return Outcome.NONE;
        }
        if (!firebaseIdentityAdmin.isConfigured()) {
            log.error("[migration] usuario legado {} entró con uid {} pero la service account de Firebase no está configurada",
                    googleSub, uid);
            return Outcome.NOT_CONFIGURED;
        }

        User u = legacy.get();
        firebaseIdentityAdmin.replaceWithLegacyGoogleUser(uid,
                new LegacyGoogleUser(u.getUserId(), u.getEmail(), u.getName(), u.getPicture()));
        log.info("[migration] uid Firebase {} reemplazado por usuario legado {}", uid, googleSub);
        return Outcome.MIGRATED;
    }
}
