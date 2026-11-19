String jpegImportFileName(String sourceName) {
  final normalizedPath = sourceName.replaceAll(r'\', '/');
  final fileName = normalizedPath.split('/').last;
  final extensionIndex = fileName.lastIndexOf('.');
  final baseName =
      extensionIndex > 0 ? fileName.substring(0, extensionIndex) : fileName;
  return '${baseName.isEmpty ? 'photo' : baseName}.jpg';
}
