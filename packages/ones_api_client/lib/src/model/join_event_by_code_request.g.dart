// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'join_event_by_code_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$JoinEventByCodeRequest extends JoinEventByCodeRequest {
  @override
  final String code;

  factory _$JoinEventByCodeRequest(
          [void Function(JoinEventByCodeRequestBuilder)? updates]) =>
      (new JoinEventByCodeRequestBuilder()..update(updates))._build();

  _$JoinEventByCodeRequest._({required this.code}) : super._() {
    BuiltValueNullFieldError.checkNotNull(
        code, r'JoinEventByCodeRequest', 'code');
  }

  @override
  JoinEventByCodeRequest rebuild(
          void Function(JoinEventByCodeRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  JoinEventByCodeRequestBuilder toBuilder() =>
      new JoinEventByCodeRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is JoinEventByCodeRequest && code == other.code;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, code.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'JoinEventByCodeRequest')
          ..add('code', code))
        .toString();
  }
}

class JoinEventByCodeRequestBuilder
    implements Builder<JoinEventByCodeRequest, JoinEventByCodeRequestBuilder> {
  _$JoinEventByCodeRequest? _$v;

  String? _code;
  String? get code => _$this._code;
  set code(String? code) => _$this._code = code;

  JoinEventByCodeRequestBuilder() {
    JoinEventByCodeRequest._defaults(this);
  }

  JoinEventByCodeRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _code = $v.code;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(JoinEventByCodeRequest other) {
    ArgumentError.checkNotNull(other, 'other');
    _$v = other as _$JoinEventByCodeRequest;
  }

  @override
  void update(void Function(JoinEventByCodeRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  JoinEventByCodeRequest build() => _build();

  _$JoinEventByCodeRequest _build() {
    final _$result = _$v ??
        new _$JoinEventByCodeRequest._(
            code: BuiltValueNullFieldError.checkNotNull(
                code, r'JoinEventByCodeRequest', 'code'));
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
