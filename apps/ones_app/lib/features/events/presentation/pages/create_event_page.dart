import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/auth_controller.dart';
import '../../domain/events_metadata.dart';
import '../events_metadata_controller.dart';
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
  bool _metadataLoadTriggered = false;
  bool _metadataApplied = false;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _inviteEmailController = TextEditingController();

  final List<_Invitee> _invitees = [];
  String? _inviteError;

  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;

  String? _eventCategoryId;
  String? _eventTypeId;

  @override
  void initState() {
    super.initState();

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
    _nameController.dispose();
    _locationController.dispose();
    _inviteEmailController.dispose();
    super.dispose();
  }

  Future<void> _addInvitee() async {
    final email = _inviteEmailController.text.trim();
    final normalizedEmail = email.toLowerCase();

    if (email.isEmpty) {
      setState(() {
        _inviteError = 'Please enter an email.';
      });
      return;
    }

    if (!_looksLikeEmail(normalizedEmail)) {
      setState(() {
        _inviteError = 'Please enter a valid email.';
      });
      return;
    }

    final alreadyExists =
        _invitees.any((i) => i.email.toLowerCase() == normalizedEmail);
    if (alreadyExists) {
      setState(() {
        _inviteError = 'This email is already invited.';
      });
      return;
    }

    final auth = context.read<AuthController>();
    String displayName = normalizedEmail;
    try {
      final lookup = await auth.lookupUserByEmail(normalizedEmail);
      final pn = lookup?.preferredName?.trim();
      if (pn != null && pn.isNotEmpty) {
        displayName = pn;
      }
    } catch (_) {
      // ignore lookup errors and fall back to email
    }

    if (!mounted) return;
    setState(() {
      _invitees.insert(
        0,
        _Invitee(name: displayName, email: normalizedEmail),
      );
      _inviteError = null;
      _inviteEmailController.clear();
      FocusScope.of(context).unfocus();
    });
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
    final metadataController = context.watch<EventsMetadataController>();

    if (!_metadataLoadTriggered) {
      _metadataLoadTriggered = true;
      Future.microtask(() async {
        try {
          await metadataController.ensureLoaded();
        } catch (_) {
          // ignore
        }
      });
    }

    final categories =
        metadataController.metadata?.categories ?? const <EventCategory>[];

    if (!_metadataApplied && categories.isNotEmpty) {
      _metadataApplied = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final initial = widget.initialEventType?.trim();

        String? categoryId;
        String? eventTypeId;

        if (initial != null && initial.isNotEmpty) {
          for (final c in categories) {
            for (final t in c.eventTypes) {
              if (t.id == initial || t.label == initial) {
                categoryId = c.id;
                eventTypeId = t.id;
                break;
              }
            }
            if (categoryId != null) break;
          }
        }

        final firstCategory = categories.first;
        final firstType = firstCategory.eventTypes.isNotEmpty
            ? firstCategory.eventTypes.first
            : null;

        setState(() {
          _eventCategoryId = categoryId ?? firstCategory.id;
          _eventTypeId = eventTypeId ?? firstType?.id;
        });
      });
    }

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF4B64E),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4B64E),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF3B1D6D)),
          onPressed:
              controller.loading ? null : () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Create Event',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: const [],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 120 + bottomInset),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CoverPicker(
                        onTap: () {},
                      ),
                      const SizedBox(height: 18),
                      const _FieldLabel('Event Name'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: 'e.g. Summer Roadtrip 2024',
                          suffixIcon: const Icon(Icons.edit_outlined),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel('Category'),
                      const SizedBox(height: 8),
                      _DropdownField(
                        value: _eventCategoryId,
                        items: categories
                            .map((c) => _DropdownOption(
                                  value: c.id,
                                  label: c.label,
                                ))
                            .toList(growable: false),
                        onChanged: (v) {
                          final selected = categories
                              .where((c) => c.id == v)
                              .cast<EventCategory?>()
                              .firstWhere((_) => true, orElse: () => null);
                          setState(() {
                            _eventCategoryId = v;
                            _eventTypeId =
                                selected?.eventTypes.isNotEmpty == true
                                    ? selected!.eventTypes.first.id
                                    : null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel('Event Type'),
                      const SizedBox(height: 8),
                      _DropdownField(
                        value: _eventTypeId,
                        items: (() {
                          final catId = _eventCategoryId;
                          final selected = categories
                              .where((c) => c.id == catId)
                              .cast<EventCategory?>()
                              .firstWhere((_) => true, orElse: () => null);
                          return (selected?.eventTypes ?? const <EventType>[])
                              .map((t) => _DropdownOption(
                                    value: t.id,
                                    label: t.label,
                                  ))
                              .toList(growable: false);
                        })(),
                        onChanged: (v) => setState(() => _eventTypeId = v),
                      ),
                      const SizedBox(height: 16),
                      _DateTimeCard(
                        startDate: _startDate,
                        startTime: _startTime,
                        endDate: _endDate,
                        endTime: _endTime,
                        onPickStartDate: () => _pickDate(
                          initial: _startDate,
                          onPicked: (d) => setState(() => _startDate = d),
                        ),
                        onPickStartTime: () => _pickTime(
                          initial: _startTime,
                          onPicked: (t) => setState(() => _startTime = t),
                        ),
                        onPickEndDate: () => _pickDate(
                          initial: _endDate,
                          onPicked: (d) => setState(() => _endDate = d),
                        ),
                        onPickEndTime: () => _pickTime(
                          initial: _endTime,
                          onPicked: (t) => setState(() => _endTime = t),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel('Location'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          hintText: 'Add a location',
                          prefixIcon: const Icon(
                            Icons.location_on,
                            color: Color(0xFF3B1D6D),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
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
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16 + bottomInset,
              child: SizedBox(
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6A0D73),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: controller.loading ? null : () => _submit(context),
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
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final controller = context.read<EventsController>();
    if (!_formKey.currentState!.validate()) return;

    final eventTypeId = _eventTypeId;
    if (eventTypeId == null || eventTypeId.trim().isEmpty) return;

    final startDate = _startDate;
    final startTime = _startTime;
    final endDate = _endDate;
    final endTime = _endTime;
    if (startDate == null || startTime == null) return;
    if (endDate == null || endTime == null) return;

    final startAt = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      startTime.hour,
      startTime.minute,
    ).toUtc();
    final endAt = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      endTime.hour,
      endTime.minute,
    ).toUtc();

    await controller.createNew(
      _nameController.text.trim(),
      eventTypeId,
      _locationController.text.trim(),
      startAt,
      endAt,
    );
    if (context.mounted) Navigator.of(context).pop();
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invite Guests',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
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
              hintText: 'Email (required)',
              filled: true,
              fillColor: const Color(0xFFF7F3EA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
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
                color: Color(0xFFE25555),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6A0D73),
                foregroundColor: Colors.white,
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
              style: TextStyle(color: Colors.black.withOpacity(0.55)),
            )
          else
            ListView.separated(
              itemCount: invitees.length,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              separatorBuilder: (_, __) => Divider(
                height: 14,
                color: Colors.black.withOpacity(0.06),
              ),
              itemBuilder: (context, index) {
                final invitee = invitees[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    invitee.name,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    invitee.email,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.6),
                    ),
                  ),
                  trailing: IconButton(
                    onPressed: () => onRemove(invitee),
                    icon: const Icon(Icons.close),
                  ),
                );
              },
            ),
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
        color: Colors.black,
      ),
    );
  }
}

class _DropdownOption {
  final String value;
  final String label;

  const _DropdownOption({required this.value, required this.label});
}

class _DropdownField extends StatelessWidget {
  final String? value;
  final List<_DropdownOption> items;
  final ValueChanged<String> onChanged;

  const _DropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down),
          items: items
              .map((e) => DropdownMenuItem<String>(
                    value: e.value,
                    child: Text(e.label),
                  ))
              .toList(growable: false),
          onChanged: (v) {
            if (v == null) return;
            onChanged(v);
          },
        ),
      ),
    );
  }
}

class _CoverPicker extends StatelessWidget {
  final VoidCallback onTap;

  const _CoverPicker({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: CustomPaint(
        painter: const _DashedBorderPainter(
          color: Color(0xFFD5A3C7),
          radius: 18,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFF6E6CF),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFE5D0D8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.photo_camera,
                  color: Color(0xFF6A0D73),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Add Event Cover',
                style: TextStyle(
                  color: Color(0xFF6A0D73),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Optional • Max 10MB',
                style: TextStyle(
                  color: Colors.black.withOpacity(0.5),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateTimeCard extends StatelessWidget {
  final DateTime? startDate;
  final TimeOfDay? startTime;
  final DateTime? endDate;
  final TimeOfDay? endTime;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickStartTime;
  final VoidCallback onPickEndDate;
  final VoidCallback onPickEndTime;

  const _DateTimeCard({
    required this.startDate,
    required this.startTime,
    required this.endDate,
    required this.endTime,
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
        color: Colors.white,
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
            color: const Color(0xFFF1E9F7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF6A0D73)),
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
            color: Colors.black.withOpacity(0.55),
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
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.65),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(icon, size: 18, color: Colors.black.withOpacity(0.55)),
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
