import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/auth_controller.dart';
import '../events_controller.dart';
import 'create_event_page.dart';
import 'event_detail_page.dart';

class EventsListPage extends StatefulWidget {
  static const routeName = '/events';

  const EventsListPage({super.key});

  @override
  State<EventsListPage> createState() => _EventsListPageState();
}

class _EventsListPageState extends State<EventsListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventsController>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final controller = context.watch<EventsController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eventos'),
        actions: [
          IconButton(
            onPressed: controller.loading ? null : () => controller.refresh(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: auth.isLoading ? null : () => auth.logout(),
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).pushNamed(CreateEventPage.routeName),
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (controller.error != null)
              Text('Error: ${controller.error}', style: const TextStyle(color: Colors.red)),
            if (auth.user != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Signed in as ${auth.user!.email ?? auth.user!.displayName ?? auth.user!.userId}'),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: controller.loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      itemCount: controller.events.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final e = controller.events[index];
                        return ListTile(
                          title: Text(e.title),
                          subtitle: Text(e.createdAt.toIso8601String()),
                          onTap: () => Navigator.of(context).pushNamed(EventDetailPage.routeName, arguments: e.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
