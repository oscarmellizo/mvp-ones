import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../auth/presentation/pages/register_page.dart';
import '../../domain/events_repository.dart';
import '../event_detail_page.dart';

class EventJoinCodePage extends StatefulWidget {
  const EventJoinCodePage({super.key});

  @override
  State<EventJoinCodePage> createState() => _EventJoinCodePageState();
}

class _EventJoinCodePageState extends State<EventJoinCodePage> {
  final _codeController = TextEditingController();
  bool _joining = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<AuthController?> _ensureRegisteredUser(BuildContext context) async {
    final authController = context.read<AuthController>();
    try {
      if (!authController.isSignedIn || (authController.idToken ?? '').isEmpty) {
        final step = await authController.signInExisting();
        if (!mounted) return null;
        if (step == AuthNextStep.needsRegistration) {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RegisterPage(popToRootOnComplete: false)),
          );
        }
      } else if (!authController.isRegistered) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RegisterPage(popToRootOnComplete: false)),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('event_join_code: auth error=$e');
      }
    }

    if (!mounted) return null;
    final afterAuth = context.read<AuthController>();
    if (!afterAuth.isRegistered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para unirte al evento.'),
        ),
      );
      return null;
    }
    return afterAuth;
  }

  Future<void> _join() async {
    final raw = _codeController.text.trim();
    if (raw.length != 6 || int.tryParse(raw) == null) {
      setState(() {
        _error = 'Ingresa un código de 6 dígitos.';
      });
      return;
    }
    setState(() {
      _error = null;
      _joining = true;
    });

    try {
      final auth = await _ensureRegisteredUser(context);
      if (!mounted || auth == null) {
        setState(() {
          _joining = false;
        });
        return;
      }

      final repo = context.read<EventsRepository>();
      final event = await repo.joinEventByCode(raw);
      if (!mounted) return;

      Navigator.of(context).pushReplacementNamed(
        '${EventDetailPage.routeName}?eventId=${Uri.encodeComponent(event.id)}&invitationStatus=accepted',
      );
    } on DioException catch (e) {
      if (!mounted) return;
      String message = 'No se pudo unir al evento con ese código.';
      final status = e.response?.statusCode;
      final data = e.response?.data;
      String code = '';
      if (data is Map) {
        final c = data['code'] ?? data['error'];
        if (c is String) code = c;
      }
      if (status == 404 || code == 'code_not_found') {
        message = 'Código inválido. Verifica el código e inténtalo de nuevo.';
      } else if (status == 410 || code == 'code_expired') {
        message = 'Este código ha expirado. Era válido hasta una semana después del evento.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      setState(() {
        _joining = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo unir al evento con ese código.')), 
      );
      setState(() {
        _joining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnesColors.background,
      appBar: AppBar(
        backgroundColor: OnesColors.background,
        foregroundColor: OnesColors.black,
        title: const Text('Ingresar código de evento'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ingresa el código de 6 dígitos que ves en el QR o que te enviaron del evento.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                maxLength: 6,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: 'Código de 6 dígitos',
                  border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _joining ? null : _join,
                  style: FilledButton.styleFrom(
                    backgroundColor: OnesColors.purpleMid,
                    foregroundColor: OnesColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: _joining
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Unirme al evento',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
