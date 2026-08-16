//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'refresh_translations_cache_response.g.dart';

/// RefreshTranslationsCacheResponse
///
/// Properties:
/// * [languagesWarmed] 
/// * [totalTranslationsLoaded] 
@BuiltValue()
abstract class RefreshTranslationsCacheResponse implements Built<RefreshTranslationsCacheResponse, RefreshTranslationsCacheResponseBuilder> {
  @BuiltValueField(wireName: r'languagesWarmed')
  BuiltList<RefreshTranslationsCacheResponseLanguagesWarmedEnum> get languagesWarmed;
  // enum languagesWarmedEnum {  es,  en,  pt,  };

  @BuiltValueField(wireName: r'totalTranslationsLoaded')
  int get totalTranslationsLoaded;

  RefreshTranslationsCacheResponse._();

  factory RefreshTranslationsCacheResponse([void updates(RefreshTranslationsCacheResponseBuilder b)]) = _$RefreshTranslationsCacheResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RefreshTranslationsCacheResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RefreshTranslationsCacheResponse> get serializer => _$RefreshTranslationsCacheResponseSerializer();
}

class _$RefreshTranslationsCacheResponseSerializer implements PrimitiveSerializer<RefreshTranslationsCacheResponse> {
  @override
  final Iterable<Type> types = const [RefreshTranslationsCacheResponse, _$RefreshTranslationsCacheResponse];

  @override
  final String wireName = r'RefreshTranslationsCacheResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RefreshTranslationsCacheResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'languagesWarmed';
    yield serializers.serialize(
      object.languagesWarmed,
      specifiedType: const FullType(BuiltList, [FullType(RefreshTranslationsCacheResponseLanguagesWarmedEnum)]),
    );
    yield r'totalTranslationsLoaded';
    yield serializers.serialize(
      object.totalTranslationsLoaded,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    RefreshTranslationsCacheResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RefreshTranslationsCacheResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'languagesWarmed':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(RefreshTranslationsCacheResponseLanguagesWarmedEnum)]),
          ) as BuiltList<RefreshTranslationsCacheResponseLanguagesWarmedEnum>;
          result.languagesWarmed.replace(valueDes);
          break;
        case r'totalTranslationsLoaded':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.totalTranslationsLoaded = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  RefreshTranslationsCacheResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RefreshTranslationsCacheResponseBuilder();
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

class RefreshTranslationsCacheResponseLanguagesWarmedEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'es')
  static const RefreshTranslationsCacheResponseLanguagesWarmedEnum es = _$refreshTranslationsCacheResponseLanguagesWarmedEnum_es;
  @BuiltValueEnumConst(wireName: r'en')
  static const RefreshTranslationsCacheResponseLanguagesWarmedEnum en = _$refreshTranslationsCacheResponseLanguagesWarmedEnum_en;
  @BuiltValueEnumConst(wireName: r'pt')
  static const RefreshTranslationsCacheResponseLanguagesWarmedEnum pt = _$refreshTranslationsCacheResponseLanguagesWarmedEnum_pt;

  static Serializer<RefreshTranslationsCacheResponseLanguagesWarmedEnum> get serializer => _$refreshTranslationsCacheResponseLanguagesWarmedEnumSerializer;

  const RefreshTranslationsCacheResponseLanguagesWarmedEnum._(String name): super(name);

  static BuiltSet<RefreshTranslationsCacheResponseLanguagesWarmedEnum> get values => _$refreshTranslationsCacheResponseLanguagesWarmedEnumValues;
  static RefreshTranslationsCacheResponseLanguagesWarmedEnum valueOf(String name) => _$refreshTranslationsCacheResponseLanguagesWarmedEnumValueOf(name);
}

