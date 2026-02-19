// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'generate_event_cover_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$GenerateEventCoverResponse extends GenerateEventCoverResponse {
  @override
  final String coverId;
  @override
  final String previewUrl;
  @override
  final DateTime expiresAt;

  factory _$GenerateEventCoverResponse(
          [void Function(GenerateEventCoverResponseBuilder)? updates]) =>
      (new GenerateEventCoverResponseBuilder()..update(updates))._build();

  _$GenerateEventCoverResponse._(
      {required this.coverId,
      required this.previewUrl,
      required this.expiresAt})
      : super._() {
    BuiltValueNullFieldError.checkNotNull(
        coverId, r'GenerateEventCoverResponse', 'coverId');
    BuiltValueNullFieldError.checkNotNull(
        previewUrl, r'GenerateEventCoverResponse', 'previewUrl');
    BuiltValueNullFieldError.checkNotNull(
        expiresAt, r'GenerateEventCoverResponse', 'expiresAt');
  }

  @override
  GenerateEventCoverResponse rebuild(
          void Function(GenerateEventCoverResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  GenerateEventCoverResponseBuilder toBuilder() =>
      new GenerateEventCoverResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is GenerateEventCoverResponse &&
        coverId == other.coverId &&
        previewUrl == other.previewUrl &&
        expiresAt == other.expiresAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, coverId.hashCode);
    _$hash = $jc(_$hash, previewUrl.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'GenerateEventCoverResponse')
          ..add('coverId', coverId)
          ..add('previewUrl', previewUrl)
          ..add('expiresAt', expiresAt))
        .toString();
  }
}

class GenerateEventCoverResponseBuilder
    implements
        Builder<GenerateEventCoverResponse, GenerateEventCoverResponseBuilder> {
  _$GenerateEventCoverResponse? _$v;

  String? _coverId;
  String? get coverId => _$this._coverId;
  set coverId(String? coverId) => _$this._coverId = coverId;

  String? _previewUrl;
  String? get previewUrl => _$this._previewUrl;
  set previewUrl(String? previewUrl) => _$this._previewUrl = previewUrl;

  DateTime? _expiresAt;
  DateTime? get expiresAt => _$this._expiresAt;
  set expiresAt(DateTime? expiresAt) => _$this._expiresAt = expiresAt;

  GenerateEventCoverResponseBuilder() {
    GenerateEventCoverResponse._defaults(this);
  }

  GenerateEventCoverResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _coverId = $v.coverId;
      _previewUrl = $v.previewUrl;
      _expiresAt = $v.expiresAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(GenerateEventCoverResponse other) {
    ArgumentError.checkNotNull(other, 'other');
    _$v = other as _$GenerateEventCoverResponse;
  }

  @override
  void update(void Function(GenerateEventCoverResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  GenerateEventCoverResponse build() => _build();

  _$GenerateEventCoverResponse _build() {
    final _$result = _$v ??
        new _$GenerateEventCoverResponse._(
            coverId: BuiltValueNullFieldError.checkNotNull(
                coverId, r'GenerateEventCoverResponse', 'coverId'),
            previewUrl: BuiltValueNullFieldError.checkNotNull(
                previewUrl, r'GenerateEventCoverResponse', 'previewUrl'),
            expiresAt: BuiltValueNullFieldError.checkNotNull(
                expiresAt, r'GenerateEventCoverResponse', 'expiresAt'));
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
