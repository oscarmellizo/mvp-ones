// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'generate_event_cover_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$GenerateEventCoverRequest extends GenerateEventCoverRequest {
  @override
  final String eventName;
  @override
  final String categoryLabel;
  @override
  final String eventTypeLabel;
  @override
  final String location;
  @override
  final String? size;

  factory _$GenerateEventCoverRequest(
          [void Function(GenerateEventCoverRequestBuilder)? updates]) =>
      (new GenerateEventCoverRequestBuilder()..update(updates))._build();

  _$GenerateEventCoverRequest._(
      {required this.eventName,
      required this.categoryLabel,
      required this.eventTypeLabel,
      required this.location,
      this.size})
      : super._() {
    BuiltValueNullFieldError.checkNotNull(
        eventName, r'GenerateEventCoverRequest', 'eventName');
    BuiltValueNullFieldError.checkNotNull(
        categoryLabel, r'GenerateEventCoverRequest', 'categoryLabel');
    BuiltValueNullFieldError.checkNotNull(
        eventTypeLabel, r'GenerateEventCoverRequest', 'eventTypeLabel');
    BuiltValueNullFieldError.checkNotNull(
        location, r'GenerateEventCoverRequest', 'location');
  }

  @override
  GenerateEventCoverRequest rebuild(
          void Function(GenerateEventCoverRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  GenerateEventCoverRequestBuilder toBuilder() =>
      new GenerateEventCoverRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is GenerateEventCoverRequest &&
        eventName == other.eventName &&
        categoryLabel == other.categoryLabel &&
        eventTypeLabel == other.eventTypeLabel &&
        location == other.location &&
        size == other.size;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, eventName.hashCode);
    _$hash = $jc(_$hash, categoryLabel.hashCode);
    _$hash = $jc(_$hash, eventTypeLabel.hashCode);
    _$hash = $jc(_$hash, location.hashCode);
    _$hash = $jc(_$hash, size.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'GenerateEventCoverRequest')
          ..add('eventName', eventName)
          ..add('categoryLabel', categoryLabel)
          ..add('eventTypeLabel', eventTypeLabel)
          ..add('location', location)
          ..add('size', size))
        .toString();
  }
}

class GenerateEventCoverRequestBuilder
    implements
        Builder<GenerateEventCoverRequest, GenerateEventCoverRequestBuilder> {
  _$GenerateEventCoverRequest? _$v;

  String? _eventName;
  String? get eventName => _$this._eventName;
  set eventName(String? eventName) => _$this._eventName = eventName;

  String? _categoryLabel;
  String? get categoryLabel => _$this._categoryLabel;
  set categoryLabel(String? categoryLabel) =>
      _$this._categoryLabel = categoryLabel;

  String? _eventTypeLabel;
  String? get eventTypeLabel => _$this._eventTypeLabel;
  set eventTypeLabel(String? eventTypeLabel) =>
      _$this._eventTypeLabel = eventTypeLabel;

  String? _location;
  String? get location => _$this._location;
  set location(String? location) => _$this._location = location;

  String? _size;
  String? get size => _$this._size;
  set size(String? size) => _$this._size = size;

  GenerateEventCoverRequestBuilder() {
    GenerateEventCoverRequest._defaults(this);
  }

  GenerateEventCoverRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _eventName = $v.eventName;
      _categoryLabel = $v.categoryLabel;
      _eventTypeLabel = $v.eventTypeLabel;
      _location = $v.location;
      _size = $v.size;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(GenerateEventCoverRequest other) {
    ArgumentError.checkNotNull(other, 'other');
    _$v = other as _$GenerateEventCoverRequest;
  }

  @override
  void update(void Function(GenerateEventCoverRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  GenerateEventCoverRequest build() => _build();

  _$GenerateEventCoverRequest _build() {
    final _$result = _$v ??
        new _$GenerateEventCoverRequest._(
            eventName: BuiltValueNullFieldError.checkNotNull(
                eventName, r'GenerateEventCoverRequest', 'eventName'),
            categoryLabel: BuiltValueNullFieldError.checkNotNull(
                categoryLabel, r'GenerateEventCoverRequest', 'categoryLabel'),
            eventTypeLabel: BuiltValueNullFieldError.checkNotNull(
                eventTypeLabel, r'GenerateEventCoverRequest', 'eventTypeLabel'),
            location: BuiltValueNullFieldError.checkNotNull(
                location, r'GenerateEventCoverRequest', 'location'),
            size: size);
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
