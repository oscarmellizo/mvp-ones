package com.ones.api.application.photos.ports;

import java.util.List;
import java.util.Optional;

import com.ones.api.domain.photos.Photo;

public interface PhotosRepository {

    Optional<Photo> findById(String photoId);

    Photo upsert(Photo photo);

    PageResult<Photo> listByEventId(String eventId, int limit, String nextToken);

    PageResult<Photo> listAll(int limit, String nextToken);

    long countByEventId(String eventId);

    void deleteById(String photoId);

    record PageResult<T>(List<T> items, String nextToken) {
    }
}
