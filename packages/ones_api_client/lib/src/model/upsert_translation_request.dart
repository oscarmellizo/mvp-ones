//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'upsert_translation_request.g.dart';

/// UpsertTranslationRequest
///
/// Properties:
/// * [translationKey] 
/// * [languageCode] 
/// * [value] 
/// * [context] 
@BuiltValue()
abstract class UpsertTranslationRequest implements Built<UpsertTranslationRequest, UpsertTranslationRequestBuilder> {
  @BuiltValueField(wireName: r'translationKey')
  String get translationKey;

  @BuiltValueField(wireName: r'languageCode')
  UpsertTranslationRequestLanguageCodeEnum get languageCode;
  // enum languageCodeEnum {  es,  en,  pt,  };

  @BuiltValueField(wireName: r'value')
  String get value;

  @BuiltValueField(wireName: r'context')
  String? get context;

  UpsertTranslationRequest._();

  factory UpsertTranslationRequest([void updates(UpsertTranslationRequestBuilder b)]) = _$UpsertTranslationRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(UpsertTranslationRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<UpsertTranslationRequest> get serializer => _$UpsertTranslationRequestSerializer();
}

class _$UpsertTranslationRequestSerializer implements PrimitiveSerializer<UpsertTranslationRequest> {
  @override
  final Iterable<Type> types = const [UpsertTranslationRequest, _$UpsertTranslationRequest];

  @override
  final String wireName = r'UpsertTranslationRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    UpsertTranslationRequest object, {
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
      specifiedType: const FullType(UpsertTranslationRequestLanguageCodeEnum),
    );
    yield r'value';
    yield serializers.serialize(
      object.value,
      specifiedType: const FullType(String),
    );
    if (object.context != null) {
      yield r'context';
      yield serializers.serialize(
        object.context,
        specifiedType: const FullType.nullable(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    UpsertTranslationRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required UpsertTranslationRequestBuilder result,
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
            specifiedType: const FullType(UpsertTranslationRequestLanguageCodeEnum),
          ) as UpsertTranslationRequestLanguageCodeEnum;
          result.languageCode = valueDes;
          break;
        case r'value':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  UpsertTranslationRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = UpsertTranslationRequestBuilder();
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

class UpsertTranslationRequestLanguageCodeEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'es')
  static const UpsertTranslationRequestLanguageCodeEnum es = _$upsertTranslationRequestLanguageCodeEnum_es;
  @BuiltValueEnumConst(wireName: r'en')
  static const UpsertTranslationRequestLanguageCodeEnum en = _$upsertTranslationRequestLanguageCodeEnum_en;
  @BuiltValueEnumConst(wireName: r'pt')
  static const UpsertTranslationRequestLanguageCodeEnum pt = _$upsertTranslationRequestLanguageCodeEnum_pt;

  static Serializer<UpsertTranslationRequestLanguageCodeEnum> get serializer => _$upsertTranslationRequestLanguageCodeEnumSerializer;

  const UpsertTranslationRequestLanguageCodeEnum._(String name): super(name);

  static BuiltSet<UpsertTranslationRequestLanguageCodeEnum> get values => _$upsertTranslationRequestLanguageCodeEnumValues;
  static UpsertTranslationRequestLanguageCodeEnum valueOf(String name) => _$upsertTranslationRequestLanguageCodeEnumValueOf(name);
}

