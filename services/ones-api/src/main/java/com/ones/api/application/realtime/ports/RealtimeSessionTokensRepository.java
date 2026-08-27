package com.ones.api.application.realtime.ports;

import java.util.Optional;

import com.ones.api.domain.realtime.RealtimeSessionToken;

public interface RealtimeSessionTokensRepository {
    RealtimeSessionToken upsert(RealtimeSessionToken t);
    Optional<RealtimeSessionToken> findByToken(String token);
    void deleteByToken(String token);
}
