import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/ones_typography.dart';
import '../../../../core/ui/widgets/ones_input_decoration.dart';
import 'auth_buttons.dart';

/// Rojo oscuro: el rojo de error estándar no se lee sobre el fondo ámbar.
const Color authErrorColor = Color(0xFF8C1D18);

/// Decoración de campos de auth: sin gris al pasar el mouse y errores legibles sobre ámbar.
InputDecoration authFieldDecoration({
  required String hintText,
  required IconData icon,
  Widget? suffix,
  String? helper,
  Color fillColor = OnesColors.white,
}) {
  const errorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.zero,
    borderSide: BorderSide(color: authErrorColor, width: 1.4),
  );
  return OnesInputDecoration.build(
    hintText: hintText,
    prefixIcon: Icon(icon, color: OnesColors.purpleDeep.withOpacity(0.7)),
    suffixIcon: suffix,
    fillColor: fillColor,
  ).copyWith(
    helperText: helper,
    helperStyle: TextStyle(color: OnesColors.black.withOpacity(0.75), fontWeight: FontWeight.w600),
    hoverColor: Colors.transparent,
    suffixIconColor: OnesColors.black.withOpacity(0.6),
    errorStyle: const TextStyle(color: authErrorColor, fontWeight: FontWeight.w700),
    errorBorder: errorBorder,
    focusedErrorBorder: errorBorder.copyWith(borderSide: const BorderSide(color: authErrorColor, width: 1.8)),
  );
}

/// Botón "Continuar con correo" que se despliega en el formulario de correo y contraseña.
class EmailAuthSection extends StatefulWidget {
  final String toggleLabel;
  final String submitLabel;
  final bool busy;

  /// Registro: exige 8 caracteres y sugiere contraseña nueva al gestor de contraseñas.
  final bool isRegistration;
  final Widget? footer;

  /// Blanco sobre el fondo ámbar; dentro de una tarjeta blanca usar un gris suave.
  final Color fieldFill;
  final Future<void> Function(String email, String password) onSubmit;

  const EmailAuthSection({
    super.key,
    required this.toggleLabel,
    required this.submitLabel,
    required this.busy,
    this.isRegistration = false,
    this.footer,
    this.fieldFill = OnesColors.white,
    required this.onSubmit,
  });

  @override
  State<EmailAuthSection> createState() => _EmailAuthSectionState();
}

class _EmailAuthSectionState extends State<EmailAuthSection> with WidgetsBindingObserver {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _formKey = GlobalKey<FormState>();
  final _formAreaKey = GlobalKey();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _expanded = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _emailFocus.addListener(_onFocusChange);
    _passwordFocus.addListener(_onFocusChange);
  }

  /// El teclado se abre o cambia de alto. Se escucha aquí y no en MediaQuery: dentro del
  /// Scaffold el inset del teclado llega en 0 porque el Scaffold ya achicó el cuerpo.
  /// En iOS el teclado suele subir después de que termina la animación del formulario.
  @override
  void didChangeMetrics() {
    if (_emailFocus.hasFocus || _passwordFocus.hasFocus) _scheduleReveal();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_emailFocus.hasFocus || _passwordFocus.hasFocus) _scheduleReveal();
  }

  /// Muestra el formulario completo (hasta el botón y el enlace inferior), no solo el campo con foco.
  void _scheduleReveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _formAreaKey.currentContext;
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(
        target,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  static void _hideKeyboard(PointerDownEvent _) => FocusManager.instance.primaryFocus?.unfocus();

  Future<void> _submit() async {
    if (widget.busy || !(_formKey.currentState?.validate() ?? false)) return;
    await widget.onSubmit(_email.text.trim(), _password.text);
  }

  InputDecoration _decoration(String hint, IconData icon, {Widget? suffix, String? helper}) {
    return authFieldDecoration(
      hintText: hint,
      icon: icon,
      suffix: suffix,
      helper: helper,
      fillColor: widget.fieldFill,
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return AnimatedSize(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      onEnd: () {
        if (_expanded) _scheduleReveal();
      },
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
      key: _formAreaKey,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('auth.email'),
              controller: _email,
              focusNode: _emailFocus,
              // En web el foco automático muestra el cursor pero el <input> del navegador no lo
              // recibe y lo escrito se pierde; ahí la persona hace clic en el campo.
              autofocus: !kIsWeb,
              onTapOutside: _hideKeyboard,
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
              focusNode: _passwordFocus,
              onTapOutside: _hideKeyboard,
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
            if (widget.footer != null) ...[
              const SizedBox(height: 4),
              widget.footer!,
            ],
          ],
        ),
      ),
    );
  }
}
