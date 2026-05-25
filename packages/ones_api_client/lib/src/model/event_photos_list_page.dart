//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ones_api_client/src/model/event_photo_list_item.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'event_photos_list_page.g.dart';

/// EventPhotosListPage
///
/// Properties:
/// * [items] 
/// * [nextToken] - Pagination cursor (opaque). Null when there are no more results.
@BuiltValue()
abstract class EventPhotosListPage implements Built<EventPhotosListPage, EventPhotosListPageBuilder> {
  @BuiltValueField(wireName: r'items')
  BuiltList<EventPhotoListItem> get items;

  /// Pagination cursor (opaque). Null when there are no more results.
  @BuiltValueField(wireName: r'nextToken')
  String? get nextToken;

  EventPhotosListPage._();

  factory EventPhotosListPage([void updates(EventPhotosListPageBuilder b)]) = _$EventPhotosListPage;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(EventPhotosListPageBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<EventPhotosListPage> get serializer => _$EventPhotosListPageSerializer();
}

class _$EventPhotosListPageSerializer implements PrimitiveSerializer<EventPhotosListPage> {
  @override
  final Iterable<Type> types = const [EventPhotosListPage, _$EventPhotosListPage];

  @override
  final String wireName = r'EventPhotosListPage';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    EventPhotosListPage object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'items';
    yield serializers.serialize(
      object.items,
      specifiedType: const FullType(BuiltList, [FullType(EventPhotoListItem)]),
    );
    if (object.nextToken != null) {
      yield r'nextToken';
      yield serializers.serialize(
        object.nextToken,
        specifiedType: const FullType.nullable(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    EventPhotosListPage object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required EventPhotosListPageBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'items':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(EventPhotoListItem)]),
          ) as BuiltList<EventPhotoListItem>;
          result.items.replace(valueDes);
          break;
        case r'nextToken':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.nextToken = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  EventPhotosListPage deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = EventPhotosListPageBuilder();
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

