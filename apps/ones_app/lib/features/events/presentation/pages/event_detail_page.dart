import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../events_controller.dart';

class EventDetailPage extends StatefulWidget {
  static const routeName = '/events/detail';

  final String eventId;

  const EventDetailPage({super.key, required this.eventId});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventsController>().select(widget.eventId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EventsController>();
    final event = controller.selected;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: controller.loading
            ? const Center(child: CircularProgressIndicator())
            : event == null
                ? Text('No event (error: ${controller.error})')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 12),
                      Text('ID: ${event.id}'),
                      Text('Owner: ${event.ownerId}'),
                      Text('Created: ${event.createdAt.toIso8601String()}'),
                    ],
                  ),
      ),
    );
  }
}
