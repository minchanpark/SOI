# soi_api_client.api.CommentAPIApi

## Load the API package
```dart
import 'package:soi_api_client/api.dart';
```

All URIs are relative to *https://newdawnsoi.site*

Method | HTTP request | Description
------------- | ------------- | -------------
[**create3**](CommentAPIApi.md#create3) | **POST** /comment/create | 댓글 추가
[**deleteComment**](CommentAPIApi.md#deletecomment) | **DELETE** /comment/delete | 댓글 삭제
[**getComment**](CommentAPIApi.md#getcomment) | **GET** /comment/get | 댓글 조회


# **create3**
> ApiResponseDtoObject create3(commentReqDto)

댓글 추가

댓글을 추가합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = CommentAPIApi();
final commentReqDto = CommentReqDto(); // CommentReqDto | 

try {
    final result = api_instance.create3(commentReqDto);
    print(result);
} catch (e) {
    print('Exception when calling CommentAPIApi->create3: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **commentReqDto** | [**CommentReqDto**](CommentReqDto.md)|  | 

### Return type

[**ApiResponseDtoObject**](ApiResponseDtoObject.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteComment**
> ApiResponseDtoListObject deleteComment(postId)

댓글 삭제

id를 통해서 댓글을 삭제합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = CommentAPIApi();
final postId = 789; // int | 

try {
    final result = api_instance.deleteComment(postId);
    print(result);
} catch (e) {
    print('Exception when calling CommentAPIApi->deleteComment: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **postId** | **int**|  | 

### Return type

[**ApiResponseDtoListObject**](ApiResponseDtoListObject.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getComment**
> ApiResponseDtoListCommentRespDto getComment(postId)

댓글 조회

게시물에 달린 댓글을 조회합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = CommentAPIApi();
final postId = 789; // int | 

try {
    final result = api_instance.getComment(postId);
    print(result);
} catch (e) {
    print('Exception when calling CommentAPIApi->getComment: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **postId** | **int**|  | 

### Return type

[**ApiResponseDtoListCommentRespDto**](ApiResponseDtoListCommentRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

