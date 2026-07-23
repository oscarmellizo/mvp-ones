import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PlansResultWebPage extends StatefulWidget {
  final String result;

  const PlansResultWebPage({super.key, required this.result});

  @override
  State<PlansResultWebPage> createState() => _PlansResultWebPageState();
}

class _PlansResultWebPageState extends State<PlansResultWebPage> {
  bool _opening = true;

  Uri get _appUri {
    final isDev = Uri.base.host.startsWith('appdev.');
    final scheme = isDev ? 'onesdev' : 'ones';
    return Uri(scheme: scheme, host: 'plans', path: '/${widget.result}');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openApp());
  }

  Future<void> _openApp() async {
    await launchUrl(_appUri, mode: LaunchMode.externalApplication);
    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    final details = switch (widget.result) {
      'success' => ('¡Pago aprobado!', 'Estamos abriendo Ones para actualizar tu plan.', Icons.check_circle_outline),
      'pending' => ('Pago pendiente', 'Tu pago está siendo procesado. Abre Ones para revisar el estado.', Icons.hourglass_top_outlined),
      _ => ('No pudimos completar el pago', 'Puedes volver a Ones e intentar nuevamente cuando quieras.', Icons.error_outline),
    };
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(details.$3, size: 72, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 24),
                Text(details.$1, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(details.$2, textAlign: TextAlign.center),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _opening ? null : _openApp,
                  icon: const Icon(Icons.open_in_new),
                  label: Text(_opening ? 'Abriendo la app…' : 'Abrir en la app'),
                ),
                TextButton(onPressed: _openApp, child: const Text('Volver a intentar')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
