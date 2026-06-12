package com.ones.api.adapters.inbound.rest.translations;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.translations.TranslationsManagementService;
import com.ones.api.domain.translations.Translation;

@RestController
@RequestMapping("/v1/translations")
public class TranslationsController {

    private final TranslationsManagementService service;

    public TranslationsController(TranslationsManagementService service) {
        this.service = service;
    }

    @GetMapping
    public List<Translation> list(
            @RequestParam("languageCode") String languageCode
    ) {
        return service.getAllTranslations(languageCode);
    }

    @GetMapping("/page")
    public TranslationsPageResponse page(
            @RequestParam("page") String page,
            @RequestParam("languageCode") String languageCode
    ) {
        final String lang = normalizeLanguage(languageCode);
        final TranslationsPageId pageId = TranslationsPageId.fromWire(page);
        final Set<String> keys = TranslationsPageKeys.keysFor(pageId);

        final Map<String, String> out = new LinkedHashMap<>();
        final List<Translation> all = service.getAllTranslations(lang);
        for (final Translation t : all) {
            if (t == null) continue;
            final String k = t.getTranslationKey();
            if (k == null || k.isBlank()) continue;
            if (!keys.contains(k)) continue;
            out.put(k, t.getValue());
        }

        return new TranslationsPageResponse(lang, pageId.wire(), out);
    }

    @GetMapping("/key")
    public Translation key(
            @RequestParam("translationKey") String translationKey,
            @RequestParam("languageCode") String languageCode
    ) {
        final String lang = normalizeLanguage(languageCode);
        return service.getTranslation(translationKey, lang);
    }

    private String normalizeLanguage(String languageCode) {
        if (languageCode == null || languageCode.isBlank()) {
            throw new IllegalArgumentException("languageCode is required");
        }
        return languageCode.trim().toLowerCase(Locale.ROOT);
    }
}

record TranslationsPageResponse(
        String languageCode,
        String page,
        Map<String, String> translations
) {
}

enum TranslationsPageId {
    HOME("home"),
    DISCOVER("discover"),
    GALLERIES("galleries"),
    PROFILE("profile"),
    CREATE_EVENT("create_event"),
    EDIT_EVENT("edit_event"),
    EVENT_DETAIL("event_detail"),
    PHOTO_CAPTURE("photo_capture"),
    PHOTO_VIEWER("photo_viewer"),
    INVITATION_LINK("invitation_link"),
    EVENT_INVITE_LINK("event_invite_link"),
    ADMIN_HOME("admin_home"),
    ADMIN_ADMINS("admin_admins"),
    ADMIN_FRAMES("admin_frames"),
    ADMIN_FRAME_EDIT("admin_frame_edit"),
    ADMIN_EVENT_TEMPLATES("admin_event_templates"),
    ADMIN_EVENT_TEMPLATE_EDIT("admin_event_template_edit"),
    ADMIN_TRANSLATIONS("admin_translations"),
    ADMIN_TRANSLATION_EDIT("admin_translation_edit");

    private final String wire;

    TranslationsPageId(String wire) {
        this.wire = wire;
    }

    public String wire() {
        return wire;
    }

    public static TranslationsPageId fromWire(String wire) {
        if (wire == null || wire.isBlank()) {
            throw new IllegalArgumentException("page is required");
        }
        final String normalized = wire.trim().toLowerCase(Locale.ROOT);
        for (final TranslationsPageId v : values()) {
            if (v.wire.equals(normalized)) {
                return v;
            }
        }
        throw new IllegalArgumentException("Unknown page: " + wire);
    }
}

final class TranslationsPageKeys {
    private TranslationsPageKeys() {
    }

    private static final Set<String> HOME_KEYS = Set.of(
            "nav.home",
            "nav.discover",
            "nav.galleries",
            "nav.profile",
            "home.search_events",
            "home.today",
            "home.next_events",
            "home.live_now",
            "home.no_upcoming_events",
            "common.error"
    );

    public static Set<String> keysFor(TranslationsPageId pageId) {
        return switch (pageId) {
            case HOME -> HOME_KEYS;
            default -> Set.of();
        };
    }
}
