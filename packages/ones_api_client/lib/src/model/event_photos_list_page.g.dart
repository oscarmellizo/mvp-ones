// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_photos_list_page.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$EventPhotosListPage extends EventPhotosListPage {
  @override
  final BuiltList<EventPhotoListItem> items;
  @override
  final String? nextToken;

  factory _$EventPhotosListPage(
          [void Function(EventPhotosListPageBuilder)? updates]) =>
      (new EventPhotosListPageBuilder()..update(updates))._build();

  _$EventPhotosListPage._({required this.items, this.nextToken}) : super._() {
    BuiltValueNullFieldError.checkNotNull(
        items, r'EventPhotosListPage', 'items');
  }

  @override
  EventPhotosListPage rebuild(
          void Function(EventPhotosListPageBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  EventPhotosListPageBuilder toBuilder() =>
      new EventPhotosListPageBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is EventPhotosListPage &&
        items == other.items &&
        nextToken == other.nextToken;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, items.hashCode);
    _$hash = $jc(_$hash, nextToken.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'EventPhotosListPage')
          ..add('items', items)
          ..add('nextToken', nextToken))
        .toString();
  }
}

class EventPhotosListPageBuilder
    implements Builder<EventPhotosListPage, EventPhotosListPageBuilder> {
  _$EventPhotosListPage? _$v;

  ListBuilder<EventPhotoListItem>? _items;
  ListBuilder<EventPhotoListItem> get items =>
      _$this._items ??= new ListBuilder<EventPhotoListItem>();
  set items(ListBuilder<EventPhotoListItem>? items) => _$this._items = items;

  String? _nextToken;
  String? get nextToken => _$this._nextToken;
  set nextToken(String? nextToken) => _$this._nextToken = nextToken;

  EventPhotosListPageBuilder() {
    EventPhotosListPage._defaults(this);
  }

  EventPhotosListPageBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _items = $v.items.toBuilder();
      _nextToken = $v.nextToken;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(EventPhotosListPage other) {
    ArgumentError.checkNotNull(other, 'other');
    _$v = other as _$EventPhotosListPage;
  }

  @override
  void update(void Function(EventPhotosListPageBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  EventPhotosListPage build() => _build();

  _$EventPhotosListPage _build() {
    _$EventPhotosListPage _$result;
    try {
      _$result = _$v ??
          new _$EventPhotosListPage._(
              items: items.build(), nextToken: nextToken);
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'items';
        items.build();
      } catch (e) {
        throw new BuiltValueNestedFieldError(
            r'EventPhotosListPage', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
