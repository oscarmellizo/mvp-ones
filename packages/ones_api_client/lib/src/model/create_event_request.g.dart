// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_event_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$CreateEventRequest extends CreateEventRequest {
  @override
  final String title;
  @override
  final String eventTypeId;
  @override
  final String location;
  @override
  final DateTime startAt;
  @override
  final DateTime endAt;

  factory _$CreateEventRequest(
          [void Function(CreateEventRequestBuilder)? updates]) =>
      (new CreateEventRequestBuilder()..update(updates))._build();

  _$CreateEventRequest._(
      {required this.title,
      required this.eventTypeId,
      required this.location,
      required this.startAt,
      required this.endAt})
      : super._() {
    BuiltValueNullFieldError.checkNotNull(
        title, r'CreateEventRequest', 'title');
    BuiltValueNullFieldError.checkNotNull(
        eventTypeId, r'CreateEventRequest', 'eventTypeId');
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
        eventTypeId == other.eventTypeId &&
        location == other.location &&
        startAt == other.startAt &&
        endAt == other.endAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, title.hashCode);
    _$hash = $jc(_$hash, eventTypeId.hashCode);
    _$hash = $jc(_$hash, location.hashCode);
    _$hash = $jc(_$hash, startAt.hashCode);
    _$hash = $jc(_$hash, endAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'CreateEventRequest')
          ..add('title', title)
          ..add('eventTypeId', eventTypeId)
          ..add('location', location)
          ..add('startAt', startAt)
          ..add('endAt', endAt))
        .toString();
  }
}

class CreateEventRequestBuilder
    implements Builder<CreateEventRequest, CreateEventRequestBuilder> {
  _$CreateEventRequest? _$v;

  String? _title;
  String? get title => _$this._title;
  set title(String? title) => _$this._title = title;

  String? _eventTypeId;
  String? get eventTypeId => _$this._eventTypeId;
  set eventTypeId(String? eventTypeId) => _$this._eventTypeId = eventTypeId;

  String? _location;
  String? get location => _$this._location;
  set location(String? location) => _$this._location = location;

  DateTime? _startAt;
  DateTime? get startAt => _$this._startAt;
  set startAt(DateTime? startAt) => _$this._startAt = startAt;

  DateTime? _endAt;
  DateTime? get endAt => _$this._endAt;
  set endAt(DateTime? endAt) => _$this._endAt = endAt;

  CreateEventRequestBuilder() {
    CreateEventRequest._defaults(this);
  }

  CreateEventRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _title = $v.title;
      _eventTypeId = $v.eventTypeId;
      _location = $v.location;
      _startAt = $v.startAt;
      _endAt = $v.endAt;
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
            eventTypeId: BuiltValueNullFieldError.checkNotNull(
                eventTypeId, r'CreateEventRequest', 'eventTypeId'),
            location: BuiltValueNullFieldError.checkNotNull(
                location, r'CreateEventRequest', 'location'),
            startAt: BuiltValueNullFieldError.checkNotNull(
                startAt, r'CreateEventRequest', 'startAt'),
            endAt: BuiltValueNullFieldError.checkNotNull(
                endAt, r'CreateEventRequest', 'endAt'));
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
