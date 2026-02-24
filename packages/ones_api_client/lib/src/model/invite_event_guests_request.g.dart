// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invite_event_guests_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$InviteEventGuestsRequest extends InviteEventGuestsRequest {
  @override
  final BuiltList<String> inviteeEmails;

  factory _$InviteEventGuestsRequest(
          [void Function(InviteEventGuestsRequestBuilder)? updates]) =>
      (new InviteEventGuestsRequestBuilder()..update(updates))._build();

  _$InviteEventGuestsRequest._({required this.inviteeEmails}) : super._() {
    BuiltValueNullFieldError.checkNotNull(
        inviteeEmails, r'InviteEventGuestsRequest', 'inviteeEmails');
  }

  @override
  InviteEventGuestsRequest rebuild(
          void Function(InviteEventGuestsRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  InviteEventGuestsRequestBuilder toBuilder() =>
      new InviteEventGuestsRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is InviteEventGuestsRequest &&
        inviteeEmails == other.inviteeEmails;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, inviteeEmails.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'InviteEventGuestsRequest')
          ..add('inviteeEmails', inviteeEmails))
        .toString();
  }
}

class InviteEventGuestsRequestBuilder
    implements
        Builder<InviteEventGuestsRequest, InviteEventGuestsRequestBuilder> {
  _$InviteEventGuestsRequest? _$v;

  ListBuilder<String>? _inviteeEmails;
  ListBuilder<String> get inviteeEmails =>
      _$this._inviteeEmails ??= new ListBuilder<String>();
  set inviteeEmails(ListBuilder<String>? inviteeEmails) =>
      _$this._inviteeEmails = inviteeEmails;

  InviteEventGuestsRequestBuilder() {
    InviteEventGuestsRequest._defaults(this);
  }

  InviteEventGuestsRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _inviteeEmails = $v.inviteeEmails.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(InviteEventGuestsRequest other) {
    ArgumentError.checkNotNull(other, 'other');
    _$v = other as _$InviteEventGuestsRequest;
  }

  @override
  void update(void Function(InviteEventGuestsRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  InviteEventGuestsRequest build() => _build();

  _$InviteEventGuestsRequest _build() {
    _$InviteEventGuestsRequest _$result;
    try {
      _$result = _$v ??
          new _$InviteEventGuestsRequest._(
              inviteeEmails: inviteeEmails.build());
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'inviteeEmails';
        inviteeEmails.build();
      } catch (e) {
        throw new BuiltValueNestedFieldError(
            r'InviteEventGuestsRequest', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
