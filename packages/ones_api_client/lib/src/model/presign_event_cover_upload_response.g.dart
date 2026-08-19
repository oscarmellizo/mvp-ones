// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'presign_event_cover_upload_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PresignEventCoverUploadResponse
    extends PresignEventCoverUploadResponse {
  @override
  final String uploadUrl;
  @override
  final String uploadKey;
  @override
  final DateTime expiresAt;

  factory _$PresignEventCoverUploadResponse(
          [void Function(PresignEventCoverUploadResponseBuilder)? updates]) =>
      (new PresignEventCoverUploadResponseBuilder()..update(updates))._build();

  _$PresignEventCoverUploadResponse._(
      {required this.uploadUrl,
      required this.uploadKey,
      required this.expiresAt})
      : super._() {
    BuiltValueNullFieldError.checkNotNull(
        uploadUrl, r'PresignEventCoverUploadResponse', 'uploadUrl');
    BuiltValueNullFieldError.checkNotNull(
        uploadKey, r'PresignEventCoverUploadResponse', 'uploadKey');
    BuiltValueNullFieldError.checkNotNull(
        expiresAt, r'PresignEventCoverUploadResponse', 'expiresAt');
  }

  @override
  PresignEventCoverUploadResponse rebuild(
          void Function(PresignEventCoverUploadResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PresignEventCoverUploadResponseBuilder toBuilder() =>
      new PresignEventCoverUploadResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PresignEventCoverUploadResponse &&
        uploadUrl == other.uploadUrl &&
        uploadKey == other.uploadKey &&
        expiresAt == other.expiresAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, uploadUrl.hashCode);
    _$hash = $jc(_$hash, uploadKey.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PresignEventCoverUploadResponse')
          ..add('uploadUrl', uploadUrl)
          ..add('uploadKey', uploadKey)
          ..add('expiresAt', expiresAt))
        .toString();
  }
}

class PresignEventCoverUploadResponseBuilder
    implements
        Builder<PresignEventCoverUploadResponse,
            PresignEventCoverUploadResponseBuilder> {
  _$PresignEventCoverUploadResponse? _$v;

  String? _uploadUrl;
  String? get uploadUrl => _$this._uploadUrl;
  set uploadUrl(String? uploadUrl) => _$this._uploadUrl = uploadUrl;

  String? _uploadKey;
  String? get uploadKey => _$this._uploadKey;
  set uploadKey(String? uploadKey) => _$this._uploadKey = uploadKey;

  DateTime? _expiresAt;
  DateTime? get expiresAt => _$this._expiresAt;
  set expiresAt(DateTime? expiresAt) => _$this._expiresAt = expiresAt;

  PresignEventCoverUploadResponseBuilder() {
    PresignEventCoverUploadResponse._defaults(this);
  }

  PresignEventCoverUploadResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _uploadUrl = $v.uploadUrl;
      _uploadKey = $v.uploadKey;
      _expiresAt = $v.expiresAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PresignEventCoverUploadResponse other) {
    ArgumentError.checkNotNull(other, 'other');
    _$v = other as _$PresignEventCoverUploadResponse;
  }

  @override
  void update(void Function(PresignEventCoverUploadResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PresignEventCoverUploadResponse build() => _build();

  _$PresignEventCoverUploadResponse _build() {
    final _$result = _$v ??
        new _$PresignEventCoverUploadResponse._(
            uploadUrl: BuiltValueNullFieldError.checkNotNull(
                uploadUrl, r'PresignEventCoverUploadResponse', 'uploadUrl'),
            uploadKey: BuiltValueNullFieldError.checkNotNull(
                uploadKey, r'PresignEventCoverUploadResponse', 'uploadKey'),
            expiresAt: BuiltValueNullFieldError.checkNotNull(
                expiresAt, r'PresignEventCoverUploadResponse', 'expiresAt'));
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
