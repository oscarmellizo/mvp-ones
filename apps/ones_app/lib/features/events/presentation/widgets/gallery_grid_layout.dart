double galleryGridWidth(double availableWidth) {
  if (!availableWidth.isFinite) return 1600;
  return availableWidth.clamp(0, 1600).toDouble();
}

int galleryCardColumns(double availableWidth) {
  const spacing = 12.0;
  const minCardWidth = 280.0;
  final width = galleryGridWidth(availableWidth);
  return ((width + spacing) / (minCardWidth + spacing)).floor().clamp(1, 5);
}

int eventPhotoGridColumns(double availableWidth) {
  const spacing = 1.0;
  const minTileWidth = 220.0;
  return ((availableWidth + spacing) / (minTileWidth + spacing))
      .floor()
      .clamp(3, 8);
}

double eventPhotoGridAspectRatio(double availableWidth) {
  if (availableWidth < 600) return 0.82;
  if (availableWidth < 1200) return 0.95;
  return 1.05;
}
