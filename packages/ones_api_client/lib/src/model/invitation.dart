//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'invitation.g.dart';

/// Invitation
///
/// Properties:
/// * [eventId] 
/// * [inviteeEmail] 
/// * [inviteeUserId] - The authenticated userId that last responded to this invitation (optional)
/// * [eventOwnerId] 
/// * [status] 
/// * [createdAt] 
/// * [updatedAt] 
/// * [eventTitle] 
/// * [eventLocation] 
/// * [eventStartAt] 
/// * [eventEndAt] 
@BuiltValue()
abstract class Invitation implements Built<Invitation, InvitationBuilder> {
  @BuiltValueField(wireName: r'eventId')
  String get eventId;

  @BuiltValueField(wireName: r'inviteeEmail')
  String get inviteeEmail;

  /// The authenticated userId that last responded to this invitation (optional)
  @BuiltValueField(wireName: r'inviteeUserId')
  String? get inviteeUserId;

  @BuiltValueField(wireName: r'eventOwnerId')
  String? get eventOwnerId;

  @BuiltValueField(wireName: r'status')
  InvitationStatusEnum get status;
  // enum statusEnum {  invited,  accepted,  rejected,  };

  @BuiltValueField(wireName: r'createdAt')
  DateTime get createdAt;

  @BuiltValueField(wireName: r'updatedAt')
  DateTime get updatedAt;

  @BuiltValueField(wireName: r'eventTitle')
  String get eventTitle;

  @BuiltValueField(wireName: r'eventLocation')
  String? get eventLocation;

  @BuiltValueField(wireName: r'eventStartAt')
  DateTime get eventStartAt;

  @BuiltValueField(wireName: r'eventEndAt')
  DateTime get eventEndAt;

  Invitation._();

  factory Invitation([void updates(InvitationBuilder b)]) = _$Invitation;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(InvitationBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<Invitation> get serializer => _$InvitationSerializer();
}

class _$InvitationSerializer implements PrimitiveSerializer<Invitation> {
  @override
  final Iterable<Type> types = const [Invitation, _$Invitation];

  @override
  final String wireName = r'Invitation';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    Invitation object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'eventId';
    yield serializers.serialize(
      object.eventId,
      specifiedType: const FullType(String),
    );
    yield r'inviteeEmail';
    yield serializers.serialize(
      object.inviteeEmail,
      specifiedType: const FullType(String),
    );
    if (object.inviteeUserId != null) {
      yield r'inviteeUserId';
      yield serializers.serialize(
        object.inviteeUserId,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.eventOwnerId != null) {
      yield r'eventOwnerId';
      yield serializers.serialize(
        object.eventOwnerId,
        specifiedType: const FullType(String),
      );
    }
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(InvitationStatusEnum),
    );
    yield r'createdAt';
    yield serializers.serialize(
      object.createdAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'updatedAt';
    yield serializers.serialize(
      object.updatedAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'eventTitle';
    yield serializers.serialize(
      object.eventTitle,
      specifiedType: const FullType(String),
    );
    if (object.eventLocation != null) {
      yield r'eventLocation';
      yield serializers.serialize(
        object.eventLocation,
        specifiedType: const FullType.nullable(String),
      );
    }
    yield r'eventStartAt';
    yield serializers.serialize(
      object.eventStartAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'eventEndAt';
    yield serializers.serialize(
      object.eventEndAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    Invitation object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required InvitationBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'eventId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.eventId = valueDes;
          break;
        case r'inviteeEmail':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.inviteeEmail = valueDes;
          break;
        case r'inviteeUserId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.inviteeUserId = valueDes;
          break;
        case r'eventOwnerId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.eventOwnerId = valueDes;
          break;
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(InvitationStatusEnum),
          ) as InvitationStatusEnum;
          result.status = valueDes;
          break;
        case r'createdAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.createdAt = valueDes;
          break;
        case r'updatedAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.updatedAt = valueDes;
          break;
        case r'eventTitle':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.eventTitle = valueDes;
          break;
        case r'eventLocation':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.eventLocation = valueDes;
          break;
        case r'eventStartAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.eventStartAt = valueDes;
          break;
        case r'eventEndAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.eventEndAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  Invitation deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = InvitationBuilder();
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

class InvitationStatusEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'invited')
  static const InvitationStatusEnum invited = _$invitationStatusEnum_invited;
  @BuiltValueEnumConst(wireName: r'accepted')
  static const InvitationStatusEnum accepted = _$invitationStatusEnum_accepted;
  @BuiltValueEnumConst(wireName: r'rejected')
  static const InvitationStatusEnum rejected = _$invitationStatusEnum_rejected;

  static Serializer<InvitationStatusEnum> get serializer => _$invitationStatusEnumSerializer;

  const InvitationStatusEnum._(String name): super(name);

  static BuiltSet<InvitationStatusEnum> get values => _$invitationStatusEnumValues;
  static InvitationStatusEnum valueOf(String name) => _$invitationStatusEnumValueOf(name);
}

