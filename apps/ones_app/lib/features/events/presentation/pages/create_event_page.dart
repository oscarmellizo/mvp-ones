import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/i18n/translations_service.dart';
import '../../../../core/utils/datetime_formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/ones_typography.dart';
import '../../../../core/ui/widgets/ones_text_form_field.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../event_covers_controller.dart';
import '../events_controller.dart';
import '../widgets/create_event_form_widgets.dart';
import '../widgets/create_event_cover_widgets.dart';
import '../widgets/create_event_datetime_widgets.dart';
import '../widgets/create_event_invite_widgets.dart';
import '../widgets/frame_picker_sheet.dart';
import '../../../tutorial/presentation/tutorial_keys.dart';
import '../../../tutorial/presentation/tutorial_controller.dart';

class CreateEventPage extends StatefulWidget {
  static const routeName = '/events/create';

  final String? initialTitle;
  final String? initialEventType;
  final String? initialLocation;
  final DateTime? initialStartDate;
  final TimeOfDay? initialStartTime;
  final DateTime? initialEndDate;
  final TimeOfDay? initialEndTime;
  final List<String>? initialFrameIds;

  const CreateEventPage({
    super.key,
    this.initialTitle,
    this.initialEventType,
    this.initialLocation,
    this.initialStartDate,
    this.initialStartTime,
    this.initialEndDate,
    this.initialEndTime,
    this.initialFrameIds,
  });

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _objectiveController = TextEditingController();
  final _locationController = TextEditingController();
  final _inviteEmailController = TextEditingController();

  String? _lastLanguage;

  static const Set<String> _createEventRequiredKeys = {
    'create_event.action_create',
    'create_event.allow_guest_invites',
    'create_event.cover_cancel',
    'create_event.cover_generate_ai',
    'create_event.cover_generate_helper',
    'create_event.cover_placeholder_title',
    'create_event.cover_regenerate',
    'create_event.cover_use',
    'create_event.creating',
    'create_event.cta_create',
    'create_event.date_label',
    'create_event.date_time_select_start_end',
    'create_event.ends',
    'create_event.error_complete_required_fields',
    'create_event.error_generate_cover_failed',
    'create_event.error_min_duration',
    'create_event.error_objective_required',
    'create_event.error_select_start_end',
    'create_event.error_session_expired',
    'create_event.field_event_name',
    'create_event.field_location',
    'create_event.field_objective',
    'create_event.frames_many',
    'create_event.frames_none',
    'create_event.frames_one',
    'create_event.hint_event_name',
    'create_event.hint_location_optional',
    'create_event.hint_objective',
    'create_event.invite_button',
    'create_event.invite_error_already_invited',
    'create_event.invite_error_cannot_invite_self',
    'create_event.invite_error_enter_email',
    'create_event.invite_error_invalid_email',
    'create_event.invite_hint',
    'create_event.invite_none',
    'create_event.invite_success_many',
    'create_event.invite_success_many_skipped_self',
    'create_event.invite_success_one',
    'create_event.invite_success_one_skipped_self',
    'create_event.invite_title',
    'create_event.invited_label',
    'create_event.location_tbd',
    'create_event.placeholder_time',
    'create_event.quick_evening',
    'create_event.quick_now',
    'create_event.quick_plus_30m',
    'create_event.quick_this_weekend',
    'create_event.quick_today',
    'create_event.quick_tomorrow',
    'create_event.section_basics',
    'create_event.section_cover',
    'create_event.section_frames',
    'create_event.section_guests',
    'create_event.section_when',
    'create_event.section_where_optional',
    'create_event.select_frames',
    'create_event.starts',
    'create_event.time_label',
    'create_event.title',
    'create_event.validation_objective_required',
    'create_event.validation_required',
  };

  static const double _ctaHeight = 56;
  static const double _ctaBottomGap = 16;
  static const Duration _minEventDuration = Duration(minutes: 15);

  final List<CreateEventInvitee> _invitees = [];
  String? _inviteError;

  String? _dateTimeError;

  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;

  String? _coverReservationId;

  bool _allowGuestInvites = true;

  List<String> _frameIds = const [];

  @override
  void initState() {
    super.initState();

    _lastLanguage = context.read<TranslationsService>().getCurrentLanguage();

    _nameController.addListener(_onFormChanged);
    _objectiveController.addListener(_onFormChanged);
    _locationController.addListener(_onFormChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TranslationsService>().ensurePageTranslations(
            page: 'create_event',
            requiredKeys: _createEventRequiredKeys,
          );
      context.read<EventCoversController>().clear();
      setState(() {
        _coverReservationId = null;
      });
    });

    if (widget.initialTitle != null && widget.initialTitle!.trim().isNotEmpty) {
      _nameController.text = widget.initialTitle!.trim();
    }

    if (widget.initialLocation != null &&
        widget.initialLocation!.trim().isNotEmpty) {
      _locationController.text = widget.initialLocation!.trim();
    }

    _startDate = widget.initialStartDate ?? _startDate;
    _startTime = widget.initialStartTime ?? _startTime;
    _endDate = widget.initialEndDate ?? _endDate;
    _endTime = widget.initialEndTime ?? _endTime;

    _frameIds = List<String>.from(widget.initialFrameIds ?? const <String>[]);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFormChanged);
    _objectiveController.removeListener(_onFormChanged);
    _locationController.removeListener(_onFormChanged);
    _nameController.dispose();
    _objectiveController.dispose();
    _locationController.dispose();
    _inviteEmailController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    if (!mounted) return;
    setState(() {});
  }

  DateTime? _combineLocal(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  String _dateTimeSummary(BuildContext context) {
    final t = context.read<TranslationsService>();
    final start = _combineLocal(_startDate, _startTime);
    final end = _combineLocal(_endDate, _endTime);
    if (start == null || end == null) {
      return t.translate('create_event.date_time_select_start_end');
    }
    final duration = end.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final hh = hours > 0 ? '${hours}h ' : '';
    final mm = '${minutes}m';
    final s =
        '${formatShortMonthDay(start)} • ${TimeOfDay.fromDateTime(start).format(context)}';
    final e =
        '${formatShortMonthDay(end)} • ${TimeOfDay.fromDateTime(end).format(context)}';
    return '$s → $e  ($hh$mm)';
  }

  bool get _canGenerateCover {
    return _nameController.text.trim().isNotEmpty &&
        _objectiveController.text.trim().isNotEmpty;
  }

  bool get _isFormReady {
    if (!_nameController.text.trim().isNotEmpty) return false;
    if (!_objectiveController.text.trim().isNotEmpty) return false;
    final start = _combineLocal(_startDate, _startTime);
    final end = _combineLocal(_endDate, _endTime);
    if (start == null || end == null) return false;
    if (end.isBefore(start.add(_minEventDuration))) return false;
    return true;
  }

  String _resolveLocation() {
    final value = _locationController.text.trim();
    if (value.isNotEmpty) return value;
    return context
        .read<TranslationsService>()
        .translate('create_event.location_tbd');
  }

  void _ensureEndDefaults() {
    final start = _combineLocal(_startDate, _startTime);
    if (start == null) return;
    if (_endDate != null && _endTime != null) return;

    final suggested = start.add(const Duration(hours: 2));
    _endDate = DateTime(suggested.year, suggested.month, suggested.day);
    _endTime = TimeOfDay(hour: suggested.hour, minute: suggested.minute);
  }

  void _validateDateTimes({bool showErrors = false}) {
    final t = context.read<TranslationsService>();
    final start = _combineLocal(_startDate, _startTime);
    final end = _combineLocal(_endDate, _endTime);

    String? error;
    if (start != null &&
        end != null &&
        end.isBefore(start.add(_minEventDuration))) {
      error = t.translate('create_event.error_min_duration');
    }

    setState(() {
      _dateTimeError = error;
    });

    if (showErrors && error != null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
  }

  ThemeData _pickerTheme(BuildContext context) {
    final base = Theme.of(context);
    const pickerFontFamily = 'Arial';
    final pickerTextTheme = base.textTheme
        .copyWith(
          displayLarge: base.textTheme.displayLarge?.copyWith(
            fontFamily: pickerFontFamily,
            fontFamilyFallback: OnesTypography.bodyFallbacks,
            letterSpacing: 0,
            height: 1.0,
          ),
          displayMedium: base.textTheme.displayMedium?.copyWith(
            fontFamily: pickerFontFamily,
            fontFamilyFallback: OnesTypography.bodyFallbacks,
            letterSpacing: 0,
            height: 1.0,
          ),
          displaySmall: base.textTheme.displaySmall?.copyWith(
            fontFamily: pickerFontFamily,
            fontFamilyFallback: OnesTypography.bodyFallbacks,
            letterSpacing: 0,
            height: 1.0,
          ),
          headlineLarge: base.textTheme.headlineLarge?.copyWith(
            fontFamily: pickerFontFamily,
            fontFamilyFallback: OnesTypography.bodyFallbacks,
            letterSpacing: 0,
            height: 1.0,
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontFamily: pickerFontFamily,
            fontFamilyFallback: OnesTypography.bodyFallbacks,
            letterSpacing: 0,
            height: 1.0,
          ),
        )
        .apply(
          bodyColor: OnesColors.black,
          displayColor: OnesColors.black,
        );
    final scheme = base.colorScheme.copyWith(
      primary: OnesColors.purpleMid,
      secondary: OnesColors.purpleMid,
      surface: OnesColors.white,
      onPrimary: OnesColors.white,
      onSecondary: OnesColors.white,
      onSurface: OnesColors.black,
      onSurfaceVariant: OnesColors.black,
    );

    return base.copyWith(
      colorScheme: scheme,
      dialogBackgroundColor: OnesColors.white,
      textTheme: pickerTextTheme,
      datePickerTheme: base.datePickerTheme.copyWith(
        headerHeadlineStyle: pickerTextTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: OnesColors.purpleMid,
        ),
      ),
      timePickerTheme: base.timePickerTheme.copyWith(
        dialTextColor: OnesColors.black,
        hourMinuteTextStyle: pickerTextTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        helpTextStyle: pickerTextTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        hourMinuteTextColor: OnesColors.black,
        dayPeriodTextColor: OnesColors.black,
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) => Theme(
        data: _pickerTheme(context),
        child: child!,
      ),
    );
    if (!mounted || pickedDate == null) return;

    setState(() {
      _startDate = pickedDate;
      _ensureEndDefaults();
    });
    _validateDateTimes();
  }

  Future<void> _pickStartTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: _pickerTheme(context),
        child: child!,
      ),
    );
    if (!mounted || pickedTime == null) return;

    setState(() {
      _startTime = pickedTime;
      _ensureEndDefaults();
    });
    _validateDateTimes();
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final initialEnd = _combineLocal(_endDate, _endTime);
    final initialDate =
        initialEnd ?? _combineLocal(_startDate, _startTime) ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate:
          DateTime(initialDate.year, initialDate.month, initialDate.day),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) => Theme(
        data: _pickerTheme(context),
        child: child!,
      ),
    );
    if (!mounted || pickedDate == null) return;

    setState(() {
      _endDate = pickedDate;
    });
    _validateDateTimes();
  }

  Future<void> _pickEndTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _endTime ?? _startTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: _pickerTheme(context),
        child: child!,
      ),
    );
    if (!mounted || pickedTime == null) return;

    setState(() {
      _endTime = pickedTime;
    });
    _validateDateTimes();
  }

  void _applyQuickStartDate(DateTime date) {
    setState(() {
      _startDate = DateTime(date.year, date.month, date.day);
      _ensureEndDefaults();
    });
    _validateDateTimes();
  }

  void _applyQuickStartTime(TimeOfDay time) {
    setState(() {
      _startTime = time;
      _ensureEndDefaults();
    });
    _validateDateTimes();
  }

  DateTime _nextWeekendStart() {
    final now = DateTime.now();
    final weekday = now.weekday; // Mon=1..Sun=7
    final daysUntilSat = (6 - weekday) % 7;
    final sat = now.add(Duration(days: daysUntilSat));
    return DateTime(sat.year, sat.month, sat.day);
  }

  TimeOfDay _roundedNowTime() {
    final now = DateTime.now();
    final minute = now.minute;
    final rounded = ((minute + 4) / 5).floor() * 5;
    final carry = rounded >= 60;
    final h = carry ? (now.hour + 1) % 24 : now.hour;
    final m = carry ? 0 : rounded;
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> _addInvitee() async {
    final t = context.read<TranslationsService>();
    final raw = _inviteEmailController.text;
    final parts = raw
        .split(RegExp(r'[\s,;]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) {
      setState(() {
        _inviteError = t.translate('create_event.invite_error_enter_email');
      });
      return;
    }

    final candidates =
        parts.map((e) => e.toLowerCase()).toList(growable: false);
    final invalid =
        candidates.where((e) => !looksLikeEmail(e)).toList(growable: false);
    if (invalid.isNotEmpty) {
      setState(() {
        _inviteError = t.translate('create_event.invite_error_invalid_email');
      });
      return;
    }

    final existing = _invitees.map((i) => i.email.toLowerCase()).toSet();
    final auth = context.read<AuthController>();
    final meEmail = auth.user?.email?.trim().toLowerCase();

    final toAdd = <String>[];
    bool removedSelf = false;
    for (final c in candidates) {
      if (existing.contains(c)) continue;
      if (toAdd.contains(c)) continue;
      if (meEmail != null && meEmail.isNotEmpty && c == meEmail) {
        removedSelf = true;
        continue;
      }
      toAdd.add(c);
    }

    if (toAdd.isEmpty) {
      setState(() {
        _inviteError = removedSelf
            ? t.translate('create_event.invite_error_cannot_invite_self')
            : t.translate('create_event.invite_error_already_invited');
      });
      return;
    }

    final newInvitees = <CreateEventInvitee>[];
    for (final email in toAdd) {
      String displayName = email;
      try {
        final lookup = await auth.lookupUserByEmail(email);
        final pn = lookup?.preferredName?.trim();
        if (pn != null && pn.isNotEmpty) {
          displayName = pn;
        }
      } catch (_) {
        // ignore lookup errors and fall back to email
      }
      newInvitees.add(CreateEventInvitee(name: displayName, email: email));
    }

    if (!mounted) return;
    setState(() {
      _invitees.insertAll(0, newInvitees);
      _inviteError = null;
      _inviteEmailController.clear();
      FocusScope.of(context).unfocus();
    });

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            () {
              final count = newInvitees.length;
              if (removedSelf) {
                final template = count == 1
                    ? t.translate(
                        'create_event.invite_success_one_skipped_self')
                    : t.translate(
                        'create_event.invite_success_many_skipped_self',
                      );
                return template.replaceAll('{count}', count.toString());
              }

              final template = count == 1
                  ? t.translate('create_event.invite_success_one')
                  : t.translate('create_event.invite_success_many');
              return template.replaceAll('{count}', count.toString());
            }(),
          ),
        ),
      );
  }

  void _removeInvitee(CreateEventInvitee invitee) {
    setState(() {
      _invitees.removeWhere((i) => i.email == invitee.email);
    });
  }

  Future<void> _pickFrames(BuildContext context) async {
    if (!mounted) return;
    final selected = await FramePickerSheet.open(
      context,
      initialSelectedFrameIds: _frameIds,
    );
    if (!mounted || selected == null) return;
    setState(() {
      _frameIds = List<String>.unmodifiable(selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EventsController>();
    final coversController = context.watch<EventCoversController>();
    final t = context.watch<TranslationsService>();

    final lang = t.getCurrentLanguage();
    if (_lastLanguage != lang) {
      _lastLanguage = lang;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<TranslationsService>().ensurePageTranslations(
              page: 'create_event',
              requiredKeys: _createEventRequiredKeys,
            );
      });
    }

    _coverReservationId = coversController.reservationId;

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isKeyboardOpen = bottomInset > 0;

    return Scaffold(
      backgroundColor: OnesColors.background,
      appBar: AppBar(
        backgroundColor: OnesColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: OnesColors.purpleDeep),
          onPressed:
              controller.loading ? null : () => Navigator.of(context).pop(),
        ),
        title: Text(
          t.translate('create_event.title'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: OnesColors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            key: TutorialKeys.createHelpIcon,
            icon: const Icon(Icons.help_outline, color: OnesColors.purpleDeep),
            onPressed: () => TutorialController.instance.start(context),
          ),
          TextButton(
            onPressed: controller.loading ? null : () => _submit(context),
            child: Text(
              t.translate('create_event.action_create'),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: OnesColors.purpleDeep,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 10, 16, isKeyboardOpen ? 16 : 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CreateEventFormSection(
                  title: t.translate('create_event.section_basics'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CreateEventFieldLabel(
                        t.translate('create_event.field_event_name'),
                      ),
                      const SizedBox(height: 8),
                      OnesTextFormField(
                        key: TutorialKeys.createTitleField,
                        controller: _nameController,
                        hintText: t.translate('create_event.hint_event_name'),
                        suffixIcon: const Icon(Icons.edit_outlined),
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? t.translate('create_event.validation_required')
                            : null,
                      ),
                      const SizedBox(height: 16),
                      CreateEventFieldLabel(
                        t.translate('create_event.field_objective'),
                      ),
                      const SizedBox(height: 8),
                      OnesTextFormField(
                        controller: _objectiveController,
                        hintText: t.translate('create_event.hint_objective'),
                        prefixIcon: const Icon(
                          Icons.flag,
                          color: OnesColors.purpleDeep,
                        ),
                        keyboardType: TextInputType.multiline,
                        minLines: 3,
                        maxLines: 6,
                        textInputAction: TextInputAction.newline,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) {
                            return t.translate(
                              'create_event.validation_objective_required',
                            );
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                CreateEventFormSection(
                  title: t.translate('create_event.section_when'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _dateTimeSummary(context),
                        style: TextStyle(
                          color: OnesColors.black.withOpacity(0.7),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionChip(
                            label:
                                Text(t.translate('create_event.quick_today')),
                            onPressed: () =>
                                _applyQuickStartDate(DateTime.now()),
                          ),
                          ActionChip(
                            label: Text(
                                t.translate('create_event.quick_tomorrow')),
                            onPressed: () => _applyQuickStartDate(
                                DateTime.now().add(const Duration(days: 1))),
                          ),
                          ActionChip(
                            label: Text(
                                t.translate('create_event.quick_this_weekend')),
                            onPressed: () =>
                                _applyQuickStartDate(_nextWeekendStart()),
                          ),
                          ActionChip(
                            label: Text(t.translate('create_event.quick_now')),
                            onPressed: () =>
                                _applyQuickStartTime(_roundedNowTime()),
                          ),
                          ActionChip(
                            label: Text(
                                t.translate('create_event.quick_plus_30m')),
                            onPressed: () {
                              final base = _combineLocal(
                                      _startDate ?? DateTime.now(),
                                      _startTime ?? _roundedNowTime()) ??
                                  DateTime.now();
                              final next =
                                  base.add(const Duration(minutes: 30));
                              _applyQuickStartDate(next);
                              _applyQuickStartTime(
                                  TimeOfDay.fromDateTime(next));
                            },
                          ),
                          ActionChip(
                            label:
                                Text(t.translate('create_event.quick_evening')),
                            onPressed: () => _applyQuickStartTime(
                                const TimeOfDay(hour: 19, minute: 0)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CreateEventDateTimeCard(
                        key: TutorialKeys.createWhenCard,
                        startDate: _startDate,
                        startTime: _startTime,
                        endDate: _endDate,
                        endTime: _endTime,
                        errorText: _dateTimeError,
                        onPickStartDate: _pickStartDate,
                        onPickStartTime: _pickStartTime,
                        onPickEndDate: _pickEndDate,
                        onPickEndTime: _pickEndTime,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                CreateEventFormSection(
                  title: t.translate('create_event.section_cover'),
                  child: CreateEventCoverPicker(
                    imageUrl: coversController.preview?.previewUrl,
                    loading: coversController.loading,
                    accepted: coversController.reservationId != null,
                    errorText: coversController.error?.toString(),
                    showGenerateHelper: !_canGenerateCover,
                    onGenerate: _canGenerateCover
                        ? () => _generateCover(context)
                        : null,
                    onAccept: coversController.preview == null
                        ? null
                        : () async {
                            await coversController.accept();
                          },
                    onCancel: coversController.preview == null
                        ? null
                        : () async {
                            await coversController.cancel();
                          },
                  ),
                ),
                const SizedBox(height: 14),
                CreateEventFormSection(
                  title: t.translate('create_event.section_where_optional'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CreateEventFieldLabel(
                        t.translate('create_event.field_location'),
                      ),
                      const SizedBox(height: 8),
                      OnesTextFormField(
                        controller: _locationController,
                        hintText:
                            t.translate('create_event.hint_location_optional'),
                        prefixIcon: const Icon(
                          Icons.location_on,
                          color: OnesColors.purpleDeep,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                CreateEventFormSection(
                  title: t.translate('create_event.section_guests'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            t.translate('create_event.allow_guest_invites'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: OnesColors.black,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Switch(
                            value: _allowGuestInvites,
                            onChanged: (value) {
                              setState(() {
                                _allowGuestInvites = value;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CreateEventInviteGuestsCard(
                        emailController: _inviteEmailController,
                        inviteError: _inviteError,
                        invitees: _invitees,
                        onInvite: _addInvitee,
                        onRemove: _removeInvitee,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                CreateEventFormSection(
                  title: t.translate('create_event.section_frames'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        () {
                          if (_frameIds.isEmpty) {
                            return t.translate('create_event.frames_none');
                          }
                          final count = _frameIds.length;
                          final template = count == 1
                              ? t.translate('create_event.frames_one')
                              : t.translate('create_event.frames_many');
                          return template.replaceAll(
                            '{count}',
                            count.toString(),
                          );
                        }(),
                        style: TextStyle(
                          color: OnesColors.black.withOpacity(0.7),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: controller.loading
                              ? null
                              : () => _pickFrames(context),
                          child:
                              Text(t.translate('create_event.select_frames')),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isKeyboardOpen) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: _ctaHeight,
                    child: FilledButton(
                      key: TutorialKeys.createCtaCreate,
                      style: FilledButton.styleFrom(
                        backgroundColor: OnesColors.purpleMid,
                        disabledBackgroundColor:
                            OnesColors.purpleMid.withOpacity(0.5),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      onPressed: (controller.loading || !_isFormReady)
                          ? null
                          : () => _submit(context),
                      child: controller.loading
                          ? Text(t.translate('create_event.creating'))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  t.translate('create_event.cta_create'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Icon(Icons.arrow_forward),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: _ctaBottomGap),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final controller = context.read<EventsController>();
    final auth = context.read<AuthController>();
    final t = context.read<TranslationsService>();
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
                t.translate('create_event.error_complete_required_fields')),
          ),
        );
      return;
    }
    final objective = _objectiveController.text.trim();
    if (objective.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(t.translate('create_event.error_objective_required')),
          ),
        );
      return;
    }

    _validateDateTimes(showErrors: false);

    final startLocal = _combineLocal(_startDate, _startTime);
    final endLocal = _combineLocal(_endDate, _endTime);

    if (startLocal == null || endLocal == null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(t.translate('create_event.error_select_start_end')),
          ),
        );
      return;
    }

    if (endLocal.isBefore(startLocal.add(_minEventDuration))) {
      _validateDateTimes(showErrors: true);
      return;
    }

    final startAt = startLocal.toUtc();
    final endAt = endLocal.toUtc();

    try {
      await controller.createNew(
        _nameController.text.trim(),
        objective,
        _resolveLocation(),
        startAt,
        endAt,
        _coverReservationId,
        _invitees.map((i) => i.email).toList(growable: false),
        _allowGuestInvites,
        _frameIds,
      );
      if (context.mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(t.translate('create_event.error_session_expired')),
            ),
          );
        await auth.logout();
        return;
      }
      rethrow;
    }
  }

  Future<void> _generateCover(
    BuildContext context,
  ) async {
    final covers = context.read<EventCoversController>();
    final auth = context.read<AuthController>();
    final t = context.read<TranslationsService>();

    final eventName = _nameController.text.trim();
    final objective = _objectiveController.text.trim();
    if (eventName.isEmpty) return;
    if (objective.isEmpty) return;
    final location = _locationController.text.trim();
    final coverLocation =
        location.isEmpty ? t.translate('create_event.location_tbd') : location;

    try {
      await covers.generate(
        eventName: eventName,
        objective: objective,
        location: coverLocation,
        size: null,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(t.translate('create_event.error_session_expired')),
            ),
          );
        await auth.logout();
        return;
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content:
                Text(t.translate('create_event.error_generate_cover_failed')),
          ),
        );
      rethrow;
    }
  }
}
