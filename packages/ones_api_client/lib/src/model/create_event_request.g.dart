// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_event_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$CreateEventRequest extends CreateEventRequest {
  @override
  final String title;
  @override
  final String objective;
  @override
  final String location;
  @override
  final DateTime startAt;
  @override
  final DateTime endAt;
  @override
  final String? coverReservationId;

  factory _$CreateEventRequest(
          [void Function(CreateEventRequestBuilder)? updates]) =>
      (new CreateEventRequestBuilder()..update(updates))._build();

  _$CreateEventRequest._(
      {required this.title,
      required this.objective,
      required this.location,
      required this.startAt,
      required this.endAt,
      this.coverReservationId})
      : super._() {
    BuiltValueNullFieldError.checkNotNull(
        title, r'CreateEventRequest', 'title');
    BuiltValueNullFieldError.checkNotNull(
        objective, r'CreateEventRequest', 'objective');
    BuiltValueNullFieldError.checkNotNull(
        location, r'CreateEventRequest', 'location');
    BuiltValueNullFieldError.checkNotNull(
        startAt, r'CreateEventRequest', 'startAt');
    BuiltValueNullFieldError.checkNotNull(
        endAt, r'CreateEventRequest', 'endAt');
  }

  @override
  CreateEventRequest rebuild(
          void Function(CreateEventRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  CreateEventRequestBuilder toBuilder() =>
      new CreateEventRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CreateEventRequest &&
        title == other.title &&
        objective == other.objective &&
        location == other.location &&
        startAt == other.startAt &&
        endAt == other.endAt &&
        coverReservationId == other.coverReservationId;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, title.hashCode);
    _$hash = $jc(_$hash, objective.hashCode);
    _$hash = $jc(_$hash, location.hashCode);
    _$hash = $jc(_$hash, startAt.hashCode);
    _$hash = $jc(_$hash, endAt.hashCode);
    _$hash = $jc(_$hash, coverReservationId.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'CreateEventRequest')
          ..add('title', title)
          ..add('objective', objective)
          ..add('location', location)
          ..add('startAt', startAt)
          ..add('endAt', endAt)
          ..add('coverReservationId', coverReservationId))
        .toString();
  }
}

class CreateEventRequestBuilder
    implements Builder<CreateEventRequest, CreateEventRequestBuilder> {
  _$CreateEventRequest? _$v;

  String? _title;
  String? get title => _$this._title;
  set title(String? title) => _$this._title = title;

  String? _objective;
  String? get objective => _$this._objective;
  set objective(String? objective) => _$this._objective = objective;

  String? _location;
  String? get location => _$this._location;
  set location(String? location) => _$this._location = location;

  DateTime? _startAt;
  DateTime? get startAt => _$this._startAt;
  set startAt(DateTime? startAt) => _$this._startAt = startAt;

  DateTime? _endAt;
  DateTime? get endAt => _$this._endAt;
  set endAt(DateTime? endAt) => _$this._endAt = endAt;

  String? _coverReservationId;
  String? get coverReservationId => _$this._coverReservationId;
  set coverReservationId(String? coverReservationId) =>
      _$this._coverReservationId = coverReservationId;

  CreateEventRequestBuilder() {
    CreateEventRequest._defaults(this);
  }

  CreateEventRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _title = $v.title;
      _objective = $v.objective;
      _location = $v.location;
      _startAt = $v.startAt;
      _endAt = $v.endAt;
      _coverReservationId = $v.coverReservationId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CreateEventRequest other) {
    ArgumentError.checkNotNull(other, 'other');
    _$v = other as _$CreateEventRequest;
  }

  @override
  void update(void Function(CreateEventRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  CreateEventRequest build() => _build();

  _$CreateEventRequest _build() {
    final _$result = _$v ??
        new _$CreateEventRequest._(
            title: BuiltValueNullFieldError.checkNotNull(
                title, r'CreateEventRequest', 'title'),
            objective: BuiltValueNullFieldError.checkNotNull(
                objective, r'CreateEventRequest', 'objective'),
            location: BuiltValueNullFieldError.checkNotNull(
                location, r'CreateEventRequest', 'location'),
            startAt: BuiltValueNullFieldError.checkNotNull(
                startAt, r'CreateEventRequest', 'startAt'),
            endAt: BuiltValueNullFieldError.checkNotNull(
                endAt, r'CreateEventRequest', 'endAt'),
            coverReservationId: coverReservationId);
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
