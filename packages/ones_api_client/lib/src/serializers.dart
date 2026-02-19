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
import 'package:ones_api_client/src/model/generate_event_cover_request.dart';
import 'package:ones_api_client/src/model/generate_event_cover_response.dart';
import 'package:ones_api_client/src/model/health_response.dart';
import 'package:ones_api_client/src/model/presigned_url_response.dart';

part 'serializers.g.dart';

@SerializersFor([
  AcceptEventCoverResponse,
  CreateEventRequest,
  ErrorResponse,
  Event,
  GenerateEventCoverRequest,
  GenerateEventCoverResponse,
  HealthResponse,
  PresignedUrlResponse,
])
Serializers serializers = (_$serializers.toBuilder()
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(Event)]),
        () => ListBuilder<Event>(),
      )
      ..add(const OneOfSerializer())
      ..add(const AnyOfSerializer())
      ..add(const DateSerializer())
      ..add(Iso8601DateTimeSerializer()))
    .build();

Serializers standardSerializers =
    (serializers.toBuilder()..addPlugin(StandardJsonPlugin())).build();
