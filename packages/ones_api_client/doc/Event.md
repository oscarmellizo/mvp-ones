# ones_api_client.model.Event

## Load the model package
```dart
import 'package:ones_api_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**id** | **String** |  | 
**ownerId** | **String** |  | 
**createdAt** | [**DateTime**](DateTime.md) |  | 
**title** | **String** |  | 
**objective** | **String** |  | 
**location** | **String** |  | 
**startAt** | [**DateTime**](DateTime.md) |  | 
**endAt** | [**DateTime**](DateTime.md) |  | 
**coverKey** | **String** | S3 object key for the event cover (optional) | [optional] 
**allowGuestInvites** | **bool** | Whether accepted guests (non-owner) are allowed to invite other guests. | [optional] [default to true]
**inviteLinkEnabled** | **bool** | Whether the public invite link is currently enabled. | [optional] 
**frameIds** | **BuiltList&lt;String&gt;** |  | [optional] 
**eventCode** | **String** | Six-digit numeric code guests can use to join the event. | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


