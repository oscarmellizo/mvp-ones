//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'join_event_by_code_request.g.dart';

/// JoinEventByCodeRequest
///
/// Properties:
/// * [code] 
@BuiltValue()
abstract class JoinEventByCodeRequest implements Built<JoinEventByCodeRequest, JoinEventByCodeRequestBuilder> {
  @BuiltValueField(wireName: r'code')
  String get code;

  JoinEventByCodeRequest._();

  factory JoinEventByCodeRequest([void updates(JoinEventByCodeRequestBuilder b)]) = _$JoinEventByCodeRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(JoinEventByCodeRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<JoinEventByCodeRequest> get serializer => _$JoinEventByCodeRequestSerializer();
}

class _$JoinEventByCodeRequestSerializer implements PrimitiveSerializer<JoinEventByCodeRequest> {
  @override
  final Iterable<Type> types = const [JoinEventByCodeRequest, _$JoinEventByCodeRequest];

  @override
  final String wireName = r'JoinEventByCodeRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    JoinEventByCodeRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'code';
    yield serializers.serialize(
      object.code,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    JoinEventByCodeRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required JoinEventByCodeRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'code':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.code = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  JoinEventByCodeRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = JoinEventByCodeRequestBuilder();
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

