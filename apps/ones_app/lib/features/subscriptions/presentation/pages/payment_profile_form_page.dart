import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/payment_profile.dart';
import '../subscriptions_controller.dart';

class PaymentProfileFormPage extends StatefulWidget {
  final String planId;

  const PaymentProfileFormPage({super.key, required this.planId});

  @override
  State<PaymentProfileFormPage> createState() => _PaymentProfileFormPageState();
}

class _PaymentProfileFormPageState extends State<PaymentProfileFormPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _docTypeCtrl;
  late final TextEditingController _docNumberCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _countryCtrl;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<SubscriptionsController>().paymentProfile;
    _nameCtrl = TextEditingController(text: profile?.fullName ?? '');
    _emailCtrl = TextEditingController(text: profile?.mercadoPagoEmail ?? '');
    _docTypeCtrl = TextEditingController(text: profile?.documentType ?? '');
    _docNumberCtrl = TextEditingController(text: profile?.documentNumber ?? '');
    _phoneCtrl = TextEditingController(text: profile?.phoneNumber ?? '');
    _countryCtrl = TextEditingController(text: profile?.country ?? 'CO');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _docTypeCtrl.dispose();
    _docNumberCtrl.dispose();
    _phoneCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Datos del pagador'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Completa o confirma tus datos para continuar con el pago en Mercado Pago.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo (Mercado Pago)',
                hintText: 'tu-email@ejemplo.com',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _countryCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'País',
                      hintText: 'CO',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _docTypeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de documento',
                      hintText: 'CC / CE / NIT',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _docNumberCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Número de documento',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _onContinue,
                child:
                    Text(_submitting ? 'Procesando…' : 'Guardar y continuar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onContinue() async {
    final messenger = ScaffoldMessenger.of(context);

    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('El correo es obligatorio.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final controller = context.read<SubscriptionsController>();
      final profile = PaymentProfile(
        fullName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        mercadoPagoEmail: email,
        country: _countryCtrl.text.trim().isEmpty
            ? null
            : _countryCtrl.text.trim(),
        documentType: _docTypeCtrl.text.trim().isEmpty
            ? null
            : _docTypeCtrl.text.trim(),
        documentNumber: _docNumberCtrl.text.trim().isEmpty
            ? null
            : _docNumberCtrl.text.trim(),
        phoneNumber:
            _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      );

      await controller.savePaymentProfile(profile);
      if (!mounted) return;

      final initPoint =
          await controller.createMercadoPagoSubscription(widget.planId);
      if (!mounted) return;

      if (initPoint == null) {
        final err = controller.error ?? 'No se pudo iniciar el pago.';
        messenger.showSnackBar(SnackBar(content: Text(err)));
        return;
      }

      final uri = Uri.tryParse(initPoint);
      if (uri == null) {
        messenger.showSnackBar(
            SnackBar(content: Text('Enlace de pago inválido: $initPoint')));
        return;
      }

      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (!launched) {
        messenger.showSnackBar(SnackBar(
            content: Text(
                'No se pudo abrir el navegador. Copia este enlace: $initPoint')));
      } else {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
