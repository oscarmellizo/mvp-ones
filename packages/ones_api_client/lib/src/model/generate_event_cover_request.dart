//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'generate_event_cover_request.g.dart';

/// GenerateEventCoverRequest
///
/// Properties:
/// * [eventName] 
/// * [categoryLabel] 
/// * [eventTypeLabel] 
/// * [location] 
/// * [size] - Image size; backend may ignore unsupported values
@BuiltValue()
abstract class GenerateEventCoverRequest implements Built<GenerateEventCoverRequest, GenerateEventCoverRequestBuilder> {
  @BuiltValueField(wireName: r'eventName')
  String get eventName;

  @BuiltValueField(wireName: r'categoryLabel')
  String get categoryLabel;

  @BuiltValueField(wireName: r'eventTypeLabel')
  String get eventTypeLabel;

  @BuiltValueField(wireName: r'location')
  String get location;

  /// Image size; backend may ignore unsupported values
  @BuiltValueField(wireName: r'size')
  String? get size;

  GenerateEventCoverRequest._();

  factory GenerateEventCoverRequest([void updates(GenerateEventCoverRequestBuilder b)]) = _$GenerateEventCoverRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(GenerateEventCoverRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<GenerateEventCoverRequest> get serializer => _$GenerateEventCoverRequestSerializer();
}

class _$GenerateEventCoverRequestSerializer implements PrimitiveSerializer<GenerateEventCoverRequest> {
  @override
  final Iterable<Type> types = const [GenerateEventCoverRequest, _$GenerateEventCoverRequest];

  @override
  final String wireName = r'GenerateEventCoverRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    GenerateEventCoverRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'eventName';
    yield serializers.serialize(
      object.eventName,
      specifiedType: const FullType(String),
    );
    yield r'categoryLabel';
    yield serializers.serialize(
      object.categoryLabel,
      specifiedType: const FullType(String),
    );
    yield r'eventTypeLabel';
    yield serializers.serialize(
      object.eventTypeLabel,
      specifiedType: const FullType(String),
    );
    yield r'location';
    yield serializers.serialize(
      object.location,
      specifiedType: const FullType(String),
    );
    if (object.size != null) {
      yield r'size';
      yield serializers.serialize(
        object.size,
        specifiedType: const FullType(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    GenerateEventCoverRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required GenerateEventCoverRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'eventName':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.eventName = valueDes;
          break;
        case r'categoryLabel':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.categoryLabel = valueDes;
          break;
        case r'eventTypeLabel':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.eventTypeLabel = valueDes;
          break;
        case r'location':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.location = valueDes;
          break;
        case r'size':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.size = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  GenerateEventCoverRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GenerateEventCoverRequestBuilder();
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

