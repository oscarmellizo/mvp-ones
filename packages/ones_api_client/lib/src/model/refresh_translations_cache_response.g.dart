// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'refresh_translations_cache_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const RefreshTranslationsCacheResponseLanguagesWarmedEnum
    _$refreshTranslationsCacheResponseLanguagesWarmedEnum_es =
    const RefreshTranslationsCacheResponseLanguagesWarmedEnum._('es');
const RefreshTranslationsCacheResponseLanguagesWarmedEnum
    _$refreshTranslationsCacheResponseLanguagesWarmedEnum_en =
    const RefreshTranslationsCacheResponseLanguagesWarmedEnum._('en');
const RefreshTranslationsCacheResponseLanguagesWarmedEnum
    _$refreshTranslationsCacheResponseLanguagesWarmedEnum_pt =
    const RefreshTranslationsCacheResponseLanguagesWarmedEnum._('pt');

RefreshTranslationsCacheResponseLanguagesWarmedEnum
    _$refreshTranslationsCacheResponseLanguagesWarmedEnumValueOf(String name) {
  switch (name) {
    case 'es':
      return _$refreshTranslationsCacheResponseLanguagesWarmedEnum_es;
    case 'en':
      return _$refreshTranslationsCacheResponseLanguagesWarmedEnum_en;
    case 'pt':
      return _$refreshTranslationsCacheResponseLanguagesWarmedEnum_pt;
    default:
      throw new ArgumentError(name);
  }
}

final BuiltSet<RefreshTranslationsCacheResponseLanguagesWarmedEnum>
    _$refreshTranslationsCacheResponseLanguagesWarmedEnumValues = new BuiltSet<
        RefreshTranslationsCacheResponseLanguagesWarmedEnum>(const <RefreshTranslationsCacheResponseLanguagesWarmedEnum>[
  _$refreshTranslationsCacheResponseLanguagesWarmedEnum_es,
  _$refreshTranslationsCacheResponseLanguagesWarmedEnum_en,
  _$refreshTranslationsCacheResponseLanguagesWarmedEnum_pt,
]);

Serializer<RefreshTranslationsCacheResponseLanguagesWarmedEnum>
    _$refreshTranslationsCacheResponseLanguagesWarmedEnumSerializer =
    new _$RefreshTranslationsCacheResponseLanguagesWarmedEnumSerializer();

class _$RefreshTranslationsCacheResponseLanguagesWarmedEnumSerializer
    implements
        PrimitiveSerializer<
            RefreshTranslationsCacheResponseLanguagesWarmedEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'es': 'es',
    'en': 'en',
    'pt': 'pt',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'es': 'es',
    'en': 'en',
    'pt': 'pt',
  };

  @override
  final Iterable<Type> types = const <Type>[
    RefreshTranslationsCacheResponseLanguagesWarmedEnum
  ];
  @override
  final String wireName = 'RefreshTranslationsCacheResponseLanguagesWarmedEnum';

  @override
  Object serialize(Serializers serializers,
          RefreshTranslationsCacheResponseLanguagesWarmedEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  RefreshTranslationsCacheResponseLanguagesWarmedEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      RefreshTranslationsCacheResponseLanguagesWarmedEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$RefreshTranslationsCacheResponse
    extends RefreshTranslationsCacheResponse {
  @override
  final BuiltList<RefreshTranslationsCacheResponseLanguagesWarmedEnum>
      languagesWarmed;
  @override
  final int totalTranslationsLoaded;

  factory _$RefreshTranslationsCacheResponse(
          [void Function(RefreshTranslationsCacheResponseBuilder)? updates]) =>
      (new RefreshTranslationsCacheResponseBuilder()..update(updates))._build();

  _$RefreshTranslationsCacheResponse._(
      {required this.languagesWarmed, required this.totalTranslationsLoaded})
      : super._() {
    BuiltValueNullFieldError.checkNotNull(languagesWarmed,
        r'RefreshTranslationsCacheResponse', 'languagesWarmed');
    BuiltValueNullFieldError.checkNotNull(totalTranslationsLoaded,
        r'RefreshTranslationsCacheResponse', 'totalTranslationsLoaded');
  }

  @override
  RefreshTranslationsCacheResponse rebuild(
          void Function(RefreshTranslationsCacheResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  RefreshTranslationsCacheResponseBuilder toBuilder() =>
      new RefreshTranslationsCacheResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RefreshTranslationsCacheResponse &&
        languagesWarmed == other.languagesWarmed &&
        totalTranslationsLoaded == other.totalTranslationsLoaded;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, languagesWarmed.hashCode);
    _$hash = $jc(_$hash, totalTranslationsLoaded.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RefreshTranslationsCacheResponse')
          ..add('languagesWarmed', languagesWarmed)
          ..add('totalTranslationsLoaded', totalTranslationsLoaded))
        .toString();
  }
}

class RefreshTranslationsCacheResponseBuilder
    implements
        Builder<RefreshTranslationsCacheResponse,
            RefreshTranslationsCacheResponseBuilder> {
  _$RefreshTranslationsCacheResponse? _$v;

  ListBuilder<RefreshTranslationsCacheResponseLanguagesWarmedEnum>?
      _languagesWarmed;
  ListBuilder<RefreshTranslationsCacheResponseLanguagesWarmedEnum>
      get languagesWarmed => _$this._languagesWarmed ??= new ListBuilder<
          RefreshTranslationsCacheResponseLanguagesWarmedEnum>();
  set languagesWarmed(
          ListBuilder<RefreshTranslationsCacheResponseLanguagesWarmedEnum>?
              languagesWarmed) =>
      _$this._languagesWarmed = languagesWarmed;

  int? _totalTranslationsLoaded;
  int? get totalTranslationsLoaded => _$this._totalTranslationsLoaded;
  set totalTranslationsLoaded(int? totalTranslationsLoaded) =>
      _$this._totalTranslationsLoaded = totalTranslationsLoaded;

  RefreshTranslationsCacheResponseBuilder() {
    RefreshTranslationsCacheResponse._defaults(this);
  }

  RefreshTranslationsCacheResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _languagesWarmed = $v.languagesWarmed.toBuilder();
      _totalTranslationsLoaded = $v.totalTranslationsLoaded;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RefreshTranslationsCacheResponse other) {
    ArgumentError.checkNotNull(other, 'other');
    _$v = other as _$RefreshTranslationsCacheResponse;
  }

  @override
  void update(void Function(RefreshTranslationsCacheResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RefreshTranslationsCacheResponse build() => _build();

  _$RefreshTranslationsCacheResponse _build() {
    _$RefreshTranslationsCacheResponse _$result;
    try {
      _$result = _$v ??
          new _$RefreshTranslationsCacheResponse._(
              languagesWarmed: languagesWarmed.build(),
              totalTranslationsLoaded: BuiltValueNullFieldError.checkNotNull(
                  totalTranslationsLoaded,
                  r'RefreshTranslationsCacheResponse',
                  'totalTranslationsLoaded'));
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'languagesWarmed';
        languagesWarmed.build();
      } catch (e) {
        throw new BuiltValueNestedFieldError(
            r'RefreshTranslationsCacheResponse', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
