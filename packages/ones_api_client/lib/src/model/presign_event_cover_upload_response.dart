//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'presign_event_cover_upload_response.g.dart';

/// PresignEventCoverUploadResponse
///
/// Properties:
/// * [uploadUrl] 
/// * [uploadKey] 
/// * [expiresAt] 
@BuiltValue()
abstract class PresignEventCoverUploadResponse implements Built<PresignEventCoverUploadResponse, PresignEventCoverUploadResponseBuilder> {
  @BuiltValueField(wireName: r'uploadUrl')
  String get uploadUrl;

  @BuiltValueField(wireName: r'uploadKey')
  String get uploadKey;

  @BuiltValueField(wireName: r'expiresAt')
  DateTime get expiresAt;

  PresignEventCoverUploadResponse._();

  factory PresignEventCoverUploadResponse([void updates(PresignEventCoverUploadResponseBuilder b)]) = _$PresignEventCoverUploadResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PresignEventCoverUploadResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PresignEventCoverUploadResponse> get serializer => _$PresignEventCoverUploadResponseSerializer();
}

class _$PresignEventCoverUploadResponseSerializer implements PrimitiveSerializer<PresignEventCoverUploadResponse> {
  @override
  final Iterable<Type> types = const [PresignEventCoverUploadResponse, _$PresignEventCoverUploadResponse];

  @override
  final String wireName = r'PresignEventCoverUploadResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PresignEventCoverUploadResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'uploadUrl';
    yield serializers.serialize(
      object.uploadUrl,
      specifiedType: const FullType(String),
    );
    yield r'uploadKey';
    yield serializers.serialize(
      object.uploadKey,
      specifiedType: const FullType(String),
    );
    yield r'expiresAt';
    yield serializers.serialize(
      object.expiresAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    PresignEventCoverUploadResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required PresignEventCoverUploadResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'uploadUrl':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.uploadUrl = valueDes;
          break;
        case r'uploadKey':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.uploadKey = valueDes;
          break;
        case r'expiresAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.expiresAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  PresignEventCoverUploadResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PresignEventCoverUploadResponseBuilder();
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

