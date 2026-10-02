package com.ones.api.application.users.ports;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import com.ones.api.domain.users.User;

public interface UsersRepository {

    Optional<User> findById(String userId);

    Optional<User> findByEmail(String email);

    User upsert(User user);

    /**
     * Escribe la fila completa solo si el estado guardado sigue siendo {@code expectedStatus}
     * ({@code null} = la fila existe pero no tiene estado). Devuelve false si otro proceso lo cambió.
     */
    boolean upsertIfStatus(User user, String expectedStatus);

    /**
     * Escribe la fila completa solo si sigue en CLOSING con el mismo {@code closingAt} (el reclamo de esta corrida;
     * {@code null} = CLOSING sin closingAt). Devuelve false si otra corrida la reclamó o cambió.
     */
    boolean upsertIfClosing(User user, Instant expectedClosingAt);

    void deleteById(String userId);

    List<User> findByStatusIn(Set<String> statuses);
}
