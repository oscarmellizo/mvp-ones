//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'translation.g.dart';

/// Translation
///
/// Properties:
/// * [translationKey] 
/// * [languageCode] 
/// * [value] 
/// * [context] 
/// * [createdAt] 
/// * [updatedAt] 
/// * [createdBy] 
/// * [updatedBy] 
@BuiltValue()
abstract class Translation implements Built<Translation, TranslationBuilder> {
  @BuiltValueField(wireName: r'translationKey')
  String get translationKey;

  @BuiltValueField(wireName: r'languageCode')
  TranslationLanguageCodeEnum get languageCode;
  // enum languageCodeEnum {  es,  en,  pt,  };

  @BuiltValueField(wireName: r'value')
  String? get value;

  @BuiltValueField(wireName: r'context')
  String? get context;

  @BuiltValueField(wireName: r'createdAt')
  DateTime? get createdAt;

  @BuiltValueField(wireName: r'updatedAt')
  DateTime? get updatedAt;

  @BuiltValueField(wireName: r'createdBy')
  String? get createdBy;

  @BuiltValueField(wireName: r'updatedBy')
  String? get updatedBy;

  Translation._();

  factory Translation([void updates(TranslationBuilder b)]) = _$Translation;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(TranslationBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<Translation> get serializer => _$TranslationSerializer();
}

class _$TranslationSerializer implements PrimitiveSerializer<Translation> {
  @override
  final Iterable<Type> types = const [Translation, _$Translation];

  @override
  final String wireName = r'Translation';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    Translation object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'translationKey';
    yield serializers.serialize(
      object.translationKey,
      specifiedType: const FullType(String),
    );
    yield r'languageCode';
    yield serializers.serialize(
      object.languageCode,
      specifiedType: const FullType(TranslationLanguageCodeEnum),
    );
    if (object.value != null) {
      yield r'value';
      yield serializers.serialize(
        object.value,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.context != null) {
      yield r'context';
      yield serializers.serialize(
        object.context,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.createdAt != null) {
      yield r'createdAt';
      yield serializers.serialize(
        object.createdAt,
        specifiedType: const FullType.nullable(DateTime),
      );
    }
    if (object.updatedAt != null) {
      yield r'updatedAt';
      yield serializers.serialize(
        object.updatedAt,
        specifiedType: const FullType.nullable(DateTime),
      );
    }
    if (object.createdBy != null) {
      yield r'createdBy';
      yield serializers.serialize(
        object.createdBy,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.updatedBy != null) {
      yield r'updatedBy';
      yield serializers.serialize(
        object.updatedBy,
        specifiedType: const FullType.nullable(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    Translation object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required TranslationBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'translationKey':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.translationKey = valueDes;
          break;
        case r'languageCode':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(TranslationLanguageCodeEnum),
          ) as TranslationLanguageCodeEnum;
          result.languageCode = valueDes;
          break;
        case r'value':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.value = valueDes;
          break;
        case r'context':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.context = valueDes;
          break;
        case r'createdAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DateTime),
          ) as DateTime?;
          if (valueDes == null) continue;
          result.createdAt = valueDes;
          break;
        case r'updatedAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DateTime),
          ) as DateTime?;
          if (valueDes == null) continue;
          result.updatedAt = valueDes;
          break;
        case r'createdBy':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.createdBy = valueDes;
          break;
        case r'updatedBy':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.updatedBy = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  Translation deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = TranslationBuilder();
    final serializedList = (serialized as Iterable<Object?>).toList();
    final unhandled = <Object?>[];
    _deserializeProperties(
      serializers,
      serialized,
      specifiedType: specifiedType,
      serializedList: serializedList,
      unhandled: unhandled,
      result: result,
    );
    return result.build();
  }
}

class TranslationLanguageCodeEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'es')
  static const TranslationLanguageCodeEnum es = _$translationLanguageCodeEnum_es;
  @BuiltValueEnumConst(wireName: r'en')
  static const TranslationLanguageCodeEnum en = _$translationLanguageCodeEnum_en;
  @BuiltValueEnumConst(wireName: r'pt')
  static const TranslationLanguageCodeEnum pt = _$translationLanguageCodeEnum_pt;

  static Serializer<TranslationLanguageCodeEnum> get serializer => _$translationLanguageCodeEnumSerializer;

  const TranslationLanguageCodeEnum._(String name): super(name);

  static BuiltSet<TranslationLanguageCodeEnum> get values => _$translationLanguageCodeEnumValues;
  static TranslationLanguageCodeEnum valueOf(String name) => _$translationLanguageCodeEnumValueOf(name);
}

