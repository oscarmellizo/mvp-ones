//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'generate_event_cover_response.g.dart';

/// GenerateEventCoverResponse
///
/// Properties:
/// * [coverId] 
/// * [previewUrl] 
/// * [expiresAt] 
@BuiltValue()
abstract class GenerateEventCoverResponse implements Built<GenerateEventCoverResponse, GenerateEventCoverResponseBuilder> {
  @BuiltValueField(wireName: r'coverId')
  String get coverId;

  @BuiltValueField(wireName: r'previewUrl')
  String get previewUrl;

  @BuiltValueField(wireName: r'expiresAt')
  DateTime get expiresAt;

  GenerateEventCoverResponse._();

  factory GenerateEventCoverResponse([void updates(GenerateEventCoverResponseBuilder b)]) = _$GenerateEventCoverResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(GenerateEventCoverResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<GenerateEventCoverResponse> get serializer => _$GenerateEventCoverResponseSerializer();
}

class _$GenerateEventCoverResponseSerializer implements PrimitiveSerializer<GenerateEventCoverResponse> {
  @override
  final Iterable<Type> types = const [GenerateEventCoverResponse, _$GenerateEventCoverResponse];

  @override
  final String wireName = r'GenerateEventCoverResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    GenerateEventCoverResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'coverId';
    yield serializers.serialize(
      object.coverId,
      specifiedType: const FullType(String),
    );
    yield r'previewUrl';
    yield serializers.serialize(
      object.previewUrl,
      specifiedType: const FullType(String),
    );
    yield r'expiresAt';
    yield serializers.serialize(
      object.expiresAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    GenerateEventCoverResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required GenerateEventCoverResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'coverId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.coverId = valueDes;
          break;
        case r'previewUrl':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.previewUrl = valueDes;
          break;
        case r'expiresAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.expiresAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  GenerateEventCoverResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GenerateEventCoverResponseBuilder();
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

