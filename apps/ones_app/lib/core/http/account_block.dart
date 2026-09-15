/// Detección de respuestas 403 que indican una cuenta desactivada o cerrada.
///
/// El API responde `403 {"code":"ACCOUNT_DISABLED"|"ACCOUNT_CLOSED"}` desde
/// `DisabledAccountFilter` cuando la cuenta ya no puede usar el servicio.
class AccountBlock {
  static const String disabled = 'ACCOUNT_DISABLED';
  static const String closed = 'ACCOUNT_CLOSED';

  /// Devuelve el código de bloqueo si [status]/[data] corresponden a uno, o null.
  static String? codeFrom(int? status, dynamic data) {
    if (status != 403 || data is! Map) return null;
    final code = data['code']?.toString();
    if (code == disabled || code == closed) return code;
    return null;
  }
}
