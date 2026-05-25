// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guest_v2.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const GuestV2RoleEnum _$guestV2RoleEnum_owner =
    const GuestV2RoleEnum._('owner');
const GuestV2RoleEnum _$guestV2RoleEnum_guest =
    const GuestV2RoleEnum._('guest');

GuestV2RoleEnum _$guestV2RoleEnumValueOf(String name) {
  switch (name) {
    case 'owner':
      return _$guestV2RoleEnum_owner;
    case 'guest':
      return _$guestV2RoleEnum_guest;
    default:
      throw new ArgumentError(name);
  }
}

final BuiltSet<GuestV2RoleEnum> _$guestV2RoleEnumValues =
    new BuiltSet<GuestV2RoleEnum>(const <GuestV2RoleEnum>[
  _$guestV2RoleEnum_owner,
  _$guestV2RoleEnum_guest,
]);

const GuestV2StatusEnum _$guestV2StatusEnum_owner =
    const GuestV2StatusEnum._('owner');
const GuestV2StatusEnum _$guestV2StatusEnum_invited =
    const GuestV2StatusEnum._('invited');
const GuestV2StatusEnum _$guestV2StatusEnum_accepted =
    const GuestV2StatusEnum._('accepted');
const GuestV2StatusEnum _$guestV2StatusEnum_rejected =
    const GuestV2StatusEnum._('rejected');

GuestV2StatusEnum _$guestV2StatusEnumValueOf(String name) {
  switch (name) {
    case 'owner':
      return _$guestV2StatusEnum_owner;
    case 'invited':
      return _$guestV2StatusEnum_invited;
    case 'accepted':
      return _$guestV2StatusEnum_accepted;
    case 'rejected':
      return _$guestV2StatusEnum_rejected;
    default:
      throw new ArgumentError(name);
  }
}

final BuiltSet<GuestV2StatusEnum> _$guestV2StatusEnumValues =
    new BuiltSet<GuestV2StatusEnum>(const <GuestV2StatusEnum>[
  _$guestV2StatusEnum_owner,
  _$guestV2StatusEnum_invited,
  _$guestV2StatusEnum_accepted,
  _$guestV2StatusEnum_rejected,
]);

Serializer<GuestV2RoleEnum> _$guestV2RoleEnumSerializer =
    new _$GuestV2RoleEnumSerializer();
Serializer<GuestV2StatusEnum> _$guestV2StatusEnumSerializer =
    new _$GuestV2StatusEnumSerializer();

class _$GuestV2RoleEnumSerializer
    implements PrimitiveSerializer<GuestV2RoleEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'owner': 'owner',
    'guest': 'guest',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'owner': 'owner',
    'guest': 'guest',
  };

  @override
  final Iterable<Type> types = const <Type>[GuestV2RoleEnum];
  @override
  final String wireName = 'GuestV2RoleEnum';

  @override
  Object serialize(Serializers serializers, GuestV2RoleEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  GuestV2RoleEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      GuestV2RoleEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$GuestV2StatusEnumSerializer
    implements PrimitiveSerializer<GuestV2StatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'owner': 'owner',
    'invited': 'invited',
    'accepted': 'accepted',
    'rejected': 'rejected',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'owner': 'owner',
    'invited': 'invited',
    'accepted': 'accepted',
    'rejected': 'rejected',
  };

  @override
  final Iterable<Type> types = const <Type>[GuestV2StatusEnum];
  @override
  final String wireName = 'GuestV2StatusEnum';

  @override
  Object serialize(Serializers serializers, GuestV2StatusEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  GuestV2StatusEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      GuestV2StatusEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$GuestV2 extends GuestV2 {
  @override
  final String? userId;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final GuestV2RoleEnum role;
  @override
  final GuestV2StatusEnum status;

  factory _$GuestV2([void Function(GuestV2Builder)? updates]) =>
      (new GuestV2Builder()..update(updates))._build();

  _$GuestV2._(
      {this.userId,
      this.email,
      this.displayName,
      required this.role,
      required this.status})
      : super._() {
    BuiltValueNullFieldError.checkNotNull(role, r'GuestV2', 'role');
    BuiltValueNullFieldError.checkNotNull(status, r'GuestV2', 'status');
  }

  @override
  GuestV2 rebuild(void Function(GuestV2Builder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  GuestV2Builder toBuilder() => new GuestV2Builder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is GuestV2 &&
        userId == other.userId &&
        email == other.email &&
        displayName == other.displayName &&
        role == other.role &&
        status == other.status;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, userId.hashCode);
    _$hash = $jc(_$hash, email.hashCode);
    _$hash = $jc(_$hash, displayName.hashCode);
    _$hash = $jc(_$hash, role.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'GuestV2')
          ..add('userId', userId)
          ..add('email', email)
          ..add('displayName', displayName)
          ..add('role', role)
          ..add('status', status))
        .toString();
  }
}

class GuestV2Builder implements Builder<GuestV2, GuestV2Builder> {
  _$GuestV2? _$v;

  String? _userId;
  String? get userId => _$this._userId;
  set userId(String? userId) => _$this._userId = userId;

  String? _email;
  String? get email => _$this._email;
  set email(String? email) => _$this._email = email;

  String? _displayName;
  String? get displayName => _$this._displayName;
  set displayName(String? displayName) => _$this._displayName = displayName;

  GuestV2RoleEnum? _role;
  GuestV2RoleEnum? get role => _$this._role;
  set role(GuestV2RoleEnum? role) => _$this._role = role;

  GuestV2StatusEnum? _status;
  GuestV2StatusEnum? get status => _$this._status;
  set status(GuestV2StatusEnum? status) => _$this._status = status;

  GuestV2Builder() {
    GuestV2._defaults(this);
  }

  GuestV2Builder get _$this {
    final $v = _$v;
    if ($v != null) {
      _userId = $v.userId;
      _email = $v.email;
      _displayName = $v.displayName;
      _role = $v.role;
      _status = $v.status;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(GuestV2 other) {
    ArgumentError.checkNotNull(other, 'other');
    _$v = other as _$GuestV2;
  }

  @override
  void update(void Function(GuestV2Builder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  GuestV2 build() => _build();

  _$GuestV2 _build() {
    final _$result = _$v ??
        new _$GuestV2._(
            userId: userId,
            email: email,
            displayName: displayName,
            role:
                BuiltValueNullFieldError.checkNotNull(role, r'GuestV2', 'role'),
            status: BuiltValueNullFieldError.checkNotNull(
                status, r'GuestV2', 'status'));
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
