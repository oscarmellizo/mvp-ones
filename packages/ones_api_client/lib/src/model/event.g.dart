// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$Event extends Event {
  @override
  final String id;
  @override
  final String ownerId;
  @override
  final DateTime createdAt;
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
  final String? coverKey;

  factory _$Event([void Function(EventBuilder)? updates]) =>
      (new EventBuilder()..update(updates))._build();

  _$Event._(
      {required this.id,
      required this.ownerId,
      required this.createdAt,
      required this.title,
      required this.objective,
      required this.location,
      required this.startAt,
      required this.endAt,
      this.coverKey})
      : super._() {
    BuiltValueNullFieldError.checkNotNull(id, r'Event', 'id');
    BuiltValueNullFieldError.checkNotNull(ownerId, r'Event', 'ownerId');
    BuiltValueNullFieldError.checkNotNull(createdAt, r'Event', 'createdAt');
    BuiltValueNullFieldError.checkNotNull(title, r'Event', 'title');
    BuiltValueNullFieldError.checkNotNull(objective, r'Event', 'objective');
    BuiltValueNullFieldError.checkNotNull(location, r'Event', 'location');
    BuiltValueNullFieldError.checkNotNull(startAt, r'Event', 'startAt');
    BuiltValueNullFieldError.checkNotNull(endAt, r'Event', 'endAt');
  }

  @override
  Event rebuild(void Function(EventBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  EventBuilder toBuilder() => new EventBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Event &&
        id == other.id &&
        ownerId == other.ownerId &&
        createdAt == other.createdAt &&
        title == other.title &&
        objective == other.objective &&
        location == other.location &&
        startAt == other.startAt &&
        endAt == other.endAt &&
        coverKey == other.coverKey;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, ownerId.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jc(_$hash, title.hashCode);
    _$hash = $jc(_$hash, objective.hashCode);
    _$hash = $jc(_$hash, location.hashCode);
    _$hash = $jc(_$hash, startAt.hashCode);
    _$hash = $jc(_$hash, endAt.hashCode);
    _$hash = $jc(_$hash, coverKey.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Event')
          ..add('id', id)
          ..add('ownerId', ownerId)
          ..add('createdAt', createdAt)
          ..add('title', title)
          ..add('objective', objective)
          ..add('location', location)
          ..add('startAt', startAt)
          ..add('endAt', endAt)
          ..add('coverKey', coverKey))
        .toString();
  }
}

class EventBuilder implements Builder<Event, EventBuilder> {
  _$Event? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _ownerId;
  String? get ownerId => _$this._ownerId;
  set ownerId(String? ownerId) => _$this._ownerId = ownerId;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

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

  String? _coverKey;
  String? get coverKey => _$this._coverKey;
  set coverKey(String? coverKey) => _$this._coverKey = coverKey;

  EventBuilder() {
    Event._defaults(this);
  }

  EventBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _ownerId = $v.ownerId;
      _createdAt = $v.createdAt;
      _title = $v.title;
      _objective = $v.objective;
      _location = $v.location;
      _startAt = $v.startAt;
      _endAt = $v.endAt;
      _coverKey = $v.coverKey;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Event other) {
    ArgumentError.checkNotNull(other, 'other');
    _$v = other as _$Event;
  }

  @override
  void update(void Function(EventBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Event build() => _build();

  _$Event _build() {
    final _$result = _$v ??
        new _$Event._(
            id: BuiltValueNullFieldError.checkNotNull(id, r'Event', 'id'),
            ownerId: BuiltValueNullFieldError.checkNotNull(
                ownerId, r'Event', 'ownerId'),
            createdAt: BuiltValueNullFieldError.checkNotNull(
                createdAt, r'Event', 'createdAt'),
            title:
                BuiltValueNullFieldError.checkNotNull(title, r'Event', 'title'),
            objective: BuiltValueNullFieldError.checkNotNull(
                objective, r'Event', 'objective'),
            location: BuiltValueNullFieldError.checkNotNull(
                location, r'Event', 'location'),
            startAt: BuiltValueNullFieldError.checkNotNull(
                startAt, r'Event', 'startAt'),
            endAt:
                BuiltValueNullFieldError.checkNotNull(endAt, r'Event', 'endAt'),
            coverKey: coverKey);
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
