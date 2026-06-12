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

    private static final Set<String> DISCOVER_KEYS = Set.of(
            "discover.search_templates",
            "discover.failed_load_templates",
            "discover.no_templates_found_for",
            "discover.public",
            "discover.status_label",
            "discover.frames_label",
            "discover.use_template_question",
            "discover.not_now",
            "discover.use_template"
    );

    private static final Set<String> GALLERIES_KEYS = Set.of(
            "galleries.search_past_events",
            "galleries.filter_all",
            "galleries.filter_last_7_days",
            "galleries.filter_last_30_days",
            "galleries.filter_this_year",
            "galleries.no_past_events_yet",
            "galleries.no_results_for",
            "galleries.today",
            "galleries.yesterday"
    );

    private static final Set<String> PROFILE_KEYS = Set.of(
            "profile.guest",
            "profile.no_authenticated_user",
            "profile.account",
            "profile.first_name",
            "profile.last_name",
            "profile.email",
            "profile.preferences",
            "profile.preferred_name_question",
            "profile.preferred_name_label",
            "profile.preferred_name_description",
            "profile.language",
            "profile.language_es",
            "profile.language_en",
            "profile.language_pt",
            "profile.error_preferred_name_required",
            "profile.success_preferences_saved",
            "profile.error_save_failed",
            "profile.save_preferences",
            "profile.admin",
            "profile.open_admin",
            "profile.signing_out",
            "profile.logout"
    );

    private static final Set<String> CREATE_EVENT_KEYS = Set.of(
            "create_event.action_create",
            "create_event.allow_guest_invites",
            "create_event.cover_cancel",
            "create_event.cover_generate_ai",
            "create_event.cover_generate_helper",
            "create_event.cover_placeholder_title",
            "create_event.cover_regenerate",
            "create_event.cover_use",
            "create_event.creating",
            "create_event.cta_create",
            "create_event.date_label",
            "create_event.date_time_select_start_end",
            "create_event.ends",
            "create_event.error_complete_required_fields",
            "create_event.error_generate_cover_failed",
            "create_event.error_min_duration",
            "create_event.error_objective_required",
            "create_event.error_select_start_end",
            "create_event.error_session_expired",
            "create_event.field_event_name",
            "create_event.field_location",
            "create_event.field_objective",
            "create_event.frames_many",
            "create_event.frames_none",
            "create_event.frames_one",
            "create_event.hint_event_name",
            "create_event.hint_location_optional",
            "create_event.hint_objective",
            "create_event.invite_button",
            "create_event.invite_error_already_invited",
            "create_event.invite_error_cannot_invite_self",
            "create_event.invite_error_enter_email",
            "create_event.invite_error_invalid_email",
            "create_event.invite_hint",
            "create_event.invite_none",
            "create_event.invite_success_many",
            "create_event.invite_success_many_skipped_self",
            "create_event.invite_success_one",
            "create_event.invite_success_one_skipped_self",
            "create_event.invite_title",
            "create_event.invited_label",
            "create_event.location_tbd",
            "create_event.placeholder_time",
            "create_event.quick_evening",
            "create_event.quick_now",
            "create_event.quick_plus_30m",
            "create_event.quick_this_weekend",
            "create_event.quick_today",
            "create_event.quick_tomorrow",
            "create_event.section_basics",
            "create_event.section_cover",
            "create_event.section_frames",
            "create_event.section_guests",
            "create_event.section_when",
            "create_event.section_where_optional",
            "create_event.select_frames",
            "create_event.starts",
            "create_event.time_label",
            "create_event.title",
            "create_event.validation_objective_required",
            "create_event.validation_required"
    );

    private static final Set<String> EDIT_EVENT_KEYS = Set.of(
            "edit_event.title",
            "edit_event.action_save",
            "edit_event.error_update_failed",
            "create_event.date_time_select_start_end",
            "create_event.error_select_start_end",
            "create_event.error_min_duration",
            "create_event.error_complete_required_fields",
            "create_event.location_tbd",
            "create_event.field_event_name",
            "create_event.field_objective",
            "create_event.field_location",
            "create_event.validation_required",
            "create_event.starts",
            "create_event.ends",
            "create_event.date_label",
            "create_event.time_label",
            "create_event.placeholder_time",
            "create_event.cover_placeholder_title",
            "create_event.cover_generate_helper",
            "create_event.cover_generate_ai",
            "create_event.cover_regenerate",
            "create_event.cover_use",
            "create_event.cover_cancel",
            "create_event.frames_none",
            "create_event.frames_one",
            "create_event.frames_many",
            "create_event.select_frames"
    );

    private static final Set<String> EVENT_DETAIL_KEYS = Set.of(
            "event_detail.no_event",
            "event_detail.tab_gallery",
            "event_detail.tab_details",
            "event_detail.no_photos",
            "event_detail.action_refresh",
            "event_detail.error_loading_gallery",
            "event_detail.action_retry",
            "event_detail.filter_all",
            "event_detail.filter_shared",
            "event_detail.filter_mine",
            "event_detail.guests",
            "event_detail.action_clear",
            "event_detail.action_apply",
            "event_detail.photo_processing",
            "event_detail.processing",
            "event_detail.shared",
            "event_detail.guest",
            "event_detail.action_cancel",
            "event_detail.error_mix_shared_private",
            "event_detail.photos_unshared",
            "event_detail.photos_shared",
            "event_detail.error_update_failed",
            "event_detail.action_unshare",
            "event_detail.action_share",
            "event_detail.section_event_details",
            "event_detail.action_edit_tooltip",
            "event_detail.field_event_name",
            "event_detail.field_location",
            "event_detail.field_starts",
            "event_detail.field_ends",
            "event_detail.field_description",
            "event_detail.section_frames",
            "event_detail.selected_frames",
            "event_detail.section_invite_guests",
            "event_detail.invite_by_link",
            "event_detail.link_disabled",
            "event_detail.copy_link",
            "event_detail.share_link",
            "event_detail.invite_link_copied",
            "event_detail.invite_link_update_failed",
            "event_detail.email_required_hint",
            "event_detail.action_invite",
            "event_detail.guests_title",
            "event_detail.error_enter_email",
            "event_detail.error_invalid_email",
            "event_detail.error_invite_failed",
            "event_detail.error_load_guests",
            "event_detail.no_guests_yet",
            "event_detail.guest_status_owner",
            "event_detail.guest_status_accepted",
            "event_detail.guest_status_rejected",
            "event_detail.guest_status_invited"
    );

    private static final Set<String> PHOTO_CAPTURE_KEYS = Set.of(
            "photo_capture.error_web_not_supported",
            "photo_capture.error_camera_not_initialized",
            "photo_capture.frames_loading",
            "photo_capture.frames_error",
            "photo_capture.error_capture_failed",
            "photo_capture.camera_error",
            "photo_capture.retry"
    );

    private static final Set<String> PHOTO_VIEWER_KEYS = Set.of(
            "photo_viewer.shared_by",
            "photo_viewer.photo_processing",
            "photo_viewer.error_loading_image",
            "photo_viewer.error_like_update_failed",
            "photo_viewer.error_share_failed"
    );

    public static Set<String> keysFor(TranslationsPageId pageId) {
        return switch (pageId) {
            case HOME -> HOME_KEYS;
            case DISCOVER -> DISCOVER_KEYS;
            case GALLERIES -> GALLERIES_KEYS;
            case PROFILE -> PROFILE_KEYS;
            case CREATE_EVENT -> CREATE_EVENT_KEYS;
            case EDIT_EVENT -> EDIT_EVENT_KEYS;
            case EVENT_DETAIL -> EVENT_DETAIL_KEYS;
            case PHOTO_CAPTURE -> PHOTO_CAPTURE_KEYS;
            case PHOTO_VIEWER -> PHOTO_VIEWER_KEYS;
            default -> Set.of();
        };
    }
}
