import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ones_app/core/ui/dismiss_keyboard_on_tap.dart';

void main() {
  Future<FocusNode> pumpForm(WidgetTester tester) async {
    final focus = FocusNode();
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => DismissKeyboardOnTap(child: child!),
      home: Scaffold(
        body: Column(
          children: [
            TextField(key: const Key('field'), focusNode: focus),
            const SizedBox(key: Key('blank'), height: 300, width: 300),
          ],
        ),
      ),
    ));
    return focus;
  }

  testWidgets('tocar fuera del campo oculta el teclado', (tester) async {
    final focus = await pumpForm(tester);
    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();
    expect(focus.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('blank')));
    await tester.pump();

    expect(focus.hasFocus, isFalse);
  });

  testWidgets('tocar el campo no lo cierra', (tester) async {
    final focus = await pumpForm(tester);
    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();

    expect(focus.hasFocus, isTrue);
  });
}
