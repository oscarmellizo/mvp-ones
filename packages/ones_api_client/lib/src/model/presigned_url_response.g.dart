// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'presigned_url_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PresignedUrlResponse extends PresignedUrlResponse {
  @override
  final String url;
  @override
  final DateTime expiresAt;

  factory _$PresignedUrlResponse(
          [void Function(PresignedUrlResponseBuilder)? updates]) =>
      (new PresignedUrlResponseBuilder()..update(updates))._build();

  _$PresignedUrlResponse._({required this.url, required this.expiresAt})
      : super._() {
    BuiltValueNullFieldError.checkNotNull(url, r'PresignedUrlResponse', 'url');
    BuiltValueNullFieldError.checkNotNull(
        expiresAt, r'PresignedUrlResponse', 'expiresAt');
  }

  @override
  PresignedUrlResponse rebuild(
          void Function(PresignedUrlResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PresignedUrlResponseBuilder toBuilder() =>
      new PresignedUrlResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PresignedUrlResponse &&
        url == other.url &&
        expiresAt == other.expiresAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, url.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PresignedUrlResponse')
          ..add('url', url)
          ..add('expiresAt', expiresAt))
        .toString();
  }
}

class PresignedUrlResponseBuilder
    implements Builder<PresignedUrlResponse, PresignedUrlResponseBuilder> {
  _$PresignedUrlResponse? _$v;

  String? _url;
  String? get url => _$this._url;
  set url(String? url) => _$this._url = url;

  DateTime? _expiresAt;
  DateTime? get expiresAt => _$this._expiresAt;
  set expiresAt(DateTime? expiresAt) => _$this._expiresAt = expiresAt;

  PresignedUrlResponseBuilder() {
    PresignedUrlResponse._defaults(this);
  }

  PresignedUrlResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _url = $v.url;
      _expiresAt = $v.expiresAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PresignedUrlResponse other) {
    ArgumentError.checkNotNull(other, 'other');
    _$v = other as _$PresignedUrlResponse;
  }

  @override
  void update(void Function(PresignedUrlResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PresignedUrlResponse build() => _build();

  _$PresignedUrlResponse _build() {
    final _$result = _$v ??
        new _$PresignedUrlResponse._(
            url: BuiltValueNullFieldError.checkNotNull(
                url, r'PresignedUrlResponse', 'url'),
            expiresAt: BuiltValueNullFieldError.checkNotNull(
                expiresAt, r'PresignedUrlResponse', 'expiresAt'));
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
