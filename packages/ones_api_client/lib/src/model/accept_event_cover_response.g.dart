// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accept_event_cover_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AcceptEventCoverResponse extends AcceptEventCoverResponse {
  @override
  final String reservationId;

  factory _$AcceptEventCoverResponse(
          [void Function(AcceptEventCoverResponseBuilder)? updates]) =>
      (new AcceptEventCoverResponseBuilder()..update(updates))._build();

  _$AcceptEventCoverResponse._({required this.reservationId}) : super._() {
    BuiltValueNullFieldError.checkNotNull(
        reservationId, r'AcceptEventCoverResponse', 'reservationId');
  }

  @override
  AcceptEventCoverResponse rebuild(
          void Function(AcceptEventCoverResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  AcceptEventCoverResponseBuilder toBuilder() =>
      new AcceptEventCoverResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AcceptEventCoverResponse &&
        reservationId == other.reservationId;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, reservationId.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AcceptEventCoverResponse')
          ..add('reservationId', reservationId))
        .toString();
  }
}

class AcceptEventCoverResponseBuilder
    implements
        Builder<AcceptEventCoverResponse, AcceptEventCoverResponseBuilder> {
  _$AcceptEventCoverResponse? _$v;

  String? _reservationId;
  String? get reservationId => _$this._reservationId;
  set reservationId(String? reservationId) =>
      _$this._reservationId = reservationId;

  AcceptEventCoverResponseBuilder() {
    AcceptEventCoverResponse._defaults(this);
  }

  AcceptEventCoverResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _reservationId = $v.reservationId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AcceptEventCoverResponse other) {
    ArgumentError.checkNotNull(other, 'other');
    _$v = other as _$AcceptEventCoverResponse;
  }

  @override
  void update(void Function(AcceptEventCoverResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AcceptEventCoverResponse build() => _build();

  _$AcceptEventCoverResponse _build() {
    final _$result = _$v ??
        new _$AcceptEventCoverResponse._(
            reservationId: BuiltValueNullFieldError.checkNotNull(
                reservationId, r'AcceptEventCoverResponse', 'reservationId'));
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
