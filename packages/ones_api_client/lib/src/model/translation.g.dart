// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'translation.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const TranslationLanguageCodeEnum _$translationLanguageCodeEnum_es =
    const TranslationLanguageCodeEnum._('es');
const TranslationLanguageCodeEnum _$translationLanguageCodeEnum_en =
    const TranslationLanguageCodeEnum._('en');
const TranslationLanguageCodeEnum _$translationLanguageCodeEnum_pt =
    const TranslationLanguageCodeEnum._('pt');

TranslationLanguageCodeEnum _$translationLanguageCodeEnumValueOf(String name) {
  switch (name) {
    case 'es':
      return _$translationLanguageCodeEnum_es;
    case 'en':
      return _$translationLanguageCodeEnum_en;
    case 'pt':
      return _$translationLanguageCodeEnum_pt;
    default:
      throw new ArgumentError(name);
  }
}

final BuiltSet<TranslationLanguageCodeEnum>
    _$translationLanguageCodeEnumValues = new BuiltSet<
        TranslationLanguageCodeEnum>(const <TranslationLanguageCodeEnum>[
  _$translationLanguageCodeEnum_es,
  _$translationLanguageCodeEnum_en,
  _$translationLanguageCodeEnum_pt,
]);

Serializer<TranslationLanguageCodeEnum>
    _$translationLanguageCodeEnumSerializer =
    new _$TranslationLanguageCodeEnumSerializer();

class _$TranslationLanguageCodeEnumSerializer
    implements PrimitiveSerializer<TranslationLanguageCodeEnum> {
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
  final Iterable<Type> types = const <Type>[TranslationLanguageCodeEnum];
  @override
  final String wireName = 'TranslationLanguageCodeEnum';

  @override
  Object serialize(Serializers serializers, TranslationLanguageCodeEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  TranslationLanguageCodeEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      TranslationLanguageCodeEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$Translation extends Translation {
  @override
  final String translationKey;
  @override
  final TranslationLanguageCodeEnum languageCode;
  @override
  final String? value;
  @override
  final String? context;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;
  @override
  final String? createdBy;
  @override
  final String? updatedBy;

  factory _$Translation([void Function(TranslationBuilder)? updates]) =>
      (new TranslationBuilder()..update(updates))._build();

  _$Translation._(
      {required this.translationKey,
      required this.languageCode,
      this.value,
      this.context,
      this.createdAt,
      this.updatedAt,
      this.createdBy,
      this.updatedBy})
      : super._() {
    BuiltValueNullFieldError.checkNotNull(
        translationKey, r'Translation', 'translationKey');
    BuiltValueNullFieldError.checkNotNull(
        languageCode, r'Translation', 'languageCode');
  }

  @override
  Translation rebuild(void Function(TranslationBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  TranslationBuilder toBuilder() => new TranslationBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Translation &&
        translationKey == other.translationKey &&
        languageCode == other.languageCode &&
        value == other.value &&
        context == other.context &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt &&
        createdBy == other.createdBy &&
        updatedBy == other.updatedBy;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, translationKey.hashCode);
    _$hash = $jc(_$hash, languageCode.hashCode);
    _$hash = $jc(_$hash, value.hashCode);
    _$hash = $jc(_$hash, context.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jc(_$hash, createdBy.hashCode);
    _$hash = $jc(_$hash, updatedBy.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Translation')
          ..add('translationKey', translationKey)
          ..add('languageCode', languageCode)
          ..add('value', value)
          ..add('context', context)
          ..add('createdAt', createdAt)
          ..add('updatedAt', updatedAt)
          ..add('createdBy', createdBy)
          ..add('updatedBy', updatedBy))
        .toString();
  }
}

class TranslationBuilder implements Builder<Translation, TranslationBuilder> {
  _$Translation? _$v;

  String? _translationKey;
  String? get translationKey => _$this._translationKey;
  set translationKey(String? translationKey) =>
      _$this._translationKey = translationKey;

  TranslationLanguageCodeEnum? _languageCode;
  TranslationLanguageCodeEnum? get languageCode => _$this._languageCode;
  set languageCode(TranslationLanguageCodeEnum? languageCode) =>
      _$this._languageCode = languageCode;

  String? _value;
  String? get value => _$this._value;
  set value(String? value) => _$this._value = value;

  String? _context;
  String? get context => _$this._context;
  set context(String? context) => _$this._context = context;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _$this._updatedAt;
  set updatedAt(DateTime? updatedAt) => _$this._updatedAt = updatedAt;

  String? _createdBy;
  String? get createdBy => _$this._createdBy;
  set createdBy(String? createdBy) => _$this._createdBy = createdBy;

  String? _updatedBy;
  String? get updatedBy => _$this._updatedBy;
  set updatedBy(String? updatedBy) => _$this._updatedBy = updatedBy;

  TranslationBuilder() {
    Translation._defaults(this);
  }

  TranslationBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _translationKey = $v.translationKey;
      _languageCode = $v.languageCode;
      _value = $v.value;
      _context = $v.context;
      _createdAt = $v.createdAt;
      _updatedAt = $v.updatedAt;
      _createdBy = $v.createdBy;
      _updatedBy = $v.updatedBy;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Translation other) {
    ArgumentError.checkNotNull(other, 'other');
    _$v = other as _$Translation;
  }

  @override
  void update(void Function(TranslationBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Translation build() => _build();

  _$Translation _build() {
    final _$result = _$v ??
        new _$Translation._(
            translationKey: BuiltValueNullFieldError.checkNotNull(
                translationKey, r'Translation', 'translationKey'),
            languageCode: BuiltValueNullFieldError.checkNotNull(
                languageCode, r'Translation', 'languageCode'),
            value: value,
            context: context,
            createdAt: createdAt,
            updatedAt: updatedAt,
            createdBy: createdBy,
            updatedBy: updatedBy);
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
