import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../auth/presentation/pages/register_page.dart';
import '../collections_controller.dart';
import 'collection_join_qr_payload.dart';

class CollectionJoinQrPage extends StatefulWidget {
  const CollectionJoinQrPage({super.key});

  @override
  State<CollectionJoinQrPage> createState() => _CollectionJoinQrPageState();
}

class _CollectionJoinQrPageState extends State<CollectionJoinQrPage> {
  final MobileScannerController _scanner = MobileScannerController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_busy) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    final payload = CollectionJoinQrPayload.tryParse(raw);
    if (payload == null) {
      setState(
          () => _error = 'Este QR no corresponde a una colección de ONES.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthController>();
      if (!auth.isSignedIn || (auth.idToken ?? '').isEmpty) {
        final step = await auth.signInExisting();
        if (!mounted) return;
        if (step == AuthNextStep.needsRegistration) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const RegisterPage(popToRootOnComplete: false),
            ),
          );
        }
      } else if (!auth.isRegistered) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const RegisterPage(popToRootOnComplete: false),
          ),
        );
      }
      if (!mounted || !context.read<AuthController>().isRegistered) {
        setState(() => _busy = false);
        return;
      }
      await context.read<CollectionsController>().joinByQr(
            collectionId: payload.collectionId,
            token: payload.token,
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on DioException catch (error) {
      if (!mounted) return;
      final status = error.response?.statusCode;
      setState(() {
        _busy = false;
        _error = status == 404 || status == 409
            ? 'El QR ya no está activo o la colección alcanzó su límite.'
            : 'No se pudo unir a la colección. Inténtalo de nuevo.';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'No se pudo unir a la colección. Inténtalo de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: OnesColors.white,
        title: const Text('Unirse a una colección'),
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _scanner, onDetect: _handleBarcode),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
              color: const Color.fromRGBO(0, 0, 0, .68),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Escanea el QR para unirte al instante.',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
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
                  if (_busy) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
