// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_event_cover_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SetEventCoverRequestSource_Enum _$setEventCoverRequestSourceEnum_upload =
    const SetEventCoverRequestSource_Enum._('upload');
const SetEventCoverRequestSource_Enum _$setEventCoverRequestSourceEnum_photo =
    const SetEventCoverRequestSource_Enum._('photo');

SetEventCoverRequestSource_Enum _$setEventCoverRequestSourceEnumValueOf(
    String name) {
  switch (name) {
    case 'upload':
      return _$setEventCoverRequestSourceEnum_upload;
    case 'photo':
      return _$setEventCoverRequestSourceEnum_photo;
    default:
      throw new ArgumentError(name);
  }
}

final BuiltSet<SetEventCoverRequestSource_Enum>
    _$setEventCoverRequestSourceEnumValues = new BuiltSet<
        SetEventCoverRequestSource_Enum>(const <SetEventCoverRequestSource_Enum>[
  _$setEventCoverRequestSourceEnum_upload,
  _$setEventCoverRequestSourceEnum_photo,
]);

Serializer<SetEventCoverRequestSource_Enum>
    _$setEventCoverRequestSourceEnumSerializer =
    new _$SetEventCoverRequestSource_EnumSerializer();

class _$SetEventCoverRequestSource_EnumSerializer
    implements PrimitiveSerializer<SetEventCoverRequestSource_Enum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'upload': 'upload',
    'photo': 'photo',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'upload': 'upload',
    'photo': 'photo',
  };

  @override
  final Iterable<Type> types = const <Type>[SetEventCoverRequestSource_Enum];
  @override
  final String wireName = 'SetEventCoverRequestSource_Enum';

  @override
  Object serialize(
          Serializers serializers, SetEventCoverRequestSource_Enum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  SetEventCoverRequestSource_Enum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      SetEventCoverRequestSource_Enum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$SetEventCoverRequest extends SetEventCoverRequest {
  @override
  final SetEventCoverRequestSource_Enum source_;
  @override
  final String? uploadKey;
  @override
  final String? photoId;

  factory _$SetEventCoverRequest(
          [void Function(SetEventCoverRequestBuilder)? updates]) =>
      (new SetEventCoverRequestBuilder()..update(updates))._build();

  _$SetEventCoverRequest._(
      {required this.source_, this.uploadKey, this.photoId})
      : super._() {
    BuiltValueNullFieldError.checkNotNull(
        source_, r'SetEventCoverRequest', 'source_');
  }

  @override
  SetEventCoverRequest rebuild(
          void Function(SetEventCoverRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SetEventCoverRequestBuilder toBuilder() =>
      new SetEventCoverRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SetEventCoverRequest &&
        source_ == other.source_ &&
        uploadKey == other.uploadKey &&
        photoId == other.photoId;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, source_.hashCode);
    _$hash = $jc(_$hash, uploadKey.hashCode);
    _$hash = $jc(_$hash, photoId.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SetEventCoverRequest')
          ..add('source_', source_)
          ..add('uploadKey', uploadKey)
          ..add('photoId', photoId))
        .toString();
  }
}

class SetEventCoverRequestBuilder
    implements Builder<SetEventCoverRequest, SetEventCoverRequestBuilder> {
  _$SetEventCoverRequest? _$v;

  SetEventCoverRequestSource_Enum? _source_;
  SetEventCoverRequestSource_Enum? get source_ => _$this._source_;
  set source_(SetEventCoverRequestSource_Enum? source_) =>
      _$this._source_ = source_;

  String? _uploadKey;
  String? get uploadKey => _$this._uploadKey;
  set uploadKey(String? uploadKey) => _$this._uploadKey = uploadKey;

  String? _photoId;
  String? get photoId => _$this._photoId;
  set photoId(String? photoId) => _$this._photoId = photoId;

  SetEventCoverRequestBuilder() {
    SetEventCoverRequest._defaults(this);
  }

  SetEventCoverRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _source_ = $v.source_;
      _uploadKey = $v.uploadKey;
      _photoId = $v.photoId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SetEventCoverRequest other) {
    ArgumentError.checkNotNull(other, 'other');
    _$v = other as _$SetEventCoverRequest;
  }

  @override
  void update(void Function(SetEventCoverRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SetEventCoverRequest build() => _build();

  _$SetEventCoverRequest _build() {
    final _$result = _$v ??
        new _$SetEventCoverRequest._(
            source_: BuiltValueNullFieldError.checkNotNull(
                source_, r'SetEventCoverRequest', 'source_'),
            uploadKey: uploadKey,
            photoId: photoId);
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
