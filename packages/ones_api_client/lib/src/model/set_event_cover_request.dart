//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'set_event_cover_request.g.dart';

/// SetEventCoverRequest
///
/// Properties:
/// * [source_] 
/// * [uploadKey] - S3 key returned by presignEventCoverUpload when source=upload
/// * [photoId] - Event photoId to use as cover when source=photo
@BuiltValue()
abstract class SetEventCoverRequest implements Built<SetEventCoverRequest, SetEventCoverRequestBuilder> {
  @BuiltValueField(wireName: r'source')
  SetEventCoverRequestSource_Enum get source_;
  // enum source_Enum {  upload,  photo,  };

  /// S3 key returned by presignEventCoverUpload when source=upload
  @BuiltValueField(wireName: r'uploadKey')
  String? get uploadKey;

  /// Event photoId to use as cover when source=photo
  @BuiltValueField(wireName: r'photoId')
  String? get photoId;

  SetEventCoverRequest._();

  factory SetEventCoverRequest([void updates(SetEventCoverRequestBuilder b)]) = _$SetEventCoverRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SetEventCoverRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SetEventCoverRequest> get serializer => _$SetEventCoverRequestSerializer();
}

class _$SetEventCoverRequestSerializer implements PrimitiveSerializer<SetEventCoverRequest> {
  @override
  final Iterable<Type> types = const [SetEventCoverRequest, _$SetEventCoverRequest];

  @override
  final String wireName = r'SetEventCoverRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SetEventCoverRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'source';
    yield serializers.serialize(
      object.source_,
      specifiedType: const FullType(SetEventCoverRequestSource_Enum),
    );
    if (object.uploadKey != null) {
      yield r'uploadKey';
      yield serializers.serialize(
        object.uploadKey,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.photoId != null) {
      yield r'photoId';
      yield serializers.serialize(
        object.photoId,
        specifiedType: const FullType.nullable(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    SetEventCoverRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required SetEventCoverRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'source':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(SetEventCoverRequestSource_Enum),
          ) as SetEventCoverRequestSource_Enum;
          result.source_ = valueDes;
          break;
        case r'uploadKey':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.uploadKey = valueDes;
          break;
        case r'photoId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.photoId = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SetEventCoverRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SetEventCoverRequestBuilder();
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

class SetEventCoverRequestSource_Enum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'upload')
  static const SetEventCoverRequestSource_Enum upload = _$setEventCoverRequestSourceEnum_upload;
  @BuiltValueEnumConst(wireName: r'photo')
  static const SetEventCoverRequestSource_Enum photo = _$setEventCoverRequestSourceEnum_photo;

  static Serializer<SetEventCoverRequestSource_Enum> get serializer => _$setEventCoverRequestSourceEnumSerializer;

  const SetEventCoverRequestSource_Enum._(String name): super(name);

  static BuiltSet<SetEventCoverRequestSource_Enum> get values => _$setEventCoverRequestSourceEnumValues;
  static SetEventCoverRequestSource_Enum valueOf(String name) => _$setEventCoverRequestSourceEnumValueOf(name);
}

