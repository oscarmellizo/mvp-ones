// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_photo_list_item.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$EventPhotoListItem extends EventPhotoListItem {
  @override
  final String photoId;
  @override
  final String? guestId;
  @override
  final DateTime createdAt;
  @override
  final DateTime? uploadedAt;
  @override
  final String status;
  @override
  final String? originalUrl;
  @override
  final String? mediumUrl;
  @override
  final String? smallUrl;
  @override
  final bool shared;
  @override
  final String? ownerName;
  @override
  final String? sharedByUserId;
  @override
  final String? sharedByName;

  factory _$EventPhotoListItem(
          [void Function(EventPhotoListItemBuilder)? updates]) =>
      (new EventPhotoListItemBuilder()..update(updates))._build();

  _$EventPhotoListItem._(
      {required this.photoId,
      this.guestId,
      required this.createdAt,
      this.uploadedAt,
      required this.status,
      this.originalUrl,
      this.mediumUrl,
      this.smallUrl,
      required this.shared,
      this.ownerName,
      this.sharedByUserId,
      this.sharedByName})
      : super._() {
    BuiltValueNullFieldError.checkNotNull(
        photoId, r'EventPhotoListItem', 'photoId');
    BuiltValueNullFieldError.checkNotNull(
        createdAt, r'EventPhotoListItem', 'createdAt');
    BuiltValueNullFieldError.checkNotNull(
        status, r'EventPhotoListItem', 'status');
    BuiltValueNullFieldError.checkNotNull(
        shared, r'EventPhotoListItem', 'shared');
  }

  @override
  EventPhotoListItem rebuild(
          void Function(EventPhotoListItemBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  EventPhotoListItemBuilder toBuilder() =>
      new EventPhotoListItemBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is EventPhotoListItem &&
        photoId == other.photoId &&
        guestId == other.guestId &&
        createdAt == other.createdAt &&
        uploadedAt == other.uploadedAt &&
        status == other.status &&
        originalUrl == other.originalUrl &&
        mediumUrl == other.mediumUrl &&
        smallUrl == other.smallUrl &&
        shared == other.shared &&
        ownerName == other.ownerName &&
        sharedByUserId == other.sharedByUserId &&
        sharedByName == other.sharedByName;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, photoId.hashCode);
    _$hash = $jc(_$hash, guestId.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jc(_$hash, uploadedAt.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, originalUrl.hashCode);
    _$hash = $jc(_$hash, mediumUrl.hashCode);
    _$hash = $jc(_$hash, smallUrl.hashCode);
    _$hash = $jc(_$hash, shared.hashCode);
    _$hash = $jc(_$hash, ownerName.hashCode);
    _$hash = $jc(_$hash, sharedByUserId.hashCode);
    _$hash = $jc(_$hash, sharedByName.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'EventPhotoListItem')
          ..add('photoId', photoId)
          ..add('guestId', guestId)
          ..add('createdAt', createdAt)
          ..add('uploadedAt', uploadedAt)
          ..add('status', status)
          ..add('originalUrl', originalUrl)
          ..add('mediumUrl', mediumUrl)
          ..add('smallUrl', smallUrl)
          ..add('shared', shared)
          ..add('ownerName', ownerName)
          ..add('sharedByUserId', sharedByUserId)
          ..add('sharedByName', sharedByName))
        .toString();
  }
}

class EventPhotoListItemBuilder
    implements Builder<EventPhotoListItem, EventPhotoListItemBuilder> {
  _$EventPhotoListItem? _$v;

  String? _photoId;
  String? get photoId => _$this._photoId;
  set photoId(String? photoId) => _$this._photoId = photoId;

  String? _guestId;
  String? get guestId => _$this._guestId;
  set guestId(String? guestId) => _$this._guestId = guestId;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  DateTime? _uploadedAt;
  DateTime? get uploadedAt => _$this._uploadedAt;
  set uploadedAt(DateTime? uploadedAt) => _$this._uploadedAt = uploadedAt;

  String? _status;
  String? get status => _$this._status;
  set status(String? status) => _$this._status = status;

  String? _originalUrl;
  String? get originalUrl => _$this._originalUrl;
  set originalUrl(String? originalUrl) => _$this._originalUrl = originalUrl;

  String? _mediumUrl;
  String? get mediumUrl => _$this._mediumUrl;
  set mediumUrl(String? mediumUrl) => _$this._mediumUrl = mediumUrl;

  String? _smallUrl;
  String? get smallUrl => _$this._smallUrl;
  set smallUrl(String? smallUrl) => _$this._smallUrl = smallUrl;

  bool? _shared;
  bool? get shared => _$this._shared;
  set shared(bool? shared) => _$this._shared = shared;

  String? _ownerName;
  String? get ownerName => _$this._ownerName;
  set ownerName(String? ownerName) => _$this._ownerName = ownerName;

  String? _sharedByUserId;
  String? get sharedByUserId => _$this._sharedByUserId;
  set sharedByUserId(String? sharedByUserId) =>
      _$this._sharedByUserId = sharedByUserId;

  String? _sharedByName;
  String? get sharedByName => _$this._sharedByName;
  set sharedByName(String? sharedByName) => _$this._sharedByName = sharedByName;

  EventPhotoListItemBuilder() {
    EventPhotoListItem._defaults(this);
  }

  EventPhotoListItemBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _photoId = $v.photoId;
      _guestId = $v.guestId;
      _createdAt = $v.createdAt;
      _uploadedAt = $v.uploadedAt;
      _status = $v.status;
      _originalUrl = $v.originalUrl;
      _mediumUrl = $v.mediumUrl;
      _smallUrl = $v.smallUrl;
      _shared = $v.shared;
      _ownerName = $v.ownerName;
      _sharedByUserId = $v.sharedByUserId;
      _sharedByName = $v.sharedByName;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(EventPhotoListItem other) {
    ArgumentError.checkNotNull(other, 'other');
    _$v = other as _$EventPhotoListItem;
  }

  @override
  void update(void Function(EventPhotoListItemBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  EventPhotoListItem build() => _build();

  _$EventPhotoListItem _build() {
    final _$result = _$v ??
        new _$EventPhotoListItem._(
            photoId: BuiltValueNullFieldError.checkNotNull(
                photoId, r'EventPhotoListItem', 'photoId'),
            guestId: guestId,
            createdAt: BuiltValueNullFieldError.checkNotNull(
                createdAt, r'EventPhotoListItem', 'createdAt'),
            uploadedAt: uploadedAt,
            status: BuiltValueNullFieldError.checkNotNull(
                status, r'EventPhotoListItem', 'status'),
            originalUrl: originalUrl,
            mediumUrl: mediumUrl,
            smallUrl: smallUrl,
            shared: BuiltValueNullFieldError.checkNotNull(
                shared, r'EventPhotoListItem', 'shared'),
            ownerName: ownerName,
            sharedByUserId: sharedByUserId,
            sharedByName: sharedByName);
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
