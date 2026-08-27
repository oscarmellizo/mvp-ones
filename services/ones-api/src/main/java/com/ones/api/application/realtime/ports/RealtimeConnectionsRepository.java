package com.ones.api.application.realtime.ports;

import java.util.List;

import com.ones.api.domain.realtime.RealtimeConnection;

public interface RealtimeConnectionsRepository {
    RealtimeConnection upsert(RealtimeConnection c);
    void deleteByConnectionId(String connectionId);
    List<RealtimeConnection> listByUserId(String userId, int limit);
}
