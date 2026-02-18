import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  static const Map<String, List<String>> _eventTypeByCategory = {
    'Eventos Sociales / Personales': [
      'Cumpleaños',
      'Boda',
      'Baby shower',
      'Bautizo',
      'Primer año',
      'Graduación',
      'Aniversario',
      'Despedida de soltero/a',
      'Reunión familiar',
      'Fiesta temática',
    ],
    'Eventos Académicos / Educativos': [
      'Feria de la ciencia',
      'Congreso académico',
      'Seminario',
      'Clase especial',
      'Evento institucional',
      'Graduación universitaria',
      'Semana cultural',
      'Exposición de proyectos',
    ],
    'Eventos Públicos': [
      'Concierto',
      'Festival',
      'Evento deportivo',
      'Maratón',
      'Evento comunitario',
      'Fiesta patronal',
      'Lanzamiento público',
    ],
    'Eventos Corporativos': [
      'Team building',
      'Kickoff anual',
      'Lanzamiento de producto',
      'Networking',
      'Convención empresarial',
      'Fiesta corporativa',
      'Capacitaciones internas',
    ],
    'Eventos Infantiles': [
      'Cumpleaños infantil',
      'Presentación escolares',
      'Día del niño',
      'Actividades extracurriculares',
      'Fiesta temática',
    ],
    'Eventos Religiosos / Tradicionales': [
      'Bautizos',
      'Confirmaciones',
      'Matrimonios religiosos',
      'Procesiones',
      'Celebraciones tradicionales',
    ],
    'Eventos Tech / Comunidades': [
      'Hackathons',
      'Meetups',
      'Demo Day',
      'Lanzamiento de startup',
      'Webinar híbrido',
    ],
    'Eventos Artísticos / Culturales': [
      'Obras de teatro',
      'Recitales',
      'Exposiciones',
      'Presentaciones de danza',
      'Eventos culturales locales',
    ],
    'Eventos Deportivos': [
      'Torneo escolar',
      'Campeonato',
      'Maratón',
      'Media Maratón',
      'Carrera 5K',
      'Carrera 10K',
      'Competencia local',
    ],
    'Micro-eventos cotidianos': [
      'Cena con amigos',
      'Noche de juegos',
      'Picnic familiar',
      'Reunión pequeña',
      'Viaje grupal',
    ],
  };

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _inviteEmailController = TextEditingController();

  final List<_Invitee> _invitees = [
    const _Invitee(name: 'Andrea', email: 'andrea@example.com'),
    const _Invitee(name: 'Luis', email: 'luis@example.com'),
  ];
  String? _inviteError;

  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;

  late String _eventCategory;
  late String _eventType;

  @override
  void initState() {
    super.initState();

    _eventCategory = _eventTypeByCategory.keys.first;
    _eventType = _eventTypeByCategory[_eventCategory]!.first;

    if (widget.initialTitle != null && widget.initialTitle!.trim().isNotEmpty) {
      _nameController.text = widget.initialTitle!.trim();
    }

    if (widget.initialLocation != null &&
        widget.initialLocation!.trim().isNotEmpty) {
      _locationController.text = widget.initialLocation!.trim();
    }

    if (widget.initialEventType != null &&
        widget.initialEventType!.trim().isNotEmpty) {
      final initial = widget.initialEventType!.trim();
      final match = _eventTypeByCategory.entries
          .where((e) => e.value.contains(initial))
          .map((e) => e.key)
          .cast<String?>()
          .firstWhere((_) => true, orElse: () => null);
      if (match != null) {
        _eventCategory = match;
        _eventType = initial;
      }
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

  void _addInvitee() {
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

    setState(() {
      _invitees.insert(
        0,
        _Invitee(name: _nameFromEmail(normalizedEmail), email: normalizedEmail),
      );
      _inviteError = null;
      _inviteEmailController.clear();
      FocusScope.of(context).unfocus();
    });
  }

  String _nameFromEmail(String email) {
    final at = email.indexOf('@');
    final raw = (at > 0 ? email.substring(0, at) : email)
        .replaceAll('.', ' ')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim();
    if (raw.isEmpty) return 'Guest';
    final parts = raw.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final titled = parts
        .map((p) => p.length == 1
            ? p.toUpperCase()
            : '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
    return titled;
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
                        value: _eventCategory,
                        items:
                            _eventTypeByCategory.keys.toList(growable: false),
                        onChanged: (v) {
                          setState(() {
                            _eventCategory = v;
                            _eventType =
                                _eventTypeByCategory[_eventCategory]!.first;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel('Event Type'),
                      const SizedBox(height: 8),
                      _DropdownField(
                        value: _eventType,
                        items: _eventTypeByCategory[_eventCategory]!,
                        onChanged: (v) => setState(() => _eventType = v),
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

    await controller.createNew(_nameController.text.trim());
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
  final VoidCallback onInvite;
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
            onSubmitted: (_) => onInvite(),
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
              onPressed: onInvite,
              child: const Text(
                'Invite',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
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

class _DropdownField extends StatelessWidget {
  final String value;
  final List<String> items;
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
                    value: e,
                    child: Text(e),
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
