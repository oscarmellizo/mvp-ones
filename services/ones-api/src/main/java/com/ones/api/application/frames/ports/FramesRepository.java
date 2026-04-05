package com.ones.api.application.frames.ports;

import java.util.List;
import java.util.Optional;

import com.ones.api.domain.frames.Frame;

public interface FramesRepository {

    record ListResult(List<Frame> items, String nextToken) {
    }

    Optional<Frame> findById(String frameId);

    Frame upsert(Frame frame);

    void deleteById(String frameId);

    ListResult list(String status, int limit, String nextToken);
}
