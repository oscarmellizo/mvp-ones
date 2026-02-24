// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guest.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const GuestRoleEnum _$guestRoleEnum_owner = const GuestRoleEnum._('owner');
const GuestRoleEnum _$guestRoleEnum_guest = const GuestRoleEnum._('guest');

GuestRoleEnum _$guestRoleEnumValueOf(String name) {
  switch (name) {
    case 'owner':
      return _$guestRoleEnum_owner;
    case 'guest':
      return _$guestRoleEnum_guest;
    default:
      throw new ArgumentError(name);
  }
}

final BuiltSet<GuestRoleEnum> _$guestRoleEnumValues =
    new BuiltSet<GuestRoleEnum>(const <GuestRoleEnum>[
  _$guestRoleEnum_owner,
  _$guestRoleEnum_guest,
]);

const GuestStatusEnum _$guestStatusEnum_owner =
    const GuestStatusEnum._('owner');
const GuestStatusEnum _$guestStatusEnum_invited =
    const GuestStatusEnum._('invited');
const GuestStatusEnum _$guestStatusEnum_accepted =
    const GuestStatusEnum._('accepted');
const GuestStatusEnum _$guestStatusEnum_rejected =
    const GuestStatusEnum._('rejected');

GuestStatusEnum _$guestStatusEnumValueOf(String name) {
  switch (name) {
    case 'owner':
      return _$guestStatusEnum_owner;
    case 'invited':
      return _$guestStatusEnum_invited;
    case 'accepted':
      return _$guestStatusEnum_accepted;
    case 'rejected':
      return _$guestStatusEnum_rejected;
    default:
      throw new ArgumentError(name);
  }
}

final BuiltSet<GuestStatusEnum> _$guestStatusEnumValues =
    new BuiltSet<GuestStatusEnum>(const <GuestStatusEnum>[
  _$guestStatusEnum_owner,
  _$guestStatusEnum_invited,
  _$guestStatusEnum_accepted,
  _$guestStatusEnum_rejected,
]);

Serializer<GuestRoleEnum> _$guestRoleEnumSerializer =
    new _$GuestRoleEnumSerializer();
Serializer<GuestStatusEnum> _$guestStatusEnumSerializer =
    new _$GuestStatusEnumSerializer();

class _$GuestRoleEnumSerializer implements PrimitiveSerializer<GuestRoleEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'owner': 'owner',
    'guest': 'guest',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'owner': 'owner',
    'guest': 'guest',
  };

  @override
  final Iterable<Type> types = const <Type>[GuestRoleEnum];
  @override
  final String wireName = 'GuestRoleEnum';

  @override
  Object serialize(Serializers serializers, GuestRoleEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  GuestRoleEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      GuestRoleEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$GuestStatusEnumSerializer
    implements PrimitiveSerializer<GuestStatusEnum> {
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
  final Iterable<Type> types = const <Type>[GuestStatusEnum];
  @override
  final String wireName = 'GuestStatusEnum';

  @override
  Object serialize(Serializers serializers, GuestStatusEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  GuestStatusEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      GuestStatusEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$Guest extends Guest {
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final GuestRoleEnum role;
  @override
  final GuestStatusEnum status;

  factory _$Guest([void Function(GuestBuilder)? updates]) =>
      (new GuestBuilder()..update(updates))._build();

  _$Guest._(
      {this.email, this.displayName, required this.role, required this.status})
      : super._() {
    BuiltValueNullFieldError.checkNotNull(role, r'Guest', 'role');
    BuiltValueNullFieldError.checkNotNull(status, r'Guest', 'status');
  }

  @override
  Guest rebuild(void Function(GuestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  GuestBuilder toBuilder() => new GuestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Guest &&
        email == other.email &&
        displayName == other.displayName &&
        role == other.role &&
        status == other.status;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, email.hashCode);
    _$hash = $jc(_$hash, displayName.hashCode);
    _$hash = $jc(_$hash, role.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Guest')
          ..add('email', email)
          ..add('displayName', displayName)
          ..add('role', role)
          ..add('status', status))
        .toString();
  }
}

class GuestBuilder implements Builder<Guest, GuestBuilder> {
  _$Guest? _$v;

  String? _email;
  String? get email => _$this._email;
  set email(String? email) => _$this._email = email;

  String? _displayName;
  String? get displayName => _$this._displayName;
  set displayName(String? displayName) => _$this._displayName = displayName;

  GuestRoleEnum? _role;
  GuestRoleEnum? get role => _$this._role;
  set role(GuestRoleEnum? role) => _$this._role = role;

  GuestStatusEnum? _status;
  GuestStatusEnum? get status => _$this._status;
  set status(GuestStatusEnum? status) => _$this._status = status;

  GuestBuilder() {
    Guest._defaults(this);
  }

  GuestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _email = $v.email;
      _displayName = $v.displayName;
      _role = $v.role;
      _status = $v.status;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Guest other) {
    ArgumentError.checkNotNull(other, 'other');
    _$v = other as _$Guest;
  }

  @override
  void update(void Function(GuestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Guest build() => _build();

  _$Guest _build() {
    final _$result = _$v ??
        new _$Guest._(
            email: email,
            displayName: displayName,
            role: BuiltValueNullFieldError.checkNotNull(role, r'Guest', 'role'),
            status: BuiltValueNullFieldError.checkNotNull(
                status, r'Guest', 'status'));
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
