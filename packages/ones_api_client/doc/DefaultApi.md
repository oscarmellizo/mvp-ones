# ones_api_client.api.DefaultApi

## Load the API package
```dart
import 'package:ones_api_client/api.dart';
```

All URIs are relative to *http://localhost:8080*

Method | HTTP request | Description
------------- | ------------- | -------------
[**acceptEventCover**](DefaultApi.md#accepteventcover) | **POST** /v1/events/covers/{coverId}/accept | Accept a generated cover preview and obtain a reservation id for later event creation
[**cancelEventCover**](DefaultApi.md#canceleventcover) | **POST** /v1/events/covers/{coverId}/cancel | Cancel a generated cover preview (best-effort delete temp object)
[**createEvent**](DefaultApi.md#createevent) | **POST** /v1/events | Create event for authenticated user
[**generateEventCover**](DefaultApi.md#generateeventcover) | **POST** /v1/events/covers/generate | Generate an AI event cover preview and return a pre-signed URL
[**getEvent**](DefaultApi.md#getevent) | **GET** /v1/events/{id} | Get event by id (only if it belongs to authenticated user)
[**getEventCoverUrl**](DefaultApi.md#geteventcoverurl) | **GET** /v1/events/{id}/cover-url | Get a pre-signed URL to view the event cover image (if configured)
[**health**](DefaultApi.md#health) | **GET** /health | Health check
[**listEvents**](DefaultApi.md#listevents) | **GET** /v1/events | List events for authenticated user


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

