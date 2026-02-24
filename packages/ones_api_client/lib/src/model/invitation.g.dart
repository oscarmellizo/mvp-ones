// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invitation.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const InvitationStatusEnum _$invitationStatusEnum_invited =
    const InvitationStatusEnum._('invited');
const InvitationStatusEnum _$invitationStatusEnum_accepted =
    const InvitationStatusEnum._('accepted');
const InvitationStatusEnum _$invitationStatusEnum_rejected =
    const InvitationStatusEnum._('rejected');

InvitationStatusEnum _$invitationStatusEnumValueOf(String name) {
  switch (name) {
    case 'invited':
      return _$invitationStatusEnum_invited;
    case 'accepted':
      return _$invitationStatusEnum_accepted;
    case 'rejected':
      return _$invitationStatusEnum_rejected;
    default:
      throw new ArgumentError(name);
  }
}

final BuiltSet<InvitationStatusEnum> _$invitationStatusEnumValues =
    new BuiltSet<InvitationStatusEnum>(const <InvitationStatusEnum>[
  _$invitationStatusEnum_invited,
  _$invitationStatusEnum_accepted,
  _$invitationStatusEnum_rejected,
]);

Serializer<InvitationStatusEnum> _$invitationStatusEnumSerializer =
    new _$InvitationStatusEnumSerializer();

class _$InvitationStatusEnumSerializer
    implements PrimitiveSerializer<InvitationStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'invited': 'invited',
    'accepted': 'accepted',
    'rejected': 'rejected',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'invited': 'invited',
    'accepted': 'accepted',
    'rejected': 'rejected',
  };

  @override
  final Iterable<Type> types = const <Type>[InvitationStatusEnum];
  @override
  final String wireName = 'InvitationStatusEnum';

  @override
  Object serialize(Serializers serializers, InvitationStatusEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  InvitationStatusEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      InvitationStatusEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$Invitation extends Invitation {
  @override
  final String eventId;
  @override
  final String inviteeEmail;
  @override
  final String? inviteeUserId;
  @override
  final String? eventOwnerId;
  @override
  final InvitationStatusEnum status;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final String eventTitle;
  @override
  final String? eventLocation;
  @override
  final DateTime eventStartAt;
  @override
  final DateTime eventEndAt;

  factory _$Invitation([void Function(InvitationBuilder)? updates]) =>
      (new InvitationBuilder()..update(updates))._build();

  _$Invitation._(
      {required this.eventId,
      required this.inviteeEmail,
      this.inviteeUserId,
      this.eventOwnerId,
      required this.status,
      required this.createdAt,
      required this.updatedAt,
      required this.eventTitle,
      this.eventLocation,
      required this.eventStartAt,
      required this.eventEndAt})
      : super._() {
    BuiltValueNullFieldError.checkNotNull(eventId, r'Invitation', 'eventId');
    BuiltValueNullFieldError.checkNotNull(
        inviteeEmail, r'Invitation', 'inviteeEmail');
    BuiltValueNullFieldError.checkNotNull(status, r'Invitation', 'status');
    BuiltValueNullFieldError.checkNotNull(
        createdAt, r'Invitation', 'createdAt');
    BuiltValueNullFieldError.checkNotNull(
        updatedAt, r'Invitation', 'updatedAt');
    BuiltValueNullFieldError.checkNotNull(
        eventTitle, r'Invitation', 'eventTitle');
    BuiltValueNullFieldError.checkNotNull(
        eventStartAt, r'Invitation', 'eventStartAt');
    BuiltValueNullFieldError.checkNotNull(
        eventEndAt, r'Invitation', 'eventEndAt');
  }

  @override
  Invitation rebuild(void Function(InvitationBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  InvitationBuilder toBuilder() => new InvitationBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Invitation &&
        eventId == other.eventId &&
        inviteeEmail == other.inviteeEmail &&
        inviteeUserId == other.inviteeUserId &&
        eventOwnerId == other.eventOwnerId &&
        status == other.status &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt &&
        eventTitle == other.eventTitle &&
        eventLocation == other.eventLocation &&
        eventStartAt == other.eventStartAt &&
        eventEndAt == other.eventEndAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, eventId.hashCode);
    _$hash = $jc(_$hash, inviteeEmail.hashCode);
    _$hash = $jc(_$hash, inviteeUserId.hashCode);
    _$hash = $jc(_$hash, eventOwnerId.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jc(_$hash, eventTitle.hashCode);
    _$hash = $jc(_$hash, eventLocation.hashCode);
    _$hash = $jc(_$hash, eventStartAt.hashCode);
    _$hash = $jc(_$hash, eventEndAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Invitation')
          ..add('eventId', eventId)
          ..add('inviteeEmail', inviteeEmail)
          ..add('inviteeUserId', inviteeUserId)
          ..add('eventOwnerId', eventOwnerId)
          ..add('status', status)
          ..add('createdAt', createdAt)
          ..add('updatedAt', updatedAt)
          ..add('eventTitle', eventTitle)
          ..add('eventLocation', eventLocation)
          ..add('eventStartAt', eventStartAt)
          ..add('eventEndAt', eventEndAt))
        .toString();
  }
}

class InvitationBuilder implements Builder<Invitation, InvitationBuilder> {
  _$Invitation? _$v;

  String? _eventId;
  String? get eventId => _$this._eventId;
  set eventId(String? eventId) => _$this._eventId = eventId;

  String? _inviteeEmail;
  String? get inviteeEmail => _$this._inviteeEmail;
  set inviteeEmail(String? inviteeEmail) => _$this._inviteeEmail = inviteeEmail;

  String? _inviteeUserId;
  String? get inviteeUserId => _$this._inviteeUserId;
  set inviteeUserId(String? inviteeUserId) =>
      _$this._inviteeUserId = inviteeUserId;

  String? _eventOwnerId;
  String? get eventOwnerId => _$this._eventOwnerId;
  set eventOwnerId(String? eventOwnerId) => _$this._eventOwnerId = eventOwnerId;

  InvitationStatusEnum? _status;
  InvitationStatusEnum? get status => _$this._status;
  set status(InvitationStatusEnum? status) => _$this._status = status;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _$this._updatedAt;
  set updatedAt(DateTime? updatedAt) => _$this._updatedAt = updatedAt;

  String? _eventTitle;
  String? get eventTitle => _$this._eventTitle;
  set eventTitle(String? eventTitle) => _$this._eventTitle = eventTitle;

  String? _eventLocation;
  String? get eventLocation => _$this._eventLocation;
  set eventLocation(String? eventLocation) =>
      _$this._eventLocation = eventLocation;

  DateTime? _eventStartAt;
  DateTime? get eventStartAt => _$this._eventStartAt;
  set eventStartAt(DateTime? eventStartAt) =>
      _$this._eventStartAt = eventStartAt;

  DateTime? _eventEndAt;
  DateTime? get eventEndAt => _$this._eventEndAt;
  set eventEndAt(DateTime? eventEndAt) => _$this._eventEndAt = eventEndAt;

  InvitationBuilder() {
    Invitation._defaults(this);
  }

  InvitationBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _eventId = $v.eventId;
      _inviteeEmail = $v.inviteeEmail;
      _inviteeUserId = $v.inviteeUserId;
      _eventOwnerId = $v.eventOwnerId;
      _status = $v.status;
      _createdAt = $v.createdAt;
      _updatedAt = $v.updatedAt;
      _eventTitle = $v.eventTitle;
      _eventLocation = $v.eventLocation;
      _eventStartAt = $v.eventStartAt;
      _eventEndAt = $v.eventEndAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Invitation other) {
    ArgumentError.checkNotNull(other, 'other');
    _$v = other as _$Invitation;
  }

  @override
  void update(void Function(InvitationBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Invitation build() => _build();

  _$Invitation _build() {
    final _$result = _$v ??
        new _$Invitation._(
            eventId: BuiltValueNullFieldError.checkNotNull(
                eventId, r'Invitation', 'eventId'),
            inviteeEmail: BuiltValueNullFieldError.checkNotNull(
                inviteeEmail, r'Invitation', 'inviteeEmail'),
            inviteeUserId: inviteeUserId,
            eventOwnerId: eventOwnerId,
            status: BuiltValueNullFieldError.checkNotNull(
                status, r'Invitation', 'status'),
            createdAt: BuiltValueNullFieldError.checkNotNull(
                createdAt, r'Invitation', 'createdAt'),
            updatedAt: BuiltValueNullFieldError.checkNotNull(
                updatedAt, r'Invitation', 'updatedAt'),
            eventTitle: BuiltValueNullFieldError.checkNotNull(
                eventTitle, r'Invitation', 'eventTitle'),
            eventLocation: eventLocation,
            eventStartAt: BuiltValueNullFieldError.checkNotNull(
                eventStartAt, r'Invitation', 'eventStartAt'),
            eventEndAt: BuiltValueNullFieldError.checkNotNull(
                eventEndAt, r'Invitation', 'eventEndAt'));
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
