import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/ui/ones_colors.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = '${info.version}+${info.buildNumber}';
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnesColors.background,
      appBar: AppBar(
        backgroundColor: OnesColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Acerca de'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ones',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ones te ayuda a vivir tus eventos sin preocuparte por el espacio del teléfono ni por perder recuerdos. '
                'Sube y guarda automáticamente tus fotos y videos en la nube, sin pérdida de calidad, y '
                'compártelos fácilmente con tus invitados desde un único lugar.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Ventajas de usar Ones:',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text('• No más memoria llena: todo se almacena en la nube de forma segura.'),
              const Text('• Sin pérdida de calidad: conservamos tus fotos y videos con su nitidez original.'),
              const Text('• Compartir es fácil: crea un evento y todos pueden subir y ver contenido.'),
              const Text('• Todo organizado: tus recuerdos quedan ordenados cronológicamente por evento.'),
              const Text('• Acceso desde cualquier dispositivo: móvil o web, cuando lo necesites.'),
              const Text('• Respaldo seguro: evita pérdidas si cambias de equipo o lo extravías.'),
              const SizedBox(height: 16),
              Text('Versión: ${_version.isEmpty ? '—' : _version}'),
            ],
          ),
        ),
      ),
    );
  }
}
