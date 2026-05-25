//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'guest_v2.g.dart';

/// GuestV2
///
/// Properties:
/// * [userId] - User id if the guest has accepted and is linked to an authenticated user (or the event owner)
/// * [email] 
/// * [displayName] 
/// * [role] 
/// * [status] 
@BuiltValue()
abstract class GuestV2 implements Built<GuestV2, GuestV2Builder> {
  /// User id if the guest has accepted and is linked to an authenticated user (or the event owner)
  @BuiltValueField(wireName: r'userId')
  String? get userId;

  @BuiltValueField(wireName: r'email')
  String? get email;

  @BuiltValueField(wireName: r'displayName')
  String? get displayName;

  @BuiltValueField(wireName: r'role')
  GuestV2RoleEnum get role;
  // enum roleEnum {  owner,  guest,  };

  @BuiltValueField(wireName: r'status')
  GuestV2StatusEnum get status;
  // enum statusEnum {  owner,  invited,  accepted,  rejected,  };

  GuestV2._();

  factory GuestV2([void updates(GuestV2Builder b)]) = _$GuestV2;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(GuestV2Builder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<GuestV2> get serializer => _$GuestV2Serializer();
}

class _$GuestV2Serializer implements PrimitiveSerializer<GuestV2> {
  @override
  final Iterable<Type> types = const [GuestV2, _$GuestV2];

  @override
  final String wireName = r'GuestV2';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    GuestV2 object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.userId != null) {
      yield r'userId';
      yield serializers.serialize(
        object.userId,
        specifiedType: const FullType.nullable(String),
      );
    }
    yield r'email';
    yield object.email == null ? null : serializers.serialize(
      object.email,
      specifiedType: const FullType.nullable(String),
    );
    if (object.displayName != null) {
      yield r'displayName';
      yield serializers.serialize(
        object.displayName,
        specifiedType: const FullType.nullable(String),
      );
    }
    yield r'role';
    yield serializers.serialize(
      object.role,
      specifiedType: const FullType(GuestV2RoleEnum),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(GuestV2StatusEnum),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    GuestV2 object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required GuestV2Builder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'userId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.userId = valueDes;
          break;
        case r'email':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.email = valueDes;
          break;
        case r'displayName':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.displayName = valueDes;
          break;
        case r'role':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(GuestV2RoleEnum),
          ) as GuestV2RoleEnum;
          result.role = valueDes;
          break;
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(GuestV2StatusEnum),
          ) as GuestV2StatusEnum;
          result.status = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  GuestV2 deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GuestV2Builder();
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

class GuestV2RoleEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'owner')
  static const GuestV2RoleEnum owner = _$guestV2RoleEnum_owner;
  @BuiltValueEnumConst(wireName: r'guest')
  static const GuestV2RoleEnum guest = _$guestV2RoleEnum_guest;

  static Serializer<GuestV2RoleEnum> get serializer => _$guestV2RoleEnumSerializer;

  const GuestV2RoleEnum._(String name): super(name);

  static BuiltSet<GuestV2RoleEnum> get values => _$guestV2RoleEnumValues;
  static GuestV2RoleEnum valueOf(String name) => _$guestV2RoleEnumValueOf(name);
}

class GuestV2StatusEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'owner')
  static const GuestV2StatusEnum owner = _$guestV2StatusEnum_owner;
  @BuiltValueEnumConst(wireName: r'invited')
  static const GuestV2StatusEnum invited = _$guestV2StatusEnum_invited;
  @BuiltValueEnumConst(wireName: r'accepted')
  static const GuestV2StatusEnum accepted = _$guestV2StatusEnum_accepted;
  @BuiltValueEnumConst(wireName: r'rejected')
  static const GuestV2StatusEnum rejected = _$guestV2StatusEnum_rejected;

  static Serializer<GuestV2StatusEnum> get serializer => _$guestV2StatusEnumSerializer;

  const GuestV2StatusEnum._(String name): super(name);

  static BuiltSet<GuestV2StatusEnum> get values => _$guestV2StatusEnumValues;
  static GuestV2StatusEnum valueOf(String name) => _$guestV2StatusEnumValueOf(name);
}

