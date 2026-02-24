//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'guest.g.dart';

/// Guest
///
/// Properties:
/// * [email] 
/// * [displayName] 
/// * [role] 
/// * [status] 
@BuiltValue()
abstract class Guest implements Built<Guest, GuestBuilder> {
  @BuiltValueField(wireName: r'email')
  String? get email;

  @BuiltValueField(wireName: r'displayName')
  String? get displayName;

  @BuiltValueField(wireName: r'role')
  GuestRoleEnum get role;
  // enum roleEnum {  owner,  guest,  };

  @BuiltValueField(wireName: r'status')
  GuestStatusEnum get status;
  // enum statusEnum {  owner,  invited,  accepted,  rejected,  };

  Guest._();

  factory Guest([void updates(GuestBuilder b)]) = _$Guest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(GuestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<Guest> get serializer => _$GuestSerializer();
}

class _$GuestSerializer implements PrimitiveSerializer<Guest> {
  @override
  final Iterable<Type> types = const [Guest, _$Guest];

  @override
  final String wireName = r'Guest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    Guest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
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
      specifiedType: const FullType(GuestRoleEnum),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(GuestStatusEnum),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    Guest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required GuestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
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
            specifiedType: const FullType(GuestRoleEnum),
          ) as GuestRoleEnum;
          result.role = valueDes;
          break;
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(GuestStatusEnum),
          ) as GuestStatusEnum;
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
  Guest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GuestBuilder();
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

class GuestRoleEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'owner')
  static const GuestRoleEnum owner = _$guestRoleEnum_owner;
  @BuiltValueEnumConst(wireName: r'guest')
  static const GuestRoleEnum guest = _$guestRoleEnum_guest;

  static Serializer<GuestRoleEnum> get serializer => _$guestRoleEnumSerializer;

  const GuestRoleEnum._(String name): super(name);

  static BuiltSet<GuestRoleEnum> get values => _$guestRoleEnumValues;
  static GuestRoleEnum valueOf(String name) => _$guestRoleEnumValueOf(name);
}

class GuestStatusEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'owner')
  static const GuestStatusEnum owner = _$guestStatusEnum_owner;
  @BuiltValueEnumConst(wireName: r'invited')
  static const GuestStatusEnum invited = _$guestStatusEnum_invited;
  @BuiltValueEnumConst(wireName: r'accepted')
  static const GuestStatusEnum accepted = _$guestStatusEnum_accepted;
  @BuiltValueEnumConst(wireName: r'rejected')
  static const GuestStatusEnum rejected = _$guestStatusEnum_rejected;

  static Serializer<GuestStatusEnum> get serializer => _$guestStatusEnumSerializer;

  const GuestStatusEnum._(String name): super(name);

  static BuiltSet<GuestStatusEnum> get values => _$guestStatusEnumValues;
  static GuestStatusEnum valueOf(String name) => _$guestStatusEnumValueOf(name);
}

