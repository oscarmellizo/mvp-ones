package com.ones.api.domain.collections;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Instant;
import org.junit.jupiter.api.Test;

class CollectionPolicyTest {
    @Test
    void privateCollectionsHaveNoMembershipOrQr() {
        assertFalse(CollectionPolicy.allowsMembers(CollectionType.PRIVATE));
        assertFalse(CollectionPolicy.allowsQrJoin(CollectionType.PRIVATE));
        assertEquals(0, CollectionPolicy.maxAdditionalMembers(CollectionType.PRIVATE));
    }

    @Test
    void coupleHasExactlyOneAdditionalMemberSlot() {
        assertTrue(CollectionPolicy.allowsMembers(CollectionType.COUPLE));
        assertEquals(1, CollectionPolicy.maxAdditionalMembers(CollectionType.COUPLE));
    }

    @Test
    void sharedTypesHaveNoProductMemberLimit() {
        for (CollectionType type : new CollectionType[] {
                CollectionType.FAMILY, CollectionType.FRIENDS,
                CollectionType.PROJECTS, CollectionType.OTHER
        }) {
            assertTrue(CollectionPolicy.allowsMembers(type));
            assertEquals(Integer.MAX_VALUE, CollectionPolicy.maxAdditionalMembers(type));
        }
    }

    @Test
    void lifeCollectionCannotBeDeletedEvenByOwner() {
        Instant now = Instant.parse("2026-01-01T00:00:00Z");
        Collection life = new Collection(
                "life-1", "user-1", "Línea de Vida Ana", null, CollectionType.PRIVATE,
                null, "LIFE", now, now, false, null, false, null
        );
        assertFalse(CollectionPolicy.canDelete(life, "user-1"));
    }

    @Test
    void onlyOwnerCanDeleteUserCreatedCollection() {
        Instant now = Instant.parse("2026-01-01T00:00:00Z");
        Collection collection = new Collection(
                "collection-1", "owner-1", "Viajes", null, CollectionType.FAMILY,
                null, null, now, now, false, null, false, null
        );
        assertTrue(CollectionPolicy.canDelete(collection, "owner-1"));
        assertFalse(CollectionPolicy.canDelete(collection, "member-1"));
    }
}
