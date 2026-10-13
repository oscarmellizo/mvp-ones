import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../auth/presentation/pages/register_page.dart';
import '../../domain/events_repository.dart';
import '../event_detail_page.dart';
import 'event_invite_link_page.dart';

class EventJoinScanPage extends StatefulWidget {
  const EventJoinScanPage({super.key});

  @override
  State<EventJoinScanPage> createState() => _EventJoinScanPageState();
}

class _EventJoinScanPageState extends State<EventJoinScanPage> {
  final MobileScannerController _controller = MobileScannerController();

  bool _joining = false;
  bool _handledScan = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
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
        debugPrint('event_join_scan: auth error=$e');
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

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_joining || _handledScan) return;
    final first = capture.barcodes.firstOrNull;
    final raw = first?.rawValue ?? first?.displayValue;
    if (raw == null || raw.isEmpty) return;

    Uri? uri;
    try {
      uri = Uri.parse(raw);
    } catch (_) {
      uri = null;
    }
    if (uri == null || uri.path != EventInviteLinkPage.routeName) {
      setState(() {
        _error = 'QR no reconocido para eventos.';
      });
      return;
    }

    final eventId = uri.queryParameters['eventId'];
    final sig = uri.queryParameters['sig'];
    if (eventId == null || eventId.trim().isEmpty || sig == null || sig.trim().isEmpty) {
      setState(() {
        _error = 'QR incompleto o inválido.';
      });
      return;
    }

    setState(() {
      _joining = true;
      _handledScan = true;
      _error = null;
    });

    try {
      final auth = await _ensureRegisteredUser(context);
      if (!mounted || auth == null) {
        setState(() {
          _joining = false;
          _handledScan = false;
        });
        return;
      }

      final repo = context.read<EventsRepository>();
      // If using EventsApiRepository, it will read the fresh token via OnesApiFactory.

      await repo.acceptInviteLink(eventId, sig);
      if (!mounted) return;

      Navigator.of(context).pushReplacementNamed(
        '${EventDetailPage.routeName}?eventId=${Uri.encodeComponent(eventId)}&invitationStatus=accepted',
      );
    } on DioException catch (e) {
      if (!mounted) return;
      String message = 'No se pudo unir al evento.';
      final status = e.response?.statusCode;
      if (status == 404 || status == 410) {
        message = 'Este QR de invitación ya no es válido.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      setState(() {
        _joining = false;
        _handledScan = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo unir al evento.')), 
      );
      setState(() {
        _joining = false;
        _handledScan = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: OnesColors.white,
        title: const Text('Escanear QR de evento'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: const BoxDecoration(
                color: Color.fromRGBO(0, 0, 0, 0.65),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Apunta la cámara al QR del evento para unirte automáticamente.',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (_joining)
                    const Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Uniendo al evento...',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
