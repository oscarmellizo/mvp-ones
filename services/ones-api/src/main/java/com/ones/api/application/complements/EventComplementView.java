package com.ones.api.application.complements;

public record EventComplementView(
        String id,
        String displayName,
        String tabLabel,
        boolean enabled
) {
}
