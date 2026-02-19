//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'accept_event_cover_response.g.dart';

/// AcceptEventCoverResponse
///
/// Properties:
/// * [reservationId] 
@BuiltValue()
abstract class AcceptEventCoverResponse implements Built<AcceptEventCoverResponse, AcceptEventCoverResponseBuilder> {
  @BuiltValueField(wireName: r'reservationId')
  String get reservationId;

  AcceptEventCoverResponse._();

  factory AcceptEventCoverResponse([void updates(AcceptEventCoverResponseBuilder b)]) = _$AcceptEventCoverResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AcceptEventCoverResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AcceptEventCoverResponse> get serializer => _$AcceptEventCoverResponseSerializer();
}

class _$AcceptEventCoverResponseSerializer implements PrimitiveSerializer<AcceptEventCoverResponse> {
  @override
  final Iterable<Type> types = const [AcceptEventCoverResponse, _$AcceptEventCoverResponse];

  @override
  final String wireName = r'AcceptEventCoverResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AcceptEventCoverResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'reservationId';
    yield serializers.serialize(
      object.reservationId,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AcceptEventCoverResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required AcceptEventCoverResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'reservationId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.reservationId = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AcceptEventCoverResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AcceptEventCoverResponseBuilder();
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

