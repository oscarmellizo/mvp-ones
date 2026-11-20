import 'package:flutter/services.dart';

class IosPhotoLibraryPicker {
  static const MethodChannel _channel = MethodChannel('ones/photo_library');

  Future<List<IosPickedPhoto>> pickImages({int limit = 15}) async {
    final result = await _channel.invokeListMethod<Object?>(
      'pickImages',
      {'limit': limit},
    );
    if (result == null) return const [];

    return result
        .whereType<Map<Object?, Object?>>()
        .map((row) {
          final name = row['name'];
          final path = row['path'];
          return IosPickedPhoto(
            name: name is String ? name : 'photo.jpg',
            path: path is String ? path : '',
          );
        })
        .where((photo) => photo.path.isNotEmpty)
        .toList(growable: false);
  }
}

class IosPickedPhoto {
  final String name;
  final String path;

  const IosPickedPhoto({required this.name, required this.path});
}
