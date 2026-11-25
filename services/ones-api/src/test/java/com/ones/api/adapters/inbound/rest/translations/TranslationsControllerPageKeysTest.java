package com.ones.api.adapters.inbound.rest.translations;

import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import java.util.Set;

import org.junit.jupiter.api.Test;

class TranslationsControllerPageKeysTest {

    @Test
    void editEventPageIncludesTournamentComplementTranslations() {
        Set<String> editEventKeys =
                TranslationsPageKeys.keysFor(TranslationsPageId.EDIT_EVENT);

        assertTrue(editEventKeys.containsAll(List.of(
                "edit_event.complements_title",
                "edit_event.tournament_title",
                "edit_event.tournament_subtitle",
                "edit_event.tournament_already_enabled",
                "edit_event.complements_loading",
                "edit_event.complements_load_failed",
                "edit_event.complements_retry",
                "edit_event.tournament_enable_failed")));
    }
}
