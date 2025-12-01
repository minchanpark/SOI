# soi_api_client.api.UserAPIApi

## Load the API package
```dart
import 'package:soi_api_client/api.dart';
```

All URIs are relative to *https://newdawnsoi.site*

Method | HTTP request | Description
------------- | ------------- | -------------
[**authSMS**](UserAPIApi.md#authsms) | **POST** /user/auth | 전화번호 인증
[**checkAuthSMS**](UserAPIApi.md#checkauthsms) | **POST** /user/auth/check | 전화번호 인증확인
[**createUser**](UserAPIApi.md#createuser) | **POST** /user/create | 사용자 생성
[**deleteUser**](UserAPIApi.md#deleteuser) | **DELETE** /user/delete | Id로 사용자 삭제
[**findUser**](UserAPIApi.md#finduser) | **GET** /user/find-by-keyword | 키워드로 사용자 검색
[**getAllUsers**](UserAPIApi.md#getallusers) | **GET** /user/get-all | 모든유저 조회
[**getUser**](UserAPIApi.md#getuser) | **GET** /user/get | 특정유저 조회
[**idCheck**](UserAPIApi.md#idcheck) | **GET** /user/id-check | 사용자 id 중복 체크
[**login**](UserAPIApi.md#login) | **POST** /user/login | 사용자 로그인(전화번호로)
[**update1**](UserAPIApi.md#update1) | **PATCH** /user/update | 유저정보 업데이트
[**updateProfile**](UserAPIApi.md#updateprofile) | **PATCH** /user/update-profile | 유저 프로필 업데이트


# **authSMS**
> bool authSMS(phoneNum)

전화번호 인증

사용자가 입력한 전화번호로 인증을 발송합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = UserAPIApi();
final phoneNum = phoneNum_example; // String | 

try {
    final result = api_instance.authSMS(phoneNum);
    print(result);
} catch (e) {
    print('Exception when calling UserAPIApi->authSMS: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **phoneNum** | **String**|  | 

### Return type

**bool**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **checkAuthSMS**
> bool checkAuthSMS(authCheckReqDto)

전화번호 인증확인

사용자 전화번호와 사용자가 입력한 인증코드를 보내서 인증확인을 진행합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = UserAPIApi();
final authCheckReqDto = AuthCheckReqDto(); // AuthCheckReqDto | 

try {
    final result = api_instance.checkAuthSMS(authCheckReqDto);
    print(result);
} catch (e) {
    print('Exception when calling UserAPIApi->checkAuthSMS: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **authCheckReqDto** | [**AuthCheckReqDto**](AuthCheckReqDto.md)|  | 

### Return type

**bool**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createUser**
> ApiResponseDtoUserRespDto createUser(userCreateReqDto)

사용자 생성

새로운 사용자를 등록합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = UserAPIApi();
final userCreateReqDto = UserCreateReqDto(); // UserCreateReqDto | 

try {
    final result = api_instance.createUser(userCreateReqDto);
    print(result);
} catch (e) {
    print('Exception when calling UserAPIApi->createUser: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userCreateReqDto** | [**UserCreateReqDto**](UserCreateReqDto.md)|  | 

### Return type

[**ApiResponseDtoUserRespDto**](ApiResponseDtoUserRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteUser**
> ApiResponseDtoUserRespDto deleteUser(id)

Id로 사용자 삭제

Id 로 사용자를 삭제합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = UserAPIApi();
final id = 789; // int | 

try {
    final result = api_instance.deleteUser(id);
    print(result);
} catch (e) {
    print('Exception when calling UserAPIApi->deleteUser: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **int**|  | 

### Return type

[**ApiResponseDtoUserRespDto**](ApiResponseDtoUserRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **findUser**
> ApiResponseDtoListUserRespDto findUser(userId)

키워드로 사용자 검색

키워드가 포함된 userId를 갖고있는 사용자를 전부 검색합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = UserAPIApi();
final userId = userId_example; // String | 

try {
    final result = api_instance.findUser(userId);
    print(result);
} catch (e) {
    print('Exception when calling UserAPIApi->findUser: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **String**|  | 

### Return type

[**ApiResponseDtoListUserRespDto**](ApiResponseDtoListUserRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getAllUsers**
> ApiResponseDtoListUserFindRespDto getAllUsers()

모든유저 조회

모든유저를 조회합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = UserAPIApi();

try {
    final result = api_instance.getAllUsers();
    print(result);
} catch (e) {
    print('Exception when calling UserAPIApi->getAllUsers: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**ApiResponseDtoListUserFindRespDto**](ApiResponseDtoListUserFindRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getUser**
> ApiResponseDtoUserRespDto getUser(id)

특정유저 조회

유저의 id값(Long)으로 유저를 조회합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = UserAPIApi();
final id = 789; // int | 

try {
    final result = api_instance.getUser(id);
    print(result);
} catch (e) {
    print('Exception when calling UserAPIApi->getUser: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **int**|  | 

### Return type

[**ApiResponseDtoUserRespDto**](ApiResponseDtoUserRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **idCheck**
> ApiResponseDtoBoolean idCheck(userId)

사용자 id 중복 체크

사용자 id 중복 체크합니다. 사용가능 : true, 사용불가(중복) : false

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = UserAPIApi();
final userId = userId_example; // String | 

try {
    final result = api_instance.idCheck(userId);
    print(result);
} catch (e) {
    print('Exception when calling UserAPIApi->idCheck: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **String**|  | 

### Return type

[**ApiResponseDtoBoolean**](ApiResponseDtoBoolean.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **login**
> ApiResponseDtoUserRespDto login(phoneNum)

사용자 로그인(전화번호로)

인증이 완료된 전화번호로 로그인을 합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = UserAPIApi();
final phoneNum = phoneNum_example; // String | 

try {
    final result = api_instance.login(phoneNum);
    print(result);
} catch (e) {
    print('Exception when calling UserAPIApi->login: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **phoneNum** | **String**|  | 

### Return type

[**ApiResponseDtoUserRespDto**](ApiResponseDtoUserRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **update1**
> ApiResponseDtoUserRespDto update1(userUpdateReqDto)

유저정보 업데이트

새로운 데이터로 유저정보를 업데이트합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = UserAPIApi();
final userUpdateReqDto = UserUpdateReqDto(); // UserUpdateReqDto | 

try {
    final result = api_instance.update1(userUpdateReqDto);
    print(result);
} catch (e) {
    print('Exception when calling UserAPIApi->update1: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userUpdateReqDto** | [**UserUpdateReqDto**](UserUpdateReqDto.md)|  | 

### Return type

[**ApiResponseDtoUserRespDto**](ApiResponseDtoUserRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateProfile**
> ApiResponseDtoUserRespDto updateProfile(userId, profileImage)

유저 프로필 업데이트

유저의 프로필을 업데이트 합니다.

### Example
```dart
import 'package:soi_api_client/api.dart';

final api_instance = UserAPIApi();
final userId = 789; // int | 
final profileImage = profileImage_example; // String | 

try {
    final result = api_instance.updateProfile(userId, profileImage);
    print(result);
} catch (e) {
    print('Exception when calling UserAPIApi->updateProfile: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **int**|  | 
 **profileImage** | **String**|  | 

### Return type

[**ApiResponseDtoUserRespDto**](ApiResponseDtoUserRespDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: */*

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

