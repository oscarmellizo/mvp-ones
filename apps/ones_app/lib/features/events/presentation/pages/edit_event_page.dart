import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/i18n/translations_service.dart';
import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/ones_typography.dart';
import '../../../../core/utils/datetime_formatters.dart';
import '../../adapters/api/event_complements_api_repository.dart';
import '../../domain/event.dart';
import '../event_covers_controller.dart';
import '../events_controller.dart';
import '../widgets/create_event_cover_widgets.dart';
import '../widgets/create_event_datetime_widgets.dart';
import '../widgets/create_event_form_widgets.dart';
import '../widgets/frame_picker_sheet.dart';

class EditEventResult {
  final bool saved;
  final bool tournamentEnabled;

  const EditEventResult({
    required this.saved,
    required this.tournamentEnabled,
  });
}

class EditEventPage extends StatefulWidget {
  final Event initial;

  const EditEventPage({super.key, required this.initial});

  @override
  State<EditEventPage> createState() => _EditEventPageState();
}

class _EditEventPageState extends State<EditEventPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _objectiveController = TextEditingController();
  final _locationController = TextEditingController();

  static const Duration _minEventDuration = Duration(minutes: 15);

  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;

  String? _dateTimeError;

  List<String> _frameIds = const [];

  bool _isLoadingComplements = true;
  bool _complementsLoadFailed = false;
  bool _tournamentEnabled = false;
  bool _tournamentSelected = false;
  bool _isSaving = false;

  String? _coverReservationId;

  String? _lastLanguage;

  static const Set<String> _editEventRequiredKeys = {
    'edit_event.title',
    'edit_event.action_save',
    'edit_event.error_update_failed',
    'edit_event.complements_title',
    'edit_event.tournament_title',
    'edit_event.tournament_subtitle',
    'edit_event.tournament_already_enabled',
    'edit_event.complements_loading',
    'edit_event.complements_load_failed',
    'edit_event.complements_retry',
    'edit_event.tournament_enable_failed',
    'create_event.date_time_select_start_end',
    'create_event.error_select_start_end',
    'create_event.error_min_duration',
    'create_event.error_complete_required_fields',
    'create_event.location_tbd',
    'create_event.field_event_name',
    'create_event.field_objective',
    'create_event.field_location',
    'create_event.validation_required',
    'create_event.starts',
    'create_event.ends',
    'create_event.date_label',
    'create_event.time_label',
    'create_event.placeholder_time',
    'create_event.cover_placeholder_title',
    'create_event.cover_generate_helper',
    'create_event.cover_generate_ai',
    'create_event.cover_regenerate',
    'create_event.cover_use',
    'create_event.cover_cancel',
    'create_event.frames_none',
    'create_event.frames_one',
    'create_event.frames_many',
    'create_event.select_frames',
  };

  @override
  void initState() {
    super.initState();

    _lastLanguage = context.read<TranslationsService>().getCurrentLanguage();

    final e = widget.initial;

    _nameController.text = e.title;
    _objectiveController.text = e.objective;
    _locationController.text = e.location;

    final start = e.startAt.toLocal();
    final end = e.endAt.toLocal();

    _startDate = DateTime(start.year, start.month, start.day);
    _startTime = TimeOfDay.fromDateTime(start);

    _endDate = DateTime(end.year, end.month, end.day);
    _endTime = TimeOfDay.fromDateTime(end);

    _frameIds = List<String>.from(e.frameIds);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TranslationsService>().ensurePageTranslations(
            page: 'edit_event',
            requiredKeys: _editEventRequiredKeys,
          );
      context.read<EventCoversController>().clear();
      setState(() {
        _coverReservationId = null;
      });
      _loadComplements();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _objectiveController.dispose();
    _locationController.dispose();
    super.dispose();
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

  void _validateDateTimes({bool showErrors = false}) {
    final t = context.read<TranslationsService>();
    final start = _combineLocal(_startDate, _startTime);
    final end = _combineLocal(_endDate, _endTime);

    String? error;
    if (start == null || end == null) {
      error = t.translate(
        'create_event.error_select_start_end',
        fallback: 'Please select start and end time.',
      );
    } else if (end.isBefore(start.add(_minEventDuration))) {
      error = t.translate(
        'create_event.error_min_duration',
        fallback: 'Event must be at least 15 minutes.',
      );
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
      dialogTheme: base.dialogTheme.copyWith(backgroundColor: OnesColors.white),
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
      firstDate: DateTime(1970, 1, 1),
      lastDate: DateTime(now.year + 50, 12, 31),
      builder: (context, child) => Theme(
        data: _pickerTheme(context),
        child: child!,
      ),
    );
    if (!mounted || pickedDate == null) return;

    setState(() {
      _startDate = pickedDate;
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
      firstDate: DateTime(1970, 1, 1),
      lastDate: DateTime(now.year + 50, 12, 31),
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

  Future<void> _pickFrames() async {
    final selected = await FramePickerSheet.open(
      context,
      initialSelectedFrameIds: _frameIds,
    );
    if (!mounted || selected == null) return;
    setState(() {
      _frameIds = List<String>.unmodifiable(selected);
    });
  }

  Future<void> _loadComplements() async {
    if (!mounted) return;
    setState(() {
      _isLoadingComplements = true;
      _complementsLoadFailed = false;
    });
    try {
      final complements = await context
          .read<EventComplementsApiRepository>()
          .list(widget.initial.id);
      final enabled = complements.any(
        (item) => item['id'] == 'tournament' && item['enabled'] == true,
      );
      if (!mounted) return;
      setState(() {
        _tournamentEnabled = enabled;
        _tournamentSelected = enabled;
        _isLoadingComplements = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingComplements = false;
        _complementsLoadFailed = true;
      });
    }
  }

  Future<void> _generateCover() async {
    final covers = context.read<EventCoversController>();
    final t = context.read<TranslationsService>();

    final eventName = _nameController.text.trim();
    final objective = _objectiveController.text.trim();
    final location = _locationController.text.trim();

    if (eventName.isEmpty || objective.isEmpty) return;

    final coverLocation = location.isEmpty
        ? t.translate('create_event.location_tbd', fallback: 'TBD')
        : location;
    await covers.generate(
      eventName: eventName,
      objective: objective,
      location: coverLocation,
      size: '1792x1024',
    );

    if (!mounted) return;
    setState(() {
      _coverReservationId = covers.reservationId;
    });
  }

  Future<void> _submit() async {
    final t = context.read<TranslationsService>();
    if (_isSaving || _isLoadingComplements) return;
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              t.translate(
                'create_event.error_complete_required_fields',
                fallback: 'Please complete required fields.',
              ),
            ),
          ),
        );
      return;
    }

    _validateDateTimes(showErrors: true);
    if (_dateTimeError != null) return;

    final startLocal = _combineLocal(_startDate, _startTime);
    final endLocal = _combineLocal(_endDate, _endTime);
    if (startLocal == null || endLocal == null) return;

    final controller = context.read<EventsController>();
    final complementsRepository = context.read<EventComplementsApiRepository>();
    var eventUpdated = false;

    setState(() => _isSaving = true);
    try {
      await controller.updateEvent(
        eventId: widget.initial.id,
        title: _nameController.text.trim(),
        objective: _objectiveController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? 'TBD'
            : _locationController.text.trim(),
        startAt: startLocal.toUtc(),
        endAt: endLocal.toUtc(),
        coverReservationId: _coverReservationId,
        allowGuestInvites: widget.initial.allowGuestInvites,
        frameIds: _frameIds,
      );
      eventUpdated = true;
      if (_tournamentSelected && !_tournamentEnabled) {
        await complementsRepository.setEnabled(
          eventId: widget.initial.id,
          complementId: 'tournament',
          enabled: true,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        EditEventResult(
          saved: true,
          tournamentEnabled: _tournamentSelected,
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              eventUpdated
                  ? '${t.translate('edit_event.tournament_enable_failed', fallback: 'El evento se actualizó, pero no se pudo activar el torneo.')} (${status ?? '-'})'
                  : '${t.translate('edit_event.error_update_failed', fallback: 'No se pudo actualizar el evento.')} (${status ?? '-'})',
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              eventUpdated
                  ? t.translate(
                      'edit_event.tournament_enable_failed',
                      fallback:
                          'El evento se actualizó, pero no se pudo activar el torneo.',
                    )
                  : t.translate(
                      'edit_event.error_update_failed',
                      fallback: 'No se pudo actualizar el evento.',
                    ),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _complementsSection(TranslationsService translations) {
    final title = translations.translate(
      'edit_event.complements_title',
      fallback: 'Complementos',
    );
    if (_isLoadingComplements) {
      return CreateEventFormSection(
        title: title,
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              translations.translate(
                'edit_event.complements_loading',
                fallback: 'Cargando complementos...',
              ),
            ),
          ],
        ),
      );
    }
    if (_complementsLoadFailed) {
      return CreateEventFormSection(
        title: title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              translations.translate(
                'edit_event.complements_load_failed',
                fallback: 'No se pudieron cargar los complementos del evento.',
              ),
            ),
            TextButton.icon(
              onPressed: _loadComplements,
              icon: const Icon(Icons.refresh),
              label: Text(
                translations.translate(
                  'edit_event.complements_retry',
                  fallback: 'Reintentar',
                ),
              ),
            ),
          ],
        ),
      );
    }

    return CreateEventFormSection(
      title: title,
      child: Material(
        color: Colors.transparent,
        child: SwitchListTile(
          key: const Key('edit_event.tournament_complement'),
          contentPadding: EdgeInsets.zero,
          value: _tournamentSelected,
          onChanged: _tournamentEnabled
              ? null
              : (value) => setState(() => _tournamentSelected = value),
          title: Text(
            translations.translate(
              'edit_event.tournament_title',
              fallback: 'Torneo 4 Equipos',
            ),
          ),
          subtitle: Text(
            translations.translate(
              _tournamentEnabled
                  ? 'edit_event.tournament_already_enabled'
                  : 'edit_event.tournament_subtitle',
              fallback: _tournamentEnabled
                  ? 'Este complemento ya está activo para el evento.'
                  : 'Agrega pronósticos y tabla de posiciones al evento.',
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coversController = context.watch<EventCoversController>();
    _coverReservationId = coversController.reservationId;

    final t = context.watch<TranslationsService>();
    final lang = t.getCurrentLanguage();
    if (_lastLanguage != lang) {
      _lastLanguage = lang;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<TranslationsService>().ensurePageTranslations(
              page: 'edit_event',
              requiredKeys: _editEventRequiredKeys,
            );
      });
    }

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isKeyboardOpen = bottomInset > 0;

    final start = _combineLocal(_startDate, _startTime);
    final end = _combineLocal(_endDate, _endTime);

    final dateSummary = (start == null || end == null)
        ? context.read<TranslationsService>().translate(
              'create_event.date_time_select_start_end',
              fallback: 'Select start and end time',
            )
        : '${formatShortMonthDay(start)} • ${TimeOfDay.fromDateTime(start).format(context)} → ${formatShortMonthDay(end)} • ${TimeOfDay.fromDateTime(end).format(context)}';

    return Scaffold(
      backgroundColor: OnesColors.background,
      appBar: AppBar(
        backgroundColor: OnesColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: OnesColors.purpleDeep),
          onPressed: () => Navigator.of(context).pop(
            const EditEventResult(saved: false, tournamentEnabled: false),
          ),
        ),
        title: Text(
          context.read<TranslationsService>().translate(
                'edit_event.title',
                fallback: 'Edit Event',
              ),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: OnesColors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving || _isLoadingComplements ? null : _submit,
            child: Text(
              context.read<TranslationsService>().translate(
                    'edit_event.action_save',
                    fallback: 'Guardar',
                  ),
              style: const TextStyle(
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
                Text(
                  dateSummary,
                  style: TextStyle(
                    color: OnesColors.black.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: context.read<TranslationsService>().translate(
                          'create_event.field_event_name',
                          fallback: 'Event Name',
                        ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? context.read<TranslationsService>().translate(
                            'create_event.validation_required',
                            fallback: 'Required',
                          )
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _objectiveController,
                  decoration: InputDecoration(
                    labelText: context.read<TranslationsService>().translate(
                          'create_event.field_objective',
                          fallback: 'Description',
                        ),
                  ),
                  minLines: 3,
                  maxLines: 6,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? context.read<TranslationsService>().translate(
                            'create_event.validation_required',
                            fallback: 'Required',
                          )
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: context.read<TranslationsService>().translate(
                          'create_event.field_location',
                          fallback: 'Location',
                        ),
                  ),
                ),
                const SizedBox(height: 14),
                CreateEventDateTimeCard(
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
                const SizedBox(height: 14),
                _complementsSection(t),
                const SizedBox(height: 14),
                CreateEventCoverPicker(
                  imageUrl: coversController.preview?.previewUrl,
                  loading: coversController.loading,
                  accepted: coversController.reservationId != null,
                  errorText: coversController.error?.toString(),
                  showGenerateHelper: _nameController.text.trim().isEmpty ||
                      _objectiveController.text.trim().isEmpty,
                  onGenerate: (_nameController.text.trim().isEmpty ||
                          _objectiveController.text.trim().isEmpty)
                      ? null
                      : _generateCover,
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
                const SizedBox(height: 14),
                Text(
                  () {
                    if (_frameIds.isEmpty) {
                      return context.read<TranslationsService>().translate(
                            'create_event.frames_none',
                            fallback: 'No frames selected for this event.',
                          );
                    }
                    final count = _frameIds.length;
                    final template = count == 1
                        ? context.read<TranslationsService>().translate(
                              'create_event.frames_one',
                              fallback: 'This event will use {count} frame.',
                            )
                        : context.read<TranslationsService>().translate(
                              'create_event.frames_many',
                              fallback: 'This event will use {count} frames.',
                            );
                    return template.replaceAll(
                      '{count}',
                      count.toString(),
                    );
                  }(),
                  style: TextStyle(
                    color: OnesColors.black.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _pickFrames,
                    child: Text(
                      context.read<TranslationsService>().translate(
                            'create_event.select_frames',
                            fallback: 'Seleccionar marcos',
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
