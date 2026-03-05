import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PhotoStorage {
  Future<Directory> _baseDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final base = Directory(p.join(dir.path, 'photos'));
    if (!await base.exists()) {
      await base.create(recursive: true);
    }
    return base;
  }

  Future<File> saveJpeg({
    required String eventId,
    required String photoId,
    required File source,
  }) async {
    final base = await _baseDir();
    final targetDir = Directory(p.join(base.path, eventId));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final target = File(p.join(targetDir.path, '$photoId.jpg'));
    await source.copy(target.path);
    return target;
  }

  Future<File> getFile({required String eventId, required String photoId}) async {
    final base = await _baseDir();
    return File(p.join(base.path, eventId, '$photoId.jpg'));
  }
}
