# soi_api_client.api.PostAPIApi

## Load the API package
```dart
import 'package:soi_api_client/api.dart';
```

All URIs are relative to *https://newdawnsoi.site*

Method | HTTP request | Description
------------- | ------------- | -------------
[**create**](PostAPIApi.md#create) | **POST** /post/create | 게시물 추가
[**delete1**](PostAPIApi.md#delete1) | **DELETE** /post/delete | 게시물 삭제
[**findAllByUserId**](PostAPIApi.md#findallbyuserid) | **GET** /post/find-all | 전체 게시물 조회
[**findByCategoryId**](PostAPIApi.md#findbycategoryid) | **GET** /post/find-by/category | 카테고리에 해당하는 게시물 조회
[**setPost**](PostAPIApi.md#setpost) | **PATCH** /post/set-status | 게시물 상태변경
[**showDetail**](PostAPIApi.md#showdetail) | **GET** /post/detail | 단일 게시물 조회
[**update2**](PostAPIApi.md#update2) | **PATCH** /post/update | 게시물 수정


# **create**
> ApiResponseDtoBoolean create(postCreateReqDto)

게시물 추가

게시물을 추가합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = PostAPIApi();
final postCreateReqDto = PostCreateReqDto(); // PostCreateReqDto | 

try {
    final result = api_instance.create(postCreateReqDto);
    print(result);
} catch (e) {
    print('Exception when calling PostAPIApi->create: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **postCreateReqDto** | [**PostCreateReqDto**](PostCreateReqDto.md)|  | 

### Return type

[**ApiResponseDtoBoolean**](ApiResponseDtoBoolean.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **delete1**
> ApiResponseDtoObject delete1(postId)

게시물 삭제

id로 게시물을 삭제합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = PostAPIApi();
final postId = 789; // int | 

try {
    final result = api_instance.delete1(postId);
    print(result);
} catch (e) {
    print('Exception when calling PostAPIApi->delete1: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **postId** | **int**|  | 

### Return type

[**ApiResponseDtoObject**](ApiResponseDtoObject.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **findAllByUserId**
> ApiResponseDtoListPostRespDto findAllByUserId(userId, postStatus, page)

전체 게시물 조회

사용자가 포함된 카테고리의 모든 게시물을 상태 (활성화, 삭제됨, 비활성화)에따라 리턴해줌  page에 원하는 페이지 번호를 입력 0부터 시작

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = PostAPIApi();
final userId = 789; // int | 
final postStatus = postStatus_example; // String | 
final page = 56; // int | 

try {
    final result = api_instance.findAllByUserId(userId, postStatus, page);
    print(result);
} catch (e) {
    print('Exception when calling PostAPIApi->findAllByUserId: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **int**|  | 
 **postStatus** | **String**|  | 
 **page** | **int**|  | [optional] [default to 0]

### Return type

[**ApiResponseDtoListPostRespDto**](ApiResponseDtoListPostRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **findByCategoryId**
> ApiResponseDtoListPostRespDto findByCategoryId(categoryId, userId, page)

카테고리에 해당하는 게시물 조회

카테고리 아이디, 유저아이디로 해당 카테고리에 속한 게시물을 조회합니다.  page에 원하는 페이지 번호를 입력 0부터 시작

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = PostAPIApi();
final categoryId = 789; // int | 
final userId = 789; // int | 
final page = 56; // int | 

try {
    final result = api_instance.findByCategoryId(categoryId, userId, page);
    print(result);
} catch (e) {
    print('Exception when calling PostAPIApi->findByCategoryId: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **categoryId** | **int**|  | 
 **userId** | **int**|  | 
 **page** | **int**|  | [optional] [default to 0]

### Return type

[**ApiResponseDtoListPostRespDto**](ApiResponseDtoListPostRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **setPost**
> ApiResponseDtoObject setPost(postId, postStatus)

게시물 상태변경

게시물 상태를 변경합니다. ACTIVE : 활성화 SOFTDELETE : 삭제(휴지통) INACTIVE : 비활성화

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = PostAPIApi();
final postId = 789; // int | 
final postStatus = postStatus_example; // String | 

try {
    final result = api_instance.setPost(postId, postStatus);
    print(result);
} catch (e) {
    print('Exception when calling PostAPIApi->setPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **postId** | **int**|  | 
 **postStatus** | **String**|  | 

### Return type

[**ApiResponseDtoObject**](ApiResponseDtoObject.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **showDetail**
> ApiResponseDtoPostRespDto showDetail(postId)

단일 게시물 조회

게시물 id로 해당 게시물의 상세정보를 조회합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = PostAPIApi();
final postId = 789; // int | 

try {
    final result = api_instance.showDetail(postId);
    print(result);
} catch (e) {
    print('Exception when calling PostAPIApi->showDetail: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **postId** | **int**|  | 

### Return type

[**ApiResponseDtoPostRespDto**](ApiResponseDtoPostRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **update2**
> ApiResponseDtoObject update2(postUpdateReqDto)

게시물 수정

게시물을 수정합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = PostAPIApi();
final postUpdateReqDto = PostUpdateReqDto(); // PostUpdateReqDto | 

try {
    final result = api_instance.update2(postUpdateReqDto);
    print(result);
} catch (e) {
    print('Exception when calling PostAPIApi->update2: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **postUpdateReqDto** | [**PostUpdateReqDto**](PostUpdateReqDto.md)|  | 

### Return type

[**ApiResponseDtoObject**](ApiResponseDtoObject.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

