import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../collections_controller.dart';

class CollectionInvitationLinkPage extends StatefulWidget {
  static const routeName = '/collection-invitation';
  final String token;
  const CollectionInvitationLinkPage({super.key, required this.token});

  @override
  State<CollectionInvitationLinkPage> createState() =>
      _CollectionInvitationLinkPageState();
}

class _CollectionInvitationLinkPageState
    extends State<CollectionInvitationLinkPage> {
  bool _loading = true;
  bool _completed = false;
  bool _accepted = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _respond());
  }

  Future<void> _respond() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final member = await context
          .read<CollectionsController>()
          .respondToInvitation(widget.token);
      if (!mounted) return;
      setState(() {
        _completed = true;
        _accepted = member.status == 'ACCEPTED';
        _message = member.status == 'ACCEPTED'
            ? 'Ya formas parte de esta colección.'
            : 'La invitación fue rechazada.';
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _completed = false;
        _message = error.response?.statusCode == 403
            ? 'Inicia sesión con el correo al que se envió la invitación.'
            : 'El enlace venció o la invitación ya fue respondida.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _completed = false;
        _message = 'No pudimos procesar esta invitación.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnesColors.surfaceWarm,
      appBar: AppBar(title: const Text('Invitación a colección')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loading)
                const CircularProgressIndicator()
              else
                Icon(
                  _completed
                      ? (_accepted
                          ? Icons.check_circle_outline
                          : Icons.do_not_disturb_on_outlined)
                      : Icons.info_outline,
                  size: 58,
                  color: _completed
                      ? (_accepted ? OnesColors.green : OnesColors.inkSoft)
                      : OnesColors.purpleMid,
                ),
              const SizedBox(height: 18),
              Text(
                _loading ? 'Procesando invitación…' : (_message ?? ''),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (!_loading && !_completed) ...[
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: _respond,
                  child: const Text('Intentar de nuevo'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
