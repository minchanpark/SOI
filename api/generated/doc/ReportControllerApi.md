# soi_api_client.api.ReportControllerApi

## Load the API package
```dart
import 'package:soi_api_client/api.dart';
```

All URIs are relative to *https://newdawnsoi.site*

Method | HTTP request | Description
------------- | ------------- | -------------
[**create**](ReportControllerApi.md#create) | **POST** /report/create | 신고 추가
[**delete1**](ReportControllerApi.md#delete1) | **DELETE** /report/delete | 신고 삭제
[**find**](ReportControllerApi.md#find) | **POST** /report/find | 신고 내용 조회
[**update2**](ReportControllerApi.md#update2) | **PATCH** /report/update | 신고 상태 업데이트


# **create**
> ApiResponseDtoBoolean create(reportCreateRequestDto)

신고 추가

신고 내용을 추가합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = ReportControllerApi();
final reportCreateRequestDto = ReportCreateRequestDto(); // ReportCreateRequestDto | 

try {
    final result = api_instance.create(reportCreateRequestDto);
    print(result);
} catch (e) {
    print('Exception when calling ReportControllerApi->create: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **reportCreateRequestDto** | [**ReportCreateRequestDto**](ReportCreateRequestDto.md)|  | 

### Return type

[**ApiResponseDtoBoolean**](ApiResponseDtoBoolean.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **delete1**
> ApiResponseDtoBoolean delete1(id)

신고 삭제

id값으로 신고 삭제합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = ReportControllerApi();
final id = 789; // int | 

try {
    final result = api_instance.delete1(id);
    print(result);
} catch (e) {
    print('Exception when calling ReportControllerApi->delete1: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **int**|  | 

### Return type

[**ApiResponseDtoBoolean**](ApiResponseDtoBoolean.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **find**
> ApiResponseDtoListReportResponseDto find(reportSearchRequestDto)

신고 내용 조회

신고 내용을 조회합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = ReportControllerApi();
final reportSearchRequestDto = ReportSearchRequestDto(); // ReportSearchRequestDto | 

try {
    final result = api_instance.find(reportSearchRequestDto);
    print(result);
} catch (e) {
    print('Exception when calling ReportControllerApi->find: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **reportSearchRequestDto** | [**ReportSearchRequestDto**](ReportSearchRequestDto.md)|  | 

### Return type

[**ApiResponseDtoListReportResponseDto**](ApiResponseDtoListReportResponseDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **update2**
> ApiResponseDtoReportResponseDto update2(reportUpdateReqDto)

신고 상태 업데이트

신고 상태를 업데이트 및 관리자 커멘트를 추가합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = ReportControllerApi();
final reportUpdateReqDto = ReportUpdateReqDto(); // ReportUpdateReqDto | 

try {
    final result = api_instance.update2(reportUpdateReqDto);
    print(result);
} catch (e) {
    print('Exception when calling ReportControllerApi->update2: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **reportUpdateReqDto** | [**ReportUpdateReqDto**](ReportUpdateReqDto.md)|  | 

### Return type

[**ApiResponseDtoReportResponseDto**](ApiResponseDtoReportResponseDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

