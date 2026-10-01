import 'package:flutter/material.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/ones_typography.dart';
import '../../../../core/ui/widgets/ones_input_decoration.dart';
import 'auth_buttons.dart';

/// Botón "Continuar con correo" que se despliega en el formulario de correo y contraseña.
class EmailAuthSection extends StatefulWidget {
  final String toggleLabel;
  final String submitLabel;
  final bool busy;

  /// Registro: exige 8 caracteres y sugiere contraseña nueva al gestor de contraseñas.
  final bool isRegistration;
  final Widget? footer;
  final Future<void> Function(String email, String password) onSubmit;

  const EmailAuthSection({
    super.key,
    required this.toggleLabel,
    required this.submitLabel,
    required this.busy,
    this.isRegistration = false,
    this.footer,
    required this.onSubmit,
  });

  @override
  State<EmailAuthSection> createState() => _EmailAuthSectionState();
}

class _EmailAuthSectionState extends State<EmailAuthSection> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _expanded = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.busy || !(_formKey.currentState?.validate() ?? false)) return;
    await widget.onSubmit(_email.text.trim(), _password.text);
  }

  InputDecoration _decoration(String hint, IconData icon, {Widget? suffix, String? helper}) {
    return OnesInputDecoration.build(
      hintText: hint,
      prefixIcon: Icon(icon, color: OnesColors.purpleDeep.withOpacity(0.7)),
      suffixIcon: suffix,
      fillColor: OnesColors.white,
    ).copyWith(helperText: helper);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return AnimatedSize(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _expanded ? _form() : _toggle(),
    );
  }

  Widget _toggle() {
    return AuthOptionButton(
      key: const Key('auth.emailToggle'),
      logo: const Icon(Icons.mail_outline, size: 20, color: OnesColors.purpleDeep),
      label: widget.toggleLabel,
      onPressed: widget.busy ? null : () => setState(() => _expanded = true),
      background: Colors.transparent,
      foreground: OnesColors.purpleDeep,
      border: OnesColors.purpleDeep,
    );
  }

  Widget _form() {
    const fieldStyle = TextStyle(
      fontFamilyFallback: OnesTypography.bodyFallbacks,
      color: OnesColors.black,
      fontWeight: FontWeight.w600,
    );
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('auth.email'),
              controller: _email,
              autofocus: true,
              style: fieldStyle,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: _decoration('Correo', Icons.mail_outline),
              validator: (v) => _emailPattern.hasMatch((v ?? '').trim()) ? null : 'Escribe un correo válido.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('auth.password'),
              controller: _password,
              style: fieldStyle,
              obscureText: _obscure,
              autofillHints: [widget.isRegistration ? AutofillHints.newPassword : AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: _decoration(
                'Contraseña',
                Icons.lock_outline,
                helper: widget.isRegistration ? 'Mínimo 8 caracteres.' : null,
                suffix: IconButton(
                  tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) {
                final value = v ?? '';
                if (value.isEmpty) return 'Escribe tu contraseña.';
                if (widget.isRegistration && value.length < 8) return 'Usa al menos 8 caracteres.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('auth.submit'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: OnesColors.purpleMid,
                foregroundColor: OnesColors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              onPressed: widget.busy ? null : _submit,
              child: Text(
                widget.busy ? 'Un momento...' : widget.submitLabel,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            if (widget.footer != null) widget.footer!,
          ],
        ),
      ),
    );
  }
}
