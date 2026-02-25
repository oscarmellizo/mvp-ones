import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../event_covers_controller.dart';
import '../events_controller.dart';

class CreateEventPage extends StatefulWidget {
  static const routeName = '/events/create';

  final String? initialTitle;
  final String? initialEventType;
  final String? initialLocation;
  final DateTime? initialStartDate;
  final TimeOfDay? initialStartTime;
  final DateTime? initialEndDate;
  final TimeOfDay? initialEndTime;

  const CreateEventPage({
    super.key,
    this.initialTitle,
    this.initialEventType,
    this.initialLocation,
    this.initialStartDate,
    this.initialStartTime,
    this.initialEndDate,
    this.initialEndTime,
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

  final List<_Invitee> _invitees = [];
  String? _inviteError;

  String? _dateTimeError;

  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;

  String? _coverReservationId;

  bool _allowGuestInvites = true;

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

  InputDecoration _inputDecoration({
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: OnesColors.black.withOpacity(0.12)),
    );
    return InputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: OnesColors.black.withOpacity(0.04),
      border: baseBorder,
      enabledBorder: baseBorder,
      focusedBorder: baseBorder.copyWith(
        borderSide: const BorderSide(color: OnesColors.purpleMid, width: 1.6),
      ),
    );
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
        candidates.where((e) => !_looksLikeEmail(e)).toList(growable: false);
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

    final newInvitees = <_Invitee>[];
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
      newInvitees.add(_Invitee(name: displayName, email: email));
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

  void _removeInvitee(_Invitee invitee) {
    setState(() {
      _invitees.removeWhere((i) => i.email == invitee.email);
    });
  }

  bool _looksLikeEmail(String value) {
    final v = value.trim();
    if (!v.contains('@')) return false;
    if (v.startsWith('@') || v.endsWith('@')) return false;
    if (!v.contains('.')) return false;
    return true;
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
                _FormSection(
                  title: 'Basics',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Event Name'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration(
                          hintText: 'e.g. Summer Roadtrip 2024',
                          suffixIcon: const Icon(Icons.edit_outlined),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel('Objective'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _objectiveController,
                        keyboardType: TextInputType.multiline,
                        minLines: 3,
                        maxLines: 6,
                        textInputAction: TextInputAction.newline,
                        decoration: _inputDecoration(
                          hintText: 'What is the objective of this event?',
                          prefixIcon: const Icon(
                            Icons.flag,
                            color: OnesColors.purpleDeep,
                          ),
                        ).copyWith(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
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
                _FormSection(
                  title: 'When',
                  child: _DateTimeCard(
                    startDate: _startDate,
                    startTime: _startTime,
                    endDate: _endDate,
                    endTime: _endTime,
                    errorText: _dateTimeError,
                    onPickStartDate: () => _pickDate(
                      initial: _startDate,
                      onPicked: (d) {
                        setState(() {
                          _startDate = d;
                          _ensureEndDefaults();
                        });
                        _validateDateTimes();
                      },
                    ),
                    onPickStartTime: () => _pickTime(
                      initial: _startTime,
                      onPicked: (t) {
                        setState(() {
                          _startTime = t;
                          _ensureEndDefaults();
                        });
                        _validateDateTimes();
                      },
                    ),
                    onPickEndDate: () => _pickDate(
                      initial: _endDate,
                      onPicked: (d) {
                        setState(() => _endDate = d);
                        _validateDateTimes();
                      },
                    ),
                    onPickEndTime: () => _pickTime(
                      initial: _endTime,
                      onPicked: (t) {
                        setState(() => _endTime = t);
                        _validateDateTimes();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _FormSection(
                  title: 'Cover',
                  child: _CoverPicker(
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
                _FormSection(
                  title: 'Where (optional)',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Location'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _locationController,
                        decoration: _inputDecoration(
                          hintText: 'Add a location (optional)',
                          prefixIcon: const Icon(
                            Icons.location_on,
                            color: OnesColors.purpleDeep,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _FormSection(
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
                      _InviteGuestsCard(
                        emailController: _inviteEmailController,
                        inviteError: _inviteError,
                        invitees: _invitees,
                        onInvite: _addInvitee,
                        onRemove: _removeInvitee,
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
                      style: FilledButton.styleFrom(
                        backgroundColor: OnesColors.purpleMid,
                        disabledBackgroundColor:
                            OnesColors.purpleMid.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
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

  Future<void> _pickDate({
    required DateTime? initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _pickTime({
    required TimeOfDay? initial,
    required ValueChanged<TimeOfDay> onPicked,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? TimeOfDay.now(),
    );
    if (picked != null) onPicked(picked);
  }
}

class _InviteGuestsCard extends StatelessWidget {
  final TextEditingController emailController;
  final String? inviteError;
  final List<_Invitee> invitees;
  final Future<void> Function() onInvite;
  final ValueChanged<_Invitee> onRemove;

  const _InviteGuestsCard({
    required this.emailController,
    required this.inviteError,
    required this.invitees,
    required this.onInvite,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OnesColors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Invite Guests',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              Text(
                '${invitees.length}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: OnesColors.black.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              onInvite();
            },
            decoration: InputDecoration(
              hintText: 'Add emails (comma/space separated)',
              filled: true,
              fillColor: OnesColors.black.withOpacity(0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: OnesColors.black.withOpacity(0.12)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: OnesColors.black.withOpacity(0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: OnesColors.purpleMid,
                  width: 1.6,
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          if (inviteError != null) ...[
            const SizedBox(height: 10),
            Text(
              inviteError!,
              style: const TextStyle(
                color: OnesColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: OnesColors.purpleMid,
                foregroundColor: OnesColors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                onInvite();
              },
              child: const Text(
                'Invite',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Invited',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (invitees.isEmpty)
            Text(
              'No invited guests yet.',
              style: TextStyle(color: OnesColors.black.withOpacity(0.55)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: invitees
                  .map(
                    (invitee) => InputChip(
                      label: Tooltip(
                        message: invitee.email,
                        child: Text(
                          invitee.name.trim().isNotEmpty &&
                                  invitee.name != invitee.email
                              ? invitee.name
                              : invitee.email,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      onDeleted: () => onRemove(invitee),
                      deleteIcon: const Icon(Icons.close, size: 18),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _FormSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OnesColors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Invitee {
  final String name;
  final String email;

  const _Invitee({required this.name, required this.email});
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        color: OnesColors.black,
      ),
    );
  }
}

class _CoverPicker extends StatelessWidget {
  final String? imageUrl;
  final bool loading;
  final bool accepted;
  final String? errorText;
  final VoidCallback? onGenerate;
  final bool showGenerateHelper;
  final VoidCallback? onAccept;
  final VoidCallback? onCancel;

  const _CoverPicker({
    required this.imageUrl,
    required this.loading,
    required this.accepted,
    required this.errorText,
    required this.onGenerate,
    required this.showGenerateHelper,
    required this.onAccept,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: OnesColors.yellowPale.withOpacity(0.55),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: imageUrl == null
                        ? const SizedBox.shrink()
                        : Image.network(imageUrl!, fit: BoxFit.cover),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          OnesColors.black
                              .withOpacity(imageUrl == null ? 0 : 0.10),
                          OnesColors.black
                              .withOpacity(imageUrl == null ? 0 : 0.55),
                        ],
                      ),
                    ),
                  ),
                ),
                if (imageUrl == null && !loading)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: const _DashedBorderPainter(
                        color: OnesColors.purpleBright,
                        radius: 18,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: OnesColors.yellowPale,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.image,
                              color: OnesColors.purpleMid,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Event Cover',
                            style: TextStyle(
                              color: OnesColors.purpleMid,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (loading)
                  const Positioned.fill(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (errorText != null && errorText!.trim().isNotEmpty) ...[
          Text(
            errorText!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: OnesColors.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (showGenerateHelper) ...[
          const Text(
            'Complete name and objective to generate a cover.',
            style: TextStyle(
              color: OnesColors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: OnesColors.purpleMid,
                  foregroundColor: OnesColors.white,
                  disabledBackgroundColor:
                      OnesColors.purpleMid.withOpacity(0.5),
                  disabledForegroundColor: OnesColors.white.withOpacity(0.85),
                ),
                onPressed: (loading || onGenerate == null) ? null : onGenerate,
                child: loading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        accepted ? 'Regenerate' : 'Generate with AI',
                      ),
              ),
            ),
            if (imageUrl != null && !accepted) ...[
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OnesColors.purpleMid,
                    side: const BorderSide(
                      color: OnesColors.purpleMid,
                      width: 1.6,
                    ),
                  ),
                  onPressed: onAccept,
                  child: const Text('Use'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OnesColors.purpleMid,
                    side: const BorderSide(
                      color: OnesColors.purpleMid,
                      width: 1.6,
                    ),
                  ),
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _DateTimeCard extends StatelessWidget {
  final DateTime? startDate;
  final TimeOfDay? startTime;
  final DateTime? endDate;
  final TimeOfDay? endTime;
  final String? errorText;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickStartTime;
  final VoidCallback onPickEndDate;
  final VoidCallback onPickEndTime;

  const _DateTimeCard({
    required this.startDate,
    required this.startTime,
    required this.endDate,
    required this.endTime,
    required this.errorText,
    required this.onPickStartDate,
    required this.onPickStartTime,
    required this.onPickEndDate,
    required this.onPickEndTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OnesColors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _DateTimeRow(
            icon: Icons.calendar_month,
            title: 'Starts',
            dateValue: _formatDate(startDate),
            timeValue: _formatTime(context, startTime),
            onPickDate: onPickStartDate,
            onPickTime: onPickStartTime,
          ),
          const SizedBox(height: 14),
          _DateTimeRow(
            icon: Icons.event_busy,
            title: 'Ends',
            dateValue: _formatDate(endDate),
            timeValue: _formatTime(context, endTime),
            onPickDate: onPickEndDate,
            onPickTime: onPickEndTime,
          ),
          if (errorText != null && errorText!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                errorText!,
                style: const TextStyle(
                  color: OnesColors.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'mm/dd/yyyy';
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    final yyyy = date.year.toString();
    return '$mm/$dd/$yyyy';
  }

  String _formatTime(BuildContext context, TimeOfDay? time) {
    if (time == null) return '--:--';
    return time.format(context);
  }
}

class _DateTimeRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String dateValue;
  final String timeValue;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  const _DateTimeRow({
    required this.icon,
    required this.title,
    required this.dateValue,
    required this.timeValue,
    required this.onPickDate,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: OnesColors.purpleBright.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: OnesColors.purpleMid),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MiniField(
                      label: 'Date',
                      value: dateValue,
                      icon: Icons.calendar_today,
                      onTap: onPickDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniField(
                      label: 'Time',
                      value: timeValue,
                      icon: Icons.access_time,
                      onTap: onPickTime,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _MiniField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: OnesColors.black.withOpacity(0.55),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: OnesColors.white.withOpacity(0.75),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: OnesColors.black.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: OnesColors.black.withOpacity(0.65),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(icon, size: 18, color: OnesColors.black.withOpacity(0.55)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    const dash = 6.0;
    const gap = 4.0;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
