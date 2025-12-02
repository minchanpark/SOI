# soi_api_client.api.NotificationAPIApi

## Load the API package
```dart
import 'package:soi_api_client/api.dart';
```

All URIs are relative to *https://newdawnsoi.site*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getAll**](NotificationAPIApi.md#getall) | **POST** /notification/get-all | 알림 조회
[**getFriend**](NotificationAPIApi.md#getfriend) | **POST** /notification/get-friend | 친구관련 알림 조회


# **getAll**
> ApiResponseDtoNotificationGetAllRespDto getAll(userId)

알림 조회

알림들을 조회합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = NotificationAPIApi();
final userId = 789; // int | 

try {
    final result = api_instance.getAll(userId);
    print(result);
} catch (e) {
    print('Exception when calling NotificationAPIApi->getAll: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **int**|  | 

### Return type

[**ApiResponseDtoNotificationGetAllRespDto**](ApiResponseDtoNotificationGetAllRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getFriend**
> ApiResponseDtoListNotificationRespDto getFriend(userId)

친구관련 알림 조회

친구 요청 알림들을 조회합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = NotificationAPIApi();
final userId = 789; // int | 

try {
    final result = api_instance.getFriend(userId);
    print(result);
} catch (e) {
    print('Exception when calling NotificationAPIApi->getFriend: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **int**|  | 

### Return type

[**ApiResponseDtoListNotificationRespDto**](ApiResponseDtoListNotificationRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

