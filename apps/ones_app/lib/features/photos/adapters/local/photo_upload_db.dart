import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/photo_upload_item.dart';

class PhotoUploadDb {
  static const _dbName = 'ones_photos.db';
  static const _dbVersion = 2;
  static const _table = 'photo_upload_queue';

  Database? _db;

  Future<Database> _open() async {
    final existing = _db;
    if (existing != null) return existing;

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);

    final db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE $_table (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  eventId TEXT NOT NULL,
  photoId TEXT NOT NULL,
  localPath TEXT NOT NULL,
  contentType TEXT NOT NULL,
  status TEXT NOT NULL,
  createdAt TEXT NOT NULL,
  s3KeyOriginal TEXT,
  frameId TEXT,
  orientation TEXT,
  cameraType TEXT,
  attempts INTEGER NOT NULL,
  lastError TEXT,
  updatedAt TEXT NOT NULL
);
''');
        await db.execute(
            'CREATE INDEX idx_photo_upload_queue_status ON $_table(status, updatedAt)');
        await db.execute(
            'CREATE UNIQUE INDEX idx_photo_upload_queue_photoId ON $_table(photoId)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE $_table ADD COLUMN frameId TEXT');
          await db.execute('ALTER TABLE $_table ADD COLUMN orientation TEXT');
          await db.execute('ALTER TABLE $_table ADD COLUMN cameraType TEXT');
        }
      },
    );

    _db = db;
    return db;
  }

  Future<int> enqueue({
    required String eventId,
    required String photoId,
    required String localPath,
    required String contentType,
    required String createdAt,
    String? frameId,
    String? orientation,
    String? cameraType,
  }) async {
    final db = await _open();
    final now = DateTime.now().toUtc().toIso8601String();

    return db.insert(
      _table,
      {
        'eventId': eventId,
        'photoId': photoId,
        'localPath': localPath,
        'contentType': contentType,
        'status': 'pending',
        'createdAt': createdAt,
        's3KeyOriginal': null,
        'frameId': frameId,
        'orientation': orientation,
        'cameraType': cameraType,
        'attempts': 0,
        'lastError': null,
        'updatedAt': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<PhotoUploadItem>> listPending({int limit = 10}) async {
    final db = await _open();
    final rows = await db.query(
      _table,
      where: "status IN ('pending','failed')",
      orderBy: 'updatedAt ASC',
      limit: limit,
    );

    return rows.map(_map).toList(growable: false);
  }

  Future<List<PhotoUploadItem>> listActiveByEvent({
    required String eventId,
    int limit = 100,
  }) async {
    final db = await _open();
    final rows = await db.query(
      _table,
      where: "eventId = ? AND status IN ('pending','uploading')",
      whereArgs: [eventId],
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    return rows.map(_map).toList(growable: false);
  }

  Future<void> markUploading(int id) async {
    final db = await _open();
    await db.update(
      _table,
      {
        'status': 'uploading',
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markPresigned(int id, {required String s3KeyOriginal}) async {
    final db = await _open();
    await db.update(
      _table,
      {
        's3KeyOriginal': s3KeyOriginal,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markUploaded(int id) async {
    final db = await _open();
    await db.update(
      _table,
      {
        'status': 'uploaded',
        'lastError': null,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markFailed(int id, {required String error}) async {
    final db = await _open();

    final current = await db.query(
      _table,
      columns: ['attempts'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    final attempts =
        (current.isNotEmpty ? (current.first['attempts'] as int?) : null) ?? 0;

    await db.update(
      _table,
      {
        'status': 'pending',
        'attempts': attempts + 1,
        'lastError': error,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  PhotoUploadItem _map(Map<String, Object?> row) {
    return PhotoUploadItem(
      id: row['id'] as int,
      eventId: row['eventId'] as String,
      photoId: row['photoId'] as String,
      localPath: row['localPath'] as String,
      contentType: row['contentType'] as String,
      status: row['status'] as String,
      createdAt: row['createdAt'] as String,
      s3KeyOriginal: row['s3KeyOriginal'] as String?,
      frameId: row['frameId'] as String?,
      orientation: row['orientation'] as String?,
      cameraType: row['cameraType'] as String?,
      attempts: (row['attempts'] as int?) ?? 0,
      lastError: row['lastError'] as String?,
    );
  }
}
