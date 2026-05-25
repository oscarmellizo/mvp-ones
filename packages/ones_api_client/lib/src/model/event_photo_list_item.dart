//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'event_photo_list_item.g.dart';

/// EventPhotoListItem
///
/// Properties:
/// * [photoId] 
/// * [guestId] - Owner userId for non-shared photos
/// * [createdAt] 
/// * [uploadedAt] 
/// * [status] 
/// * [originalUrl] 
/// * [mediumUrl] 
/// * [smallUrl] 
/// * [shared] 
/// * [ownerName] 
/// * [sharedByUserId] 
/// * [sharedByName] 
@BuiltValue()
abstract class EventPhotoListItem implements Built<EventPhotoListItem, EventPhotoListItemBuilder> {
  @BuiltValueField(wireName: r'photoId')
  String get photoId;

  /// Owner userId for non-shared photos
  @BuiltValueField(wireName: r'guestId')
  String? get guestId;

  @BuiltValueField(wireName: r'createdAt')
  DateTime get createdAt;

  @BuiltValueField(wireName: r'uploadedAt')
  DateTime? get uploadedAt;

  @BuiltValueField(wireName: r'status')
  String get status;

  @BuiltValueField(wireName: r'originalUrl')
  String? get originalUrl;

  @BuiltValueField(wireName: r'mediumUrl')
  String? get mediumUrl;

  @BuiltValueField(wireName: r'smallUrl')
  String? get smallUrl;

  @BuiltValueField(wireName: r'shared')
  bool get shared;

  @BuiltValueField(wireName: r'ownerName')
  String? get ownerName;

  @BuiltValueField(wireName: r'sharedByUserId')
  String? get sharedByUserId;

  @BuiltValueField(wireName: r'sharedByName')
  String? get sharedByName;

  EventPhotoListItem._();

  factory EventPhotoListItem([void updates(EventPhotoListItemBuilder b)]) = _$EventPhotoListItem;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(EventPhotoListItemBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<EventPhotoListItem> get serializer => _$EventPhotoListItemSerializer();
}

class _$EventPhotoListItemSerializer implements PrimitiveSerializer<EventPhotoListItem> {
  @override
  final Iterable<Type> types = const [EventPhotoListItem, _$EventPhotoListItem];

  @override
  final String wireName = r'EventPhotoListItem';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    EventPhotoListItem object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'photoId';
    yield serializers.serialize(
      object.photoId,
      specifiedType: const FullType(String),
    );
    if (object.guestId != null) {
      yield r'guestId';
      yield serializers.serialize(
        object.guestId,
        specifiedType: const FullType.nullable(String),
      );
    }
    yield r'createdAt';
    yield serializers.serialize(
      object.createdAt,
      specifiedType: const FullType(DateTime),
    );
    if (object.uploadedAt != null) {
      yield r'uploadedAt';
      yield serializers.serialize(
        object.uploadedAt,
        specifiedType: const FullType.nullable(DateTime),
      );
    }
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(String),
    );
    if (object.originalUrl != null) {
      yield r'originalUrl';
      yield serializers.serialize(
        object.originalUrl,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.mediumUrl != null) {
      yield r'mediumUrl';
      yield serializers.serialize(
        object.mediumUrl,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.smallUrl != null) {
      yield r'smallUrl';
      yield serializers.serialize(
        object.smallUrl,
        specifiedType: const FullType.nullable(String),
      );
    }
    yield r'shared';
    yield serializers.serialize(
      object.shared,
      specifiedType: const FullType(bool),
    );
    if (object.ownerName != null) {
      yield r'ownerName';
      yield serializers.serialize(
        object.ownerName,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.sharedByUserId != null) {
      yield r'sharedByUserId';
      yield serializers.serialize(
        object.sharedByUserId,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.sharedByName != null) {
      yield r'sharedByName';
      yield serializers.serialize(
        object.sharedByName,
        specifiedType: const FullType.nullable(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    EventPhotoListItem object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required EventPhotoListItemBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'photoId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.photoId = valueDes;
          break;
        case r'guestId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.guestId = valueDes;
          break;
        case r'createdAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.createdAt = valueDes;
          break;
        case r'uploadedAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DateTime),
          ) as DateTime?;
          if (valueDes == null) continue;
          result.uploadedAt = valueDes;
          break;
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.status = valueDes;
          break;
        case r'originalUrl':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.originalUrl = valueDes;
          break;
        case r'mediumUrl':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.mediumUrl = valueDes;
          break;
        case r'smallUrl':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.smallUrl = valueDes;
          break;
        case r'shared':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.shared = valueDes;
          break;
        case r'ownerName':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.ownerName = valueDes;
          break;
        case r'sharedByUserId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.sharedByUserId = valueDes;
          break;
        case r'sharedByName':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.sharedByName = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  EventPhotoListItem deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = EventPhotoListItemBuilder();
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

