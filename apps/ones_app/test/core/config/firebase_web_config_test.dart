import 'package:flutter_test/flutter_test.dart';
import 'package:ones_app/core/config/firebase_web_config.dart';

void main() {
  test('web options apuntan al proyecto ones-a96a7', () {
    final o = FirebaseWebConfig.options;

    expect(o.projectId, 'ones-a96a7');
    expect(o.authDomain, 'ones-a96a7.firebaseapp.com');
    expect(o.apiKey, startsWith('AIza'));
    expect(o.appId, startsWith('1:403122779240:web:'));
  });
}
