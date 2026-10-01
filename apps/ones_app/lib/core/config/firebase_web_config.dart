/// Configuración de la app Web registrada en Firebase (proyecto `ones-a96a7`).
///
/// Es la misma para dev y prod (un solo proyecto Firebase). No es secreta: Firebase
/// la expone en el navegador por diseño.
///
/// Dónde obtenerla: Firebase Console → Configuración del proyecto → General →
/// Tus apps → app Web → "Configuración del SDK" → Config.
class FirebaseWebConfig {
  const FirebaseWebConfig._();

  static const apiKey = 'PEGAR_API_KEY';
  static const appId = 'PEGAR_APP_ID'; // 1:403122779240:web:...
  static const messagingSenderId = '403122779240';
  static const projectId = 'ones-a96a7';
  static const authDomain = 'ones-a96a7.firebaseapp.com';
  static const storageBucket = 'ones-a96a7.firebasestorage.app';
}
