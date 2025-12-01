# soi_api_client.api.CategoryAPIApi

## Load the API package
```dart
import 'package:soi_api_client/api.dart';
```

All URIs are relative to *https://newdawnsoi.site*

Method | HTTP request | Description
------------- | ------------- | -------------
[**categoryPinned**](CategoryAPIApi.md#categorypinned) | **POST** /category/pinned | 카테고리 고정
[**create3**](CategoryAPIApi.md#create3) | **POST** /category/create | 카테고리 추가
[**getCategories**](CategoryAPIApi.md#getcategories) | **POST** /category/find | 유저가 속한 카테고리 리스트를 가져오는 API
[**inviteResponse**](CategoryAPIApi.md#inviteresponse) | **POST** /category/invite/response | 카테고리에 초대된 유저가 초대 승낙여부를 결정하는 API
[**inviteUser**](CategoryAPIApi.md#inviteuser) | **POST** /category/invite |  카테고리에 유저 추가


# **categoryPinned**
> ApiResponseDtoBoolean categoryPinned(categoryId, userId)

카테고리 고정

카테고리 아이디, 유저 아이디로 카테고리를 고정 혹은 고정해제 시킵니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = CategoryAPIApi();
final categoryId = 789; // int | 
final userId = 789; // int | 

try {
    final result = api_instance.categoryPinned(categoryId, userId);
    print(result);
} catch (e) {
    print('Exception when calling CategoryAPIApi->categoryPinned: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **categoryId** | **int**|  | 
 **userId** | **int**|  | 

### Return type

[**ApiResponseDtoBoolean**](ApiResponseDtoBoolean.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **create3**
> ApiResponseDtoLong create3(categoryCreateReqDto)

카테고리 추가

카테고리를 추가합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = CategoryAPIApi();
final categoryCreateReqDto = CategoryCreateReqDto(); // CategoryCreateReqDto | 

try {
    final result = api_instance.create3(categoryCreateReqDto);
    print(result);
} catch (e) {
    print('Exception when calling CategoryAPIApi->create3: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **categoryCreateReqDto** | [**CategoryCreateReqDto**](CategoryCreateReqDto.md)|  | 

### Return type

[**ApiResponseDtoLong**](ApiResponseDtoLong.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getCategories**
> ApiResponseDtoListCategoryRespDto getCategories(categoryFilter, userId)

유저가 속한 카테고리 리스트를 가져오는 API

CategoryFilter : ALL, PUBLIC, PRIVATE -> 옵션에 따라서 전체, 그룹, 개인으로 가져올 수 있음

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = CategoryAPIApi();
final categoryFilter = categoryFilter_example; // String | 
final userId = 789; // int | 

try {
    final result = api_instance.getCategories(categoryFilter, userId);
    print(result);
} catch (e) {
    print('Exception when calling CategoryAPIApi->getCategories: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **categoryFilter** | **String**|  | 
 **userId** | **int**|  | 

### Return type

[**ApiResponseDtoListCategoryRespDto**](ApiResponseDtoListCategoryRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **inviteResponse**
> ApiResponseDtoBoolean inviteResponse(categoryInviteResponseReqDto)

카테고리에 초대된 유저가 초대 승낙여부를 결정하는 API

status에 넣을 수 있는 상태 : PENDING, ACCEPTED, DECLINED, EXPIRED

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = CategoryAPIApi();
final categoryInviteResponseReqDto = CategoryInviteResponseReqDto(); // CategoryInviteResponseReqDto | 

try {
    final result = api_instance.inviteResponse(categoryInviteResponseReqDto);
    print(result);
} catch (e) {
    print('Exception when calling CategoryAPIApi->inviteResponse: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **categoryInviteResponseReqDto** | [**CategoryInviteResponseReqDto**](CategoryInviteResponseReqDto.md)|  | 

### Return type

[**ApiResponseDtoBoolean**](ApiResponseDtoBoolean.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **inviteUser**
> ApiResponseDtoBoolean inviteUser(categoryInviteReqDto)

 카테고리에 유저 추가

이미 생성된 카테고리에 유저를 초대할 때 사용합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = CategoryAPIApi();
final categoryInviteReqDto = CategoryInviteReqDto(); // CategoryInviteReqDto | 

try {
    final result = api_instance.inviteUser(categoryInviteReqDto);
    print(result);
} catch (e) {
    print('Exception when calling CategoryAPIApi->inviteUser: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **categoryInviteReqDto** | [**CategoryInviteReqDto**](CategoryInviteReqDto.md)|  | 

### Return type

[**ApiResponseDtoBoolean**](ApiResponseDtoBoolean.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

