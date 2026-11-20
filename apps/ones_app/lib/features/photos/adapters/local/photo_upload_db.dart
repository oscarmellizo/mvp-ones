import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/photo_upload_item.dart';

class PhotoUploadDb {
  static const _dbName = 'ones_photos.db';
  static const _dbVersion = 5;
  static const _table = 'photo_upload_queue';
  static const int _maxAttempts = 5;

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
  ownerId TEXT NOT NULL,
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
  originalFilename TEXT,
  metadataCreatedAt TEXT,
  filenameCreatedAt TEXT,
  createdAtSource TEXT,
  deviceUtcOffsetMinutes INTEGER,
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
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE $_table ADD COLUMN ownerId TEXT');
        }
        if (oldVersion < 4) {
          await db
              .execute('ALTER TABLE $_table ADD COLUMN originalFilename TEXT');
          await db
              .execute('ALTER TABLE $_table ADD COLUMN metadataCreatedAt TEXT');
          await db
              .execute('ALTER TABLE $_table ADD COLUMN filenameCreatedAt TEXT');
          await db.execute(
              'ALTER TABLE $_table ADD COLUMN deviceUtcOffsetMinutes INTEGER');
        }
        if (oldVersion < 5) {
          await db
              .execute('ALTER TABLE $_table ADD COLUMN createdAtSource TEXT');
        }
      },
    );

    _db = db;
    return db;
  }

  Future<int> enqueue({
    required String ownerId,
    required String eventId,
    required String photoId,
    required String localPath,
    required String contentType,
    required String createdAt,
    String? frameId,
    String? orientation,
    String? cameraType,
    String? originalFilename,
    String? metadataCreatedAt,
    String? filenameCreatedAt,
    String? createdAtSource,
    int? deviceUtcOffsetMinutes,
  }) async {
    final db = await _open();
    final now = DateTime.now().toUtc().toIso8601String();

    return db.insert(
      _table,
      {
        'ownerId': ownerId,
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
        'originalFilename': originalFilename,
        'metadataCreatedAt': metadataCreatedAt,
        'filenameCreatedAt': filenameCreatedAt,
        'createdAtSource': createdAtSource,
        'deviceUtcOffsetMinutes': deviceUtcOffsetMinutes,
        'attempts': 0,
        'lastError': null,
        'updatedAt': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> clearAll() async {
    final db = await _open();
    await db.delete(_table);
  }

  Future<List<PhotoUploadItem>> listPending({
    required String ownerId,
    int limit = 10,
  }) async {
    final db = await _open();
    final rows = await db.query(
      _table,
      where: "ownerId = ? AND status = 'pending'",
      whereArgs: [ownerId],
      orderBy: 'updatedAt ASC',
      limit: limit,
    );

    return rows.map(_map).toList(growable: false);
  }

  Future<List<PhotoUploadItem>> listActiveByEvent({
    required String eventId,
    required String ownerId,
    int limit = 100,
  }) async {
    final db = await _open();
    final rows = await db.query(
      _table,
      where:
          "eventId = ? AND ownerId = ? AND status IN ('pending','uploading','processing','uploaded','failed','missing_file')",
      whereArgs: [eventId, ownerId],
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    return rows.map(_map).toList(growable: false);
  }

  Future<bool> hasActiveForEvent({required String eventId}) async {
    final db = await _open();
    final rows = await db.query(
      _table,
      columns: ['id'],
      where:
          "eventId = ? AND status IN ('pending','uploading','processing','uploaded','failed','missing_file')",
      whereArgs: [eventId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<PhotoUploadItem>> listActive({
    required String ownerId,
    int limit = 500,
  }) async {
    final db = await _open();
    final rows = await db.query(
      _table,
      where:
          "ownerId = ? AND status IN ('pending','uploading','processing','uploaded','failed','missing_file')",
      whereArgs: [ownerId],
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

  Future<void> markProcessing(int id) async {
    final db = await _open();
    await db.update(
      _table,
      {
        'status': 'processing',
        'lastError': null,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> purgeStale(
      {Duration olderThan = const Duration(hours: 1)}) async {
    final db = await _open();
    final cutoff = DateTime.now().toUtc().subtract(olderThan).toIso8601String();
    return db.update(
      _table,
      {
        'status': 'pending',
        'lastError': 'stale_upload_requeued',
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: "status IN ('uploading') AND updatedAt < ?",
      whereArgs: [cutoff],
    );
  }

  Future<void> deleteByPhotoId(
    String photoId, {
    required String ownerId,
  }) async {
    if (photoId.isEmpty || ownerId.isEmpty) return;
    final db = await _open();
    await db.delete(
      _table,
      where: 'photoId = ? AND ownerId = ?',
      whereArgs: [photoId, ownerId],
    );
  }

  Future<void> retryFailedByPhotoId(
    String photoId, {
    required String ownerId,
  }) async {
    if (photoId.isEmpty || ownerId.isEmpty) return;
    final db = await _open();
    await db.update(
      _table,
      {
        'status': 'pending',
        'lastError': null,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: "photoId = ? AND ownerId = ? AND status = 'failed'",
      whereArgs: [photoId, ownerId],
    );
  }

  Future<void> bindLegacyItems({required String ownerId}) async {
    if (ownerId.isEmpty) return;
    final db = await _open();
    await db.update(
      _table,
      {'ownerId': ownerId},
      where: 'ownerId IS NULL',
    );
  }

  Future<void> markLocalFileMissing(int id) async {
    final db = await _open();
    await db.update(
      _table,
      {
        'status': 'missing_file',
        'lastError': 'local_file_missing',
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
    final nextAttempts = attempts + 1;
    final newStatus = nextAttempts >= _maxAttempts ? 'failed' : 'pending';

    await db.update(
      _table,
      {
        'status': newStatus,
        'attempts': nextAttempts,
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
      ownerId: row['ownerId'] as String?,
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
      originalFilename: row['originalFilename'] as String?,
      metadataCreatedAt: row['metadataCreatedAt'] as String?,
      filenameCreatedAt: row['filenameCreatedAt'] as String?,
      createdAtSource: row['createdAtSource'] as String?,
      deviceUtcOffsetMinutes: row['deviceUtcOffsetMinutes'] as int?,
      attempts: (row['attempts'] as int?) ?? 0,
      lastError: row['lastError'] as String?,
    );
  }
}
