# ones_api_client.api.DefaultApi

## Load the API package
```dart
import 'package:ones_api_client/api.dart';
```

All URIs are relative to *http://localhost:8080*

Method | HTTP request | Description
------------- | ------------- | -------------
[**acceptEventCover**](DefaultApi.md#accepteventcover) | **POST** /v1/events/covers/{coverId}/accept | Accept a generated cover preview and obtain a reservation id for later event creation
[**acceptInvitation**](DefaultApi.md#acceptinvitation) | **POST** /v1/invitations/{eventId}/accept | Accept an invitation for an event
[**cancelEventCover**](DefaultApi.md#canceleventcover) | **POST** /v1/events/covers/{coverId}/cancel | Cancel a generated cover preview (best-effort delete temp object)
[**createEvent**](DefaultApi.md#createevent) | **POST** /v1/events | Create event for authenticated user
[**generateEventCover**](DefaultApi.md#generateeventcover) | **POST** /v1/events/covers/generate | Generate an AI event cover preview and return a pre-signed URL
[**getEvent**](DefaultApi.md#getevent) | **GET** /v1/events/{id} | Get event by id (only if it belongs to authenticated user)
[**getEventCoverUrl**](DefaultApi.md#geteventcoverurl) | **GET** /v1/events/{id}/cover-url | Get a pre-signed URL to view the event cover image (if configured)
[**health**](DefaultApi.md#health) | **GET** /health | Health check
[**inviteEventGuests**](DefaultApi.md#inviteeventguests) | **POST** /v1/events/{id}/invitees | Invite new guests to an existing event (owner only)
[**listEventGuests**](DefaultApi.md#listeventguests) | **GET** /v1/events/{id}/guests | List guests for an event (owner + invitees with invitation status)
[**listEventGuestsV2**](DefaultApi.md#listeventguestsv2) | **GET** /v1/events/{id}/guests/v2 | List guests for an event including userId (when available)
[**listEventPhotos**](DefaultApi.md#listeventphotos) | **GET** /v1/events/{eventId}/photos | List event photos (paginated) with optional server-side filtering
[**listEvents**](DefaultApi.md#listevents) | **GET** /v1/events | List events for authenticated user
[**listInvitations**](DefaultApi.md#listinvitations) | **GET** /v1/invitations | List invitations for authenticated user (by email claim)
[**rejectInvitation**](DefaultApi.md#rejectinvitation) | **POST** /v1/invitations/{eventId}/reject | Reject an invitation for an event
[**resolveInvitation**](DefaultApi.md#resolveinvitation) | **GET** /v1/invitations/resolve | Resolve an invitation token for authenticated user (returns invitation details for modal)


# **acceptEventCover**
> AcceptEventCoverResponse acceptEventCover(coverId)

Accept a generated cover preview and obtain a reservation id for later event creation

### Example
```dart
import 'package:ones_api_client/api.dart';

final api = OnesApiClient().getDefaultApi();
final String coverId = coverId_example; // String | 

try {
    final response = api.acceptEventCover(coverId);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->acceptEventCover: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **coverId** | **String**|  | 

### Return type

[**AcceptEventCoverResponse**](AcceptEventCoverResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **acceptInvitation**
> Invitation acceptInvitation(eventId)

Accept an invitation for an event

### Example
```dart
import 'package:ones_api_client/api.dart';

final api = OnesApiClient().getDefaultApi();
final String eventId = eventId_example; // String | 

try {
    final response = api.acceptInvitation(eventId);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->acceptInvitation: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 

### Return type

[**Invitation**](Invitation.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **cancelEventCover**
> cancelEventCover(coverId)

Cancel a generated cover preview (best-effort delete temp object)

### Example
```dart
import 'package:ones_api_client/api.dart';

final api = OnesApiClient().getDefaultApi();
final String coverId = coverId_example; // String | 

try {
    api.cancelEventCover(coverId);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->cancelEventCover: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **coverId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createEvent**
> Event createEvent(createEventRequest)

Create event for authenticated user

### Example
```dart
import 'package:ones_api_client/api.dart';

final api = OnesApiClient().getDefaultApi();
final CreateEventRequest createEventRequest = ; // CreateEventRequest | 

try {
    final response = api.createEvent(createEventRequest);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->createEvent: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **createEventRequest** | [**CreateEventRequest**](CreateEventRequest.md)|  | 

### Return type

[**Event**](Event.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **generateEventCover**
> GenerateEventCoverResponse generateEventCover(generateEventCoverRequest)

Generate an AI event cover preview and return a pre-signed URL

### Example
```dart
import 'package:ones_api_client/api.dart';

final api = OnesApiClient().getDefaultApi();
final GenerateEventCoverRequest generateEventCoverRequest = ; // GenerateEventCoverRequest | 

try {
    final response = api.generateEventCover(generateEventCoverRequest);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->generateEventCover: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **generateEventCoverRequest** | [**GenerateEventCoverRequest**](GenerateEventCoverRequest.md)|  | 

### Return type

[**GenerateEventCoverResponse**](GenerateEventCoverResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getEvent**
> Event getEvent(id)

Get event by id (only if it belongs to authenticated user)

### Example
```dart
import 'package:ones_api_client/api.dart';

final api = OnesApiClient().getDefaultApi();
final String id = id_example; // String | 

try {
    final response = api.getEvent(id);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->getEvent: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  | 

### Return type

[**Event**](Event.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getEventCoverUrl**
> PresignedUrlResponse getEventCoverUrl(id)

Get a pre-signed URL to view the event cover image (if configured)

### Example
```dart
import 'package:ones_api_client/api.dart';

final api = OnesApiClient().getDefaultApi();
final String id = id_example; // String | 

try {
    final response = api.getEventCoverUrl(id);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->getEventCoverUrl: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  | 

### Return type

[**PresignedUrlResponse**](PresignedUrlResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **health**
> HealthResponse health()

Health check

### Example
```dart
import 'package:ones_api_client/api.dart';

final api = OnesApiClient().getDefaultApi();

try {
    final response = api.health();
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->health: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**HealthResponse**](HealthResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **inviteEventGuests**
> BuiltList<Guest> inviteEventGuests(id, inviteEventGuestsRequest)

Invite new guests to an existing event (owner only)

### Example
```dart
import 'package:ones_api_client/api.dart';

final api = OnesApiClient().getDefaultApi();
final String id = id_example; // String | 
final InviteEventGuestsRequest inviteEventGuestsRequest = ; // InviteEventGuestsRequest | 

try {
    final response = api.inviteEventGuests(id, inviteEventGuestsRequest);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->inviteEventGuests: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  | 
 **inviteEventGuestsRequest** | [**InviteEventGuestsRequest**](InviteEventGuestsRequest.md)|  | 

### Return type

[**BuiltList&lt;Guest&gt;**](Guest.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listEventGuests**
> BuiltList<Guest> listEventGuests(id)

List guests for an event (owner + invitees with invitation status)

### Example
```dart
import 'package:ones_api_client/api.dart';

final api = OnesApiClient().getDefaultApi();
final String id = id_example; // String | 

try {
    final response = api.listEventGuests(id);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->listEventGuests: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  | 

### Return type

[**BuiltList&lt;Guest&gt;**](Guest.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listEventGuestsV2**
> BuiltList<GuestV2> listEventGuestsV2(id)

List guests for an event including userId (when available)

### Example
```dart
import 'package:ones_api_client/api.dart';

final api = OnesApiClient().getDefaultApi();
final String id = id_example; // String | 

try {
    final response = api.listEventGuestsV2(id);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->listEventGuestsV2: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **String**|  | 

### Return type

[**BuiltList&lt;GuestV2&gt;**](GuestV2.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listEventPhotos**
> EventPhotosListPage listEventPhotos(eventId, limit, nextToken, scope, filter, guestIds)

List event photos (paginated) with optional server-side filtering

### Example
```dart
import 'package:ones_api_client/api.dart';

final api = OnesApiClient().getDefaultApi();
final String eventId = eventId_example; // String | 
final int limit = 56; // int | 
final String nextToken = nextToken_example; // String | Pagination cursor returned by a previous call (opaque)
final String scope = scope_example; // String | Legacy scope parameter (kept for backward compatibility)
final String filter = filter_example; // String | Filter photos. all=all photos in the event, mine=photos owned by the requester, shared_by_me=photos shared by the requester
final BuiltList<String> guestIds = ; // BuiltList<String> | Optional guest userIds to filter by (must be participants of the event). Can be provided as repeated query params (guestIds=a&guestIds=b)

try {
    final response = api.listEventPhotos(eventId, limit, nextToken, scope, filter, guestIds);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->listEventPhotos: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 
 **limit** | **int**|  | [optional] [default to 10]
 **nextToken** | **String**| Pagination cursor returned by a previous call (opaque) | [optional] 
 **scope** | **String**| Legacy scope parameter (kept for backward compatibility) | [optional] 
 **filter** | **String**| Filter photos. all=all photos in the event, mine=photos owned by the requester, shared_by_me=photos shared by the requester | [optional] 
 **guestIds** | [**BuiltList&lt;String&gt;**](String.md)| Optional guest userIds to filter by (must be participants of the event). Can be provided as repeated query params (guestIds=a&guestIds=b) | [optional] 

### Return type

[**EventPhotosListPage**](EventPhotosListPage.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listEvents**
> BuiltList<Event> listEvents()

List events for authenticated user

### Example
```dart
import 'package:ones_api_client/api.dart';

final api = OnesApiClient().getDefaultApi();

try {
    final response = api.listEvents();
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->listEvents: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**BuiltList&lt;Event&gt;**](Event.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listInvitations**
> BuiltList<Invitation> listInvitations()

List invitations for authenticated user (by email claim)

### Example
```dart
import 'package:ones_api_client/api.dart';

final api = OnesApiClient().getDefaultApi();

try {
    final response = api.listInvitations();
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->listInvitations: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**BuiltList&lt;Invitation&gt;**](Invitation.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **rejectInvitation**
> Invitation rejectInvitation(eventId)

Reject an invitation for an event

### Example
```dart
import 'package:ones_api_client/api.dart';

final api = OnesApiClient().getDefaultApi();
final String eventId = eventId_example; // String | 

try {
    final response = api.rejectInvitation(eventId);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->rejectInvitation: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 

### Return type

[**Invitation**](Invitation.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **resolveInvitation**
> Invitation resolveInvitation(token)

Resolve an invitation token for authenticated user (returns invitation details for modal)

### Example
```dart
import 'package:ones_api_client/api.dart';

final api = OnesApiClient().getDefaultApi();
final String token = token_example; // String | 

try {
    final response = api.resolveInvitation(token);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DefaultApi->resolveInvitation: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **token** | **String**|  | 

### Return type

[**Invitation**](Invitation.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

