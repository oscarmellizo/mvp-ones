package com.ones.api.adapters.inbound.rest.internal;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.collections.CollectionPhotosService;
import com.ones.api.application.collections.CollectionService;

@RestController
@RequestMapping("/internal/collections/{collectionId}/deletion-complete")
public class InternalCollectionDeletionController {
    private final CollectionPhotosService photos;
    private final CollectionService collections;

    public InternalCollectionDeletionController(
            CollectionPhotosService photos,
            CollectionService collections
    ) {
        this.photos = photos;
        this.collections = collections;
    }

    @PostMapping
    public ResponseEntity<Void> complete(@PathVariable("collectionId") String collectionId) {
        photos.purgeMetadata(collectionId);
        collections.finalizeDeletion(collectionId);
        return ResponseEntity.noContent().build();
    }
}
