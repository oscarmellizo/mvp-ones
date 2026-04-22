import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/datetime_formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/widgets/ones_text_form_field.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../event_covers_controller.dart';
import '../events_controller.dart';
import '../widgets/create_event_form_widgets.dart';
import '../widgets/create_event_cover_widgets.dart';
import '../widgets/create_event_datetime_widgets.dart';
import '../widgets/create_event_invite_widgets.dart';

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

    _nameController.addListener(_onFormChanged);
    _objectiveController.addListener(_onFormChanged);
    _locationController.addListener(_onFormChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
    final start = _combineLocal(_startDate, _startTime);
    final end = _combineLocal(_endDate, _endTime);
    if (start == null || end == null) return 'Select start and end time';
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
    return 'TBD';
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
    final start = _combineLocal(_startDate, _startTime);
    final end = _combineLocal(_endDate, _endTime);

    String? error;
    if (start != null &&
        end != null &&
        end.isBefore(start.add(_minEventDuration))) {
      error = 'Event must be at least 15 minutes.';
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

  Future<void> _pickStartDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (!mounted || pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );
    if (!mounted || pickedTime == null) return;

    setState(() {
      _startDate = pickedDate;
      _startTime = pickedTime;
      _ensureEndDefaults();
    });
    _validateDateTimes();
  }

  Future<void> _pickEndDateTime() async {
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
    );
    if (!mounted || pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _endTime ?? _startTime ?? TimeOfDay.now(),
    );
    if (!mounted || pickedTime == null) return;

    setState(() {
      _endDate = pickedDate;
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
    final raw = _inviteEmailController.text;
    final parts = raw
        .split(RegExp(r'[\s,;]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) {
      setState(() {
        _inviteError = 'Please enter an email.';
      });
      return;
    }

    final candidates =
        parts.map((e) => e.toLowerCase()).toList(growable: false);
    final invalid =
        candidates.where((e) => !looksLikeEmail(e)).toList(growable: false);
    if (invalid.isNotEmpty) {
      setState(() {
        _inviteError = 'Please enter a valid email.';
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
            ? 'You cannot invite yourself.'
            : 'This email is already invited.';
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
            removedSelf
                ? (newInvitees.length == 1
                    ? 'Guest added. Skipped your email.'
                    : '${newInvitees.length} guests added. Skipped your email.')
                : (newInvitees.length == 1
                    ? 'Guest added.'
                    : '${newInvitees.length} guests added.'),
          ),
        ),
      );
  }

  void _removeInvitee(CreateEventInvitee invitee) {
    setState(() {
      _invitees.removeWhere((i) => i.email == invitee.email);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EventsController>();
    final coversController = context.watch<EventCoversController>();

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
        title: const Text(
          'Create Event',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: OnesColors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: controller.loading ? null : () => _submit(context),
            child: const Text(
              'Crear',
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
                  title: 'Basics',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CreateEventFieldLabel('Event Name'),
                      const SizedBox(height: 8),
                      OnesTextFormField(
                        controller: _nameController,
                        hintText: 'e.g. Summer Roadtrip 2024',
                        suffixIcon: const Icon(Icons.edit_outlined),
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      const CreateEventFieldLabel('Objective'),
                      const SizedBox(height: 8),
                      OnesTextFormField(
                        controller: _objectiveController,
                        hintText: 'What is the objective of this event?',
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
                          if (v.isEmpty) return 'Objective is required';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                CreateEventFormSection(
                  title: 'When',
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
                            label: const Text('Today'),
                            onPressed: () =>
                                _applyQuickStartDate(DateTime.now()),
                          ),
                          ActionChip(
                            label: const Text('Tomorrow'),
                            onPressed: () => _applyQuickStartDate(
                                DateTime.now().add(const Duration(days: 1))),
                          ),
                          ActionChip(
                            label: const Text('This weekend'),
                            onPressed: () =>
                                _applyQuickStartDate(_nextWeekendStart()),
                          ),
                          ActionChip(
                            label: const Text('Now'),
                            onPressed: () =>
                                _applyQuickStartTime(_roundedNowTime()),
                          ),
                          ActionChip(
                            label: const Text('+30m'),
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
                            label: const Text('Evening'),
                            onPressed: () => _applyQuickStartTime(
                                const TimeOfDay(hour: 19, minute: 0)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CreateEventDateTimeCard(
                        startDate: _startDate,
                        startTime: _startTime,
                        endDate: _endDate,
                        endTime: _endTime,
                        errorText: _dateTimeError,
                        onPickStartDate: _pickStartDateTime,
                        onPickStartTime: _pickStartDateTime,
                        onPickEndDate: _pickEndDateTime,
                        onPickEndTime: _pickEndDateTime,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                CreateEventFormSection(
                  title: 'Cover',
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
                  title: 'Where (optional)',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CreateEventFieldLabel('Location'),
                      const SizedBox(height: 8),
                      OnesTextFormField(
                        controller: _locationController,
                        hintText: 'Add a location (optional)',
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
                  title: 'Guests',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Allow Guest Invites',
                            style: TextStyle(
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
                  title: 'Frames',
                  child: Text(
                    _frameIds.isEmpty
                        ? 'No frames selected for this event.'
                        : 'This event will use ${_frameIds.length} frame${_frameIds.length == 1 ? '' : 's'}.',
                    style: TextStyle(
                      color: OnesColors.black.withOpacity(0.7),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!isKeyboardOpen) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: _ctaHeight,
                    child: FilledButton(
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
                          ? const Text('Creating...')
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Create Event',
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
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Please complete required fields.')),
        );
      return;
    }
    final objective = _objectiveController.text.trim();
    if (objective.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Objective is required.')));
      return;
    }

    _validateDateTimes(showErrors: false);

    final startLocal = _combineLocal(_startDate, _startTime);
    final endLocal = _combineLocal(_endDate, _endTime);

    if (startLocal == null || endLocal == null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Please select start and end time.')),
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
            const SnackBar(
              content: Text('Your session expired. Please sign in again.'),
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

    final eventName = _nameController.text.trim();
    final objective = _objectiveController.text.trim();
    if (eventName.isEmpty) return;
    if (objective.isEmpty) return;
    final location = _locationController.text.trim();
    final coverLocation = location.isEmpty ? 'TBD' : location;

    try {
      await covers.generate(
        eventName: eventName,
        objective: objective,
        location: coverLocation,
        size: '1792x1024',
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Your session expired. Please sign in again.'),
            ),
          );
        await auth.logout();
        return;
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Failed to generate cover.')),
        );
      rethrow;
    }
  }
}
