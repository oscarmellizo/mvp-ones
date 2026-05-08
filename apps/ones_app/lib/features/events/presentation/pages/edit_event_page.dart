import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../../../core/utils/datetime_formatters.dart';
import '../../domain/event.dart';
import '../event_covers_controller.dart';
import '../events_controller.dart';
import '../widgets/create_event_cover_widgets.dart';
import '../widgets/create_event_datetime_widgets.dart';
import '../widgets/frame_picker_sheet.dart';

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

  String? _coverReservationId;

  @override
  void initState() {
    super.initState();

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
      context.read<EventCoversController>().clear();
      setState(() {
        _coverReservationId = null;
      });
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
    final start = _combineLocal(_startDate, _startTime);
    final end = _combineLocal(_endDate, _endTime);

    String? error;
    if (start == null || end == null) {
      error = 'Please select start and end time.';
    } else if (end.isBefore(start.add(_minEventDuration))) {
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

  Future<void> _generateCover() async {
    final covers = context.read<EventCoversController>();

    final eventName = _nameController.text.trim();
    final objective = _objectiveController.text.trim();
    final location = _locationController.text.trim();

    if (eventName.isEmpty || objective.isEmpty) return;

    final coverLocation = location.isEmpty ? 'TBD' : location;
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
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
            const SnackBar(content: Text('Please complete required fields.')));
      return;
    }

    _validateDateTimes(showErrors: true);
    if (_dateTimeError != null) return;

    final startLocal = _combineLocal(_startDate, _startTime);
    final endLocal = _combineLocal(_endDate, _endTime);
    if (startLocal == null || endLocal == null) return;

    final controller = context.read<EventsController>();

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

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
            SnackBar(content: Text('Failed to update (${status ?? '-'})')));
      rethrow;
    } catch (e) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final coversController = context.watch<EventCoversController>();
    _coverReservationId = coversController.reservationId;

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isKeyboardOpen = bottomInset > 0;

    final start = _combineLocal(_startDate, _startTime);
    final end = _combineLocal(_endDate, _endTime);

    final dateSummary = (start == null || end == null)
        ? 'Select start and end time'
        : '${formatShortMonthDay(start)} • ${TimeOfDay.fromDateTime(start).format(context)} → ${formatShortMonthDay(end)} • ${TimeOfDay.fromDateTime(end).format(context)}';

    return Scaffold(
      backgroundColor: OnesColors.background,
      appBar: AppBar(
        backgroundColor: OnesColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: OnesColors.purpleDeep),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Text(
          'Edit Event',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: OnesColors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _submit,
            child: const Text(
              'Guardar',
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
                Text(
                  dateSummary,
                  style: TextStyle(
                    color: OnesColors.black.withOpacity(0.7),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Event Name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _objectiveController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  minLines: 3,
                  maxLines: 6,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(labelText: 'Location'),
                ),
                const SizedBox(height: 14),
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
                  _frameIds.isEmpty
                      ? 'No frames selected for this event.'
                      : 'This event will use ${_frameIds.length} frame${_frameIds.length == 1 ? '' : 's'}.',
                  style: TextStyle(
                    color: OnesColors.black.withOpacity(0.7),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _pickFrames,
                    child: const Text('Seleccionar marcos'),
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
