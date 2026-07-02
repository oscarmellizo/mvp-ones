package com.ones.api.application.photos.ports;

import java.time.Instant;
import java.util.Set;

public interface PhotoLikesRepository {

    Set<String> likedPhotoIds(String userId, Set<String> photoIds);

    void like(String eventId, String photoId, String userId, Instant createdAt);

    void unlike(String photoId, String userId);

    void deleteAllByPhotoId(String photoId);
}
