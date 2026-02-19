//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'presigned_url_response.g.dart';

/// PresignedUrlResponse
///
/// Properties:
/// * [url] 
/// * [expiresAt] 
@BuiltValue()
abstract class PresignedUrlResponse implements Built<PresignedUrlResponse, PresignedUrlResponseBuilder> {
  @BuiltValueField(wireName: r'url')
  String get url;

  @BuiltValueField(wireName: r'expiresAt')
  DateTime get expiresAt;

  PresignedUrlResponse._();

  factory PresignedUrlResponse([void updates(PresignedUrlResponseBuilder b)]) = _$PresignedUrlResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PresignedUrlResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PresignedUrlResponse> get serializer => _$PresignedUrlResponseSerializer();
}

class _$PresignedUrlResponseSerializer implements PrimitiveSerializer<PresignedUrlResponse> {
  @override
  final Iterable<Type> types = const [PresignedUrlResponse, _$PresignedUrlResponse];

  @override
  final String wireName = r'PresignedUrlResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PresignedUrlResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'url';
    yield serializers.serialize(
      object.url,
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
    PresignedUrlResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required PresignedUrlResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'url':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.url = valueDes;
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
  PresignedUrlResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PresignedUrlResponseBuilder();
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

