//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'presign_event_cover_upload_request.g.dart';

/// PresignEventCoverUploadRequest
///
/// Properties:
/// * [contentType] 
@BuiltValue()
abstract class PresignEventCoverUploadRequest implements Built<PresignEventCoverUploadRequest, PresignEventCoverUploadRequestBuilder> {
  @BuiltValueField(wireName: r'contentType')
  PresignEventCoverUploadRequestContentTypeEnum get contentType;
  // enum contentTypeEnum {  image/jpeg,  image/png,  };

  PresignEventCoverUploadRequest._();

  factory PresignEventCoverUploadRequest([void updates(PresignEventCoverUploadRequestBuilder b)]) = _$PresignEventCoverUploadRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PresignEventCoverUploadRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PresignEventCoverUploadRequest> get serializer => _$PresignEventCoverUploadRequestSerializer();
}

class _$PresignEventCoverUploadRequestSerializer implements PrimitiveSerializer<PresignEventCoverUploadRequest> {
  @override
  final Iterable<Type> types = const [PresignEventCoverUploadRequest, _$PresignEventCoverUploadRequest];

  @override
  final String wireName = r'PresignEventCoverUploadRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PresignEventCoverUploadRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'contentType';
    yield serializers.serialize(
      object.contentType,
      specifiedType: const FullType(PresignEventCoverUploadRequestContentTypeEnum),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    PresignEventCoverUploadRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required PresignEventCoverUploadRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'contentType':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(PresignEventCoverUploadRequestContentTypeEnum),
          ) as PresignEventCoverUploadRequestContentTypeEnum;
          result.contentType = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  PresignEventCoverUploadRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PresignEventCoverUploadRequestBuilder();
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

class PresignEventCoverUploadRequestContentTypeEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'image/jpeg')
  static const PresignEventCoverUploadRequestContentTypeEnum jpeg = _$presignEventCoverUploadRequestContentTypeEnum_jpeg;
  @BuiltValueEnumConst(wireName: r'image/png')
  static const PresignEventCoverUploadRequestContentTypeEnum png = _$presignEventCoverUploadRequestContentTypeEnum_png;

  static Serializer<PresignEventCoverUploadRequestContentTypeEnum> get serializer => _$presignEventCoverUploadRequestContentTypeEnumSerializer;

  const PresignEventCoverUploadRequestContentTypeEnum._(String name): super(name);

  static BuiltSet<PresignEventCoverUploadRequestContentTypeEnum> get values => _$presignEventCoverUploadRequestContentTypeEnumValues;
  static PresignEventCoverUploadRequestContentTypeEnum valueOf(String name) => _$presignEventCoverUploadRequestContentTypeEnumValueOf(name);
}

