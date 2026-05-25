//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'create_event_request.g.dart';

/// CreateEventRequest
///
/// Properties:
/// * [title] 
/// * [objective] 
/// * [location] 
/// * [startAt] 
/// * [endAt] 
/// * [coverReservationId] - Reservation id obtained after accepting an AI-generated cover (optional)
/// * [inviteeEmails] - Invitee emails (lowercased). For each email, an invitation is created with status 'invited'.
/// * [allowGuestInvites] - Whether accepted guests (non-owner) are allowed to invite other guests.
@BuiltValue()
abstract class CreateEventRequest implements Built<CreateEventRequest, CreateEventRequestBuilder> {
  @BuiltValueField(wireName: r'title')
  String get title;

  @BuiltValueField(wireName: r'objective')
  String get objective;

  @BuiltValueField(wireName: r'location')
  String get location;

  @BuiltValueField(wireName: r'startAt')
  DateTime get startAt;

  @BuiltValueField(wireName: r'endAt')
  DateTime get endAt;

  /// Reservation id obtained after accepting an AI-generated cover (optional)
  @BuiltValueField(wireName: r'coverReservationId')
  String? get coverReservationId;

  /// Invitee emails (lowercased). For each email, an invitation is created with status 'invited'.
  @BuiltValueField(wireName: r'inviteeEmails')
  BuiltList<String>? get inviteeEmails;

  /// Whether accepted guests (non-owner) are allowed to invite other guests.
  @BuiltValueField(wireName: r'allowGuestInvites')
  bool? get allowGuestInvites;

  CreateEventRequest._();

  factory CreateEventRequest([void updates(CreateEventRequestBuilder b)]) = _$CreateEventRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CreateEventRequestBuilder b) => b
      ..allowGuestInvites = true;

  @BuiltValueSerializer(custom: true)
  static Serializer<CreateEventRequest> get serializer => _$CreateEventRequestSerializer();
}

class _$CreateEventRequestSerializer implements PrimitiveSerializer<CreateEventRequest> {
  @override
  final Iterable<Type> types = const [CreateEventRequest, _$CreateEventRequest];

  @override
  final String wireName = r'CreateEventRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CreateEventRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'title';
    yield serializers.serialize(
      object.title,
      specifiedType: const FullType(String),
    );
    yield r'objective';
    yield serializers.serialize(
      object.objective,
      specifiedType: const FullType(String),
    );
    yield r'location';
    yield serializers.serialize(
      object.location,
      specifiedType: const FullType(String),
    );
    yield r'startAt';
    yield serializers.serialize(
      object.startAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'endAt';
    yield serializers.serialize(
      object.endAt,
      specifiedType: const FullType(DateTime),
    );
    if (object.coverReservationId != null) {
      yield r'coverReservationId';
      yield serializers.serialize(
        object.coverReservationId,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.inviteeEmails != null) {
      yield r'inviteeEmails';
      yield serializers.serialize(
        object.inviteeEmails,
        specifiedType: const FullType(BuiltList, [FullType(String)]),
      );
    }
    if (object.allowGuestInvites != null) {
      yield r'allowGuestInvites';
      yield serializers.serialize(
        object.allowGuestInvites,
        specifiedType: const FullType(bool),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    CreateEventRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required CreateEventRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'title':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.title = valueDes;
          break;
        case r'objective':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.objective = valueDes;
          break;
        case r'location':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.location = valueDes;
          break;
        case r'startAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.startAt = valueDes;
          break;
        case r'endAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.endAt = valueDes;
          break;
        case r'coverReservationId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.coverReservationId = valueDes;
          break;
        case r'inviteeEmails':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(String)]),
          ) as BuiltList<String>;
          result.inviteeEmails.replace(valueDes);
          break;
        case r'allowGuestInvites':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.allowGuestInvites = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CreateEventRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CreateEventRequestBuilder();
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

