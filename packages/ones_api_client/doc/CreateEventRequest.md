# ones_api_client.model.CreateEventRequest

## Load the model package
```dart
import 'package:ones_api_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**title** | **String** |  | 
**objective** | **String** |  | 
**location** | **String** |  | 
**startAt** | [**DateTime**](DateTime.md) |  | 
**endAt** | [**DateTime**](DateTime.md) |  | 
**coverReservationId** | **String** | Reservation id obtained after accepting an AI-generated cover (optional) | [optional] 
**inviteeEmails** | **BuiltList&lt;String&gt;** | Invitee emails (lowercased). For each email, an invitation is created with status 'invited'. | [optional] 
**allowGuestInvites** | **bool** | Whether accepted guests (non-owner) are allowed to invite other guests. | [optional] [default to true]

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


