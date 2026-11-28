package com.ones.api.application.users.ports;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import com.ones.api.domain.users.User;

public interface UsersRepository {

    Optional<User> findById(String userId);

    default List<User> findByIds(Set<String> userIds) {
        if (userIds == null || userIds.isEmpty()) return List.of();
        return userIds.stream()
                .filter(userId -> userId != null && !userId.isBlank())
                .map(String::trim)
                .distinct()
                .map(this::findById)
                .flatMap(Optional::stream)
                .toList();
    }

    Optional<User> findByEmail(String email);

    default Optional<String> findTimeZoneByEmail(String email) {
        return findByEmail(email).map(User::getTimeZone).filter(value -> value != null && !value.isBlank());
    }

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
