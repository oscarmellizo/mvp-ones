package com.ones.api.domain.collections;

public final class CollectionPolicy {
    private CollectionPolicy() {}

    public static boolean allowsMembers(CollectionType type) {
        return type != CollectionType.PRIVATE;
    }

    public static int maxAdditionalMembers(CollectionType type) {
        return switch (type) {
            case PRIVATE -> 0;
            case COUPLE -> 1;
            case FAMILY, FRIENDS, PROJECTS, OTHER -> Integer.MAX_VALUE;
        };
    }

    public static boolean allowsQrJoin(CollectionType type) {
        return type != CollectionType.PRIVATE;
    }

    public static boolean canDelete(Collection collection, String requesterId) {
        return collection != null
                && !collection.isLifeCollection()
                && !collection.deleting()
                && collection.ownerId().equals(requesterId);
    }
}
