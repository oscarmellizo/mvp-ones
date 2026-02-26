bool looksLikeEmail(String value) {
  final v = value.trim();
  if (!v.contains('@')) return false;
  if (v.startsWith('@') || v.endsWith('@')) return false;
  if (!v.contains('.')) return false;
  return true;
}
