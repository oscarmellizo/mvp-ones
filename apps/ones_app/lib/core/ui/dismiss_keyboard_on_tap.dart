import 'package:flutter/widgets.dart';

/// Oculta el teclado al tocar fuera de un campo de texto, en toda la app.
/// En iOS el teclado no se cierra solo al tocar el fondo.
class DismissKeyboardOnTap extends StatelessWidget {
  final Widget child;

  const DismissKeyboardOnTap({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // translucent: los botones y campos siguen recibiendo sus toques.
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}
