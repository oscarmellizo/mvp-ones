//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'invite_event_guests_request.g.dart';

/// InviteEventGuestsRequest
///
/// Properties:
/// * [inviteeEmails] 
@BuiltValue()
abstract class InviteEventGuestsRequest implements Built<InviteEventGuestsRequest, InviteEventGuestsRequestBuilder> {
  @BuiltValueField(wireName: r'inviteeEmails')
  BuiltList<String> get inviteeEmails;

  InviteEventGuestsRequest._();

  factory InviteEventGuestsRequest([void updates(InviteEventGuestsRequestBuilder b)]) = _$InviteEventGuestsRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(InviteEventGuestsRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<InviteEventGuestsRequest> get serializer => _$InviteEventGuestsRequestSerializer();
}

class _$InviteEventGuestsRequestSerializer implements PrimitiveSerializer<InviteEventGuestsRequest> {
  @override
  final Iterable<Type> types = const [InviteEventGuestsRequest, _$InviteEventGuestsRequest];

  @override
  final String wireName = r'InviteEventGuestsRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    InviteEventGuestsRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'inviteeEmails';
    yield serializers.serialize(
      object.inviteeEmails,
      specifiedType: const FullType(BuiltList, [FullType(String)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    InviteEventGuestsRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required InviteEventGuestsRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'inviteeEmails':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(String)]),
          ) as BuiltList<String>;
          result.inviteeEmails.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  InviteEventGuestsRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = InviteEventGuestsRequestBuilder();
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

