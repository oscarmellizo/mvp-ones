// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'upsert_translation_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const UpsertTranslationRequestLanguageCodeEnum
    _$upsertTranslationRequestLanguageCodeEnum_es =
    const UpsertTranslationRequestLanguageCodeEnum._('es');
const UpsertTranslationRequestLanguageCodeEnum
    _$upsertTranslationRequestLanguageCodeEnum_en =
    const UpsertTranslationRequestLanguageCodeEnum._('en');
const UpsertTranslationRequestLanguageCodeEnum
    _$upsertTranslationRequestLanguageCodeEnum_pt =
    const UpsertTranslationRequestLanguageCodeEnum._('pt');

UpsertTranslationRequestLanguageCodeEnum
    _$upsertTranslationRequestLanguageCodeEnumValueOf(String name) {
  switch (name) {
    case 'es':
      return _$upsertTranslationRequestLanguageCodeEnum_es;
    case 'en':
      return _$upsertTranslationRequestLanguageCodeEnum_en;
    case 'pt':
      return _$upsertTranslationRequestLanguageCodeEnum_pt;
    default:
      throw new ArgumentError(name);
  }
}

final BuiltSet<UpsertTranslationRequestLanguageCodeEnum>
    _$upsertTranslationRequestLanguageCodeEnumValues = new BuiltSet<
        UpsertTranslationRequestLanguageCodeEnum>(const <UpsertTranslationRequestLanguageCodeEnum>[
  _$upsertTranslationRequestLanguageCodeEnum_es,
  _$upsertTranslationRequestLanguageCodeEnum_en,
  _$upsertTranslationRequestLanguageCodeEnum_pt,
]);

Serializer<UpsertTranslationRequestLanguageCodeEnum>
    _$upsertTranslationRequestLanguageCodeEnumSerializer =
    new _$UpsertTranslationRequestLanguageCodeEnumSerializer();

class _$UpsertTranslationRequestLanguageCodeEnumSerializer
    implements PrimitiveSerializer<UpsertTranslationRequestLanguageCodeEnum> {
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
    UpsertTranslationRequestLanguageCodeEnum
  ];
  @override
  final String wireName = 'UpsertTranslationRequestLanguageCodeEnum';

  @override
  Object serialize(Serializers serializers,
          UpsertTranslationRequestLanguageCodeEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  UpsertTranslationRequestLanguageCodeEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      UpsertTranslationRequestLanguageCodeEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$UpsertTranslationRequest extends UpsertTranslationRequest {
  @override
  final String translationKey;
  @override
  final UpsertTranslationRequestLanguageCodeEnum languageCode;
  @override
  final String value;
  @override
  final String? context;

  factory _$UpsertTranslationRequest(
          [void Function(UpsertTranslationRequestBuilder)? updates]) =>
      (new UpsertTranslationRequestBuilder()..update(updates))._build();

  _$UpsertTranslationRequest._(
      {required this.translationKey,
      required this.languageCode,
      required this.value,
      this.context})
      : super._() {
    BuiltValueNullFieldError.checkNotNull(
        translationKey, r'UpsertTranslationRequest', 'translationKey');
    BuiltValueNullFieldError.checkNotNull(
        languageCode, r'UpsertTranslationRequest', 'languageCode');
    BuiltValueNullFieldError.checkNotNull(
        value, r'UpsertTranslationRequest', 'value');
  }

  @override
  UpsertTranslationRequest rebuild(
          void Function(UpsertTranslationRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  UpsertTranslationRequestBuilder toBuilder() =>
      new UpsertTranslationRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is UpsertTranslationRequest &&
        translationKey == other.translationKey &&
        languageCode == other.languageCode &&
        value == other.value &&
        context == other.context;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, translationKey.hashCode);
    _$hash = $jc(_$hash, languageCode.hashCode);
    _$hash = $jc(_$hash, value.hashCode);
    _$hash = $jc(_$hash, context.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'UpsertTranslationRequest')
          ..add('translationKey', translationKey)
          ..add('languageCode', languageCode)
          ..add('value', value)
          ..add('context', context))
        .toString();
  }
}

class UpsertTranslationRequestBuilder
    implements
        Builder<UpsertTranslationRequest, UpsertTranslationRequestBuilder> {
  _$UpsertTranslationRequest? _$v;

  String? _translationKey;
  String? get translationKey => _$this._translationKey;
  set translationKey(String? translationKey) =>
      _$this._translationKey = translationKey;

  UpsertTranslationRequestLanguageCodeEnum? _languageCode;
  UpsertTranslationRequestLanguageCodeEnum? get languageCode =>
      _$this._languageCode;
  set languageCode(UpsertTranslationRequestLanguageCodeEnum? languageCode) =>
      _$this._languageCode = languageCode;

  String? _value;
  String? get value => _$this._value;
  set value(String? value) => _$this._value = value;

  String? _context;
  String? get context => _$this._context;
  set context(String? context) => _$this._context = context;

  UpsertTranslationRequestBuilder() {
    UpsertTranslationRequest._defaults(this);
  }

  UpsertTranslationRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _translationKey = $v.translationKey;
      _languageCode = $v.languageCode;
      _value = $v.value;
      _context = $v.context;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(UpsertTranslationRequest other) {
    ArgumentError.checkNotNull(other, 'other');
    _$v = other as _$UpsertTranslationRequest;
  }

  @override
  void update(void Function(UpsertTranslationRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  UpsertTranslationRequest build() => _build();

  _$UpsertTranslationRequest _build() {
    final _$result = _$v ??
        new _$UpsertTranslationRequest._(
            translationKey: BuiltValueNullFieldError.checkNotNull(
                translationKey, r'UpsertTranslationRequest', 'translationKey'),
            languageCode: BuiltValueNullFieldError.checkNotNull(
                languageCode, r'UpsertTranslationRequest', 'languageCode'),
            value: BuiltValueNullFieldError.checkNotNull(
                value, r'UpsertTranslationRequest', 'value'),
            context: context);
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
