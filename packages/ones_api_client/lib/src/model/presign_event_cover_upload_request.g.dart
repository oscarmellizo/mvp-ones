// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'presign_event_cover_upload_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const PresignEventCoverUploadRequestContentTypeEnum
    _$presignEventCoverUploadRequestContentTypeEnum_jpeg =
    const PresignEventCoverUploadRequestContentTypeEnum._('jpeg');
const PresignEventCoverUploadRequestContentTypeEnum
    _$presignEventCoverUploadRequestContentTypeEnum_png =
    const PresignEventCoverUploadRequestContentTypeEnum._('png');

PresignEventCoverUploadRequestContentTypeEnum
    _$presignEventCoverUploadRequestContentTypeEnumValueOf(String name) {
  switch (name) {
    case 'jpeg':
      return _$presignEventCoverUploadRequestContentTypeEnum_jpeg;
    case 'png':
      return _$presignEventCoverUploadRequestContentTypeEnum_png;
    default:
      throw new ArgumentError(name);
  }
}

final BuiltSet<PresignEventCoverUploadRequestContentTypeEnum>
    _$presignEventCoverUploadRequestContentTypeEnumValues = new BuiltSet<
        PresignEventCoverUploadRequestContentTypeEnum>(const <PresignEventCoverUploadRequestContentTypeEnum>[
  _$presignEventCoverUploadRequestContentTypeEnum_jpeg,
  _$presignEventCoverUploadRequestContentTypeEnum_png,
]);

Serializer<PresignEventCoverUploadRequestContentTypeEnum>
    _$presignEventCoverUploadRequestContentTypeEnumSerializer =
    new _$PresignEventCoverUploadRequestContentTypeEnumSerializer();

class _$PresignEventCoverUploadRequestContentTypeEnumSerializer
    implements
        PrimitiveSerializer<PresignEventCoverUploadRequestContentTypeEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'jpeg': 'image/jpeg',
    'png': 'image/png',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'image/jpeg': 'jpeg',
    'image/png': 'png',
  };

  @override
  final Iterable<Type> types = const <Type>[
    PresignEventCoverUploadRequestContentTypeEnum
  ];
  @override
  final String wireName = 'PresignEventCoverUploadRequestContentTypeEnum';

  @override
  Object serialize(Serializers serializers,
          PresignEventCoverUploadRequestContentTypeEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  PresignEventCoverUploadRequestContentTypeEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      PresignEventCoverUploadRequestContentTypeEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$PresignEventCoverUploadRequest extends PresignEventCoverUploadRequest {
  @override
  final PresignEventCoverUploadRequestContentTypeEnum contentType;

  factory _$PresignEventCoverUploadRequest(
          [void Function(PresignEventCoverUploadRequestBuilder)? updates]) =>
      (new PresignEventCoverUploadRequestBuilder()..update(updates))._build();

  _$PresignEventCoverUploadRequest._({required this.contentType}) : super._() {
    BuiltValueNullFieldError.checkNotNull(
        contentType, r'PresignEventCoverUploadRequest', 'contentType');
  }

  @override
  PresignEventCoverUploadRequest rebuild(
          void Function(PresignEventCoverUploadRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PresignEventCoverUploadRequestBuilder toBuilder() =>
      new PresignEventCoverUploadRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PresignEventCoverUploadRequest &&
        contentType == other.contentType;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, contentType.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PresignEventCoverUploadRequest')
          ..add('contentType', contentType))
        .toString();
  }
}

class PresignEventCoverUploadRequestBuilder
    implements
        Builder<PresignEventCoverUploadRequest,
            PresignEventCoverUploadRequestBuilder> {
  _$PresignEventCoverUploadRequest? _$v;

  PresignEventCoverUploadRequestContentTypeEnum? _contentType;
  PresignEventCoverUploadRequestContentTypeEnum? get contentType =>
      _$this._contentType;
  set contentType(PresignEventCoverUploadRequestContentTypeEnum? contentType) =>
      _$this._contentType = contentType;

  PresignEventCoverUploadRequestBuilder() {
    PresignEventCoverUploadRequest._defaults(this);
  }

  PresignEventCoverUploadRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _contentType = $v.contentType;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PresignEventCoverUploadRequest other) {
    ArgumentError.checkNotNull(other, 'other');
    _$v = other as _$PresignEventCoverUploadRequest;
  }

  @override
  void update(void Function(PresignEventCoverUploadRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PresignEventCoverUploadRequest build() => _build();

  _$PresignEventCoverUploadRequest _build() {
    final _$result = _$v ??
        new _$PresignEventCoverUploadRequest._(
            contentType: BuiltValueNullFieldError.checkNotNull(
                contentType, r'PresignEventCoverUploadRequest', 'contentType'));
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
