//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_import

import 'package:one_of_serializer/any_of_serializer.dart';
import 'package:one_of_serializer/one_of_serializer.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/serializer.dart';
import 'package:built_value/standard_json_plugin.dart';
import 'package:built_value/iso_8601_date_time_serializer.dart';
import 'package:ones_api_client/src/date_serializer.dart';
import 'package:ones_api_client/src/model/date.dart';

import 'package:ones_api_client/src/model/accept_event_cover_response.dart';
import 'package:ones_api_client/src/model/create_event_request.dart';
import 'package:ones_api_client/src/model/error_response.dart';
import 'package:ones_api_client/src/model/event.dart';
import 'package:ones_api_client/src/model/event_photo_list_item.dart';
import 'package:ones_api_client/src/model/event_photos_list_page.dart';
import 'package:ones_api_client/src/model/generate_event_cover_request.dart';
import 'package:ones_api_client/src/model/generate_event_cover_response.dart';
import 'package:ones_api_client/src/model/guest.dart';
import 'package:ones_api_client/src/model/guest_v2.dart';
import 'package:ones_api_client/src/model/health_response.dart';
import 'package:ones_api_client/src/model/invitation.dart';
import 'package:ones_api_client/src/model/invite_event_guests_request.dart';
import 'package:ones_api_client/src/model/presigned_url_response.dart';
import 'package:ones_api_client/src/model/translation.dart';
import 'package:ones_api_client/src/model/upsert_translation_request.dart';

part 'serializers.g.dart';

@SerializersFor([
  AcceptEventCoverResponse,
  CreateEventRequest,
  ErrorResponse,
  Event,
  EventPhotoListItem,
  EventPhotosListPage,
  GenerateEventCoverRequest,
  GenerateEventCoverResponse,
  Guest,
  GuestV2,
  HealthResponse,
  Invitation,
  InviteEventGuestsRequest,
  PresignedUrlResponse,
  Translation,
  UpsertTranslationRequest,
])
Serializers serializers = (_$serializers.toBuilder()
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(Event)]),
        () => ListBuilder<Event>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(Translation)]),
        () => ListBuilder<Translation>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(Invitation)]),
        () => ListBuilder<Invitation>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(Guest)]),
        () => ListBuilder<Guest>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(String)]),
        () => ListBuilder<String>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(GuestV2)]),
        () => ListBuilder<GuestV2>(),
      )
      ..add(const OneOfSerializer())
      ..add(const AnyOfSerializer())
      ..add(const DateSerializer())
      ..add(Iso8601DateTimeSerializer()))
    .build();

Serializers standardSerializers =
    (serializers.toBuilder()..addPlugin(StandardJsonPlugin())).build();
