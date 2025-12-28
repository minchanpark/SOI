//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class FriendAPIApi {
  FriendAPIApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// 친구 차단
  ///
  /// 차단 요청을 한 사용자의 id : requesterId에 차단을 당하는 사용자의 id : receiverId에 담아서 요청
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [FriendReqDto] friendReqDto (required):
  Future<Response> blockFriendWithHttpInfo(FriendReqDto friendReqDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/friend/block';

    // ignore: prefer_final_locals
    Object? postBody = friendReqDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// 친구 차단
  ///
  /// 차단 요청을 한 사용자의 id : requesterId에 차단을 당하는 사용자의 id : receiverId에 담아서 요청
  ///
  /// Parameters:
  ///
  /// * [FriendReqDto] friendReqDto (required):
  Future<ApiResponseDtoBoolean?> blockFriend(FriendReqDto friendReqDto,) async {
    final response = await blockFriendWithHttpInfo(friendReqDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoBoolean',) as ApiResponseDtoBoolean;
    
    }
    return null;
  }

  /// 친구 추가
  ///
  /// 사용자 전화번호를 통해 친구추가를 합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [FriendCreateReqDto] friendCreateReqDto (required):
  Future<Response> create1WithHttpInfo(FriendCreateReqDto friendCreateReqDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/friend/create';

    // ignore: prefer_final_locals
    Object? postBody = friendCreateReqDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// 친구 추가
  ///
  /// 사용자 전화번호를 통해 친구추가를 합니다.
  ///
  /// Parameters:
  ///
  /// * [FriendCreateReqDto] friendCreateReqDto (required):
  Future<ApiResponseDtoFriendRespDto?> create1(FriendCreateReqDto friendCreateReqDto,) async {
    final response = await create1WithHttpInfo(friendCreateReqDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoFriendRespDto',) as ApiResponseDtoFriendRespDto;
    
    }
    return null;
  }

  /// nickname으로 친구 추가
  ///
  /// 사용자 nickName을 통해 친구추가를 합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [FriendCreateByNickNameReqDto] friendCreateByNickNameReqDto (required):
  Future<Response> createByNickNameWithHttpInfo(FriendCreateByNickNameReqDto friendCreateByNickNameReqDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/friend/create/by-nickname';

    // ignore: prefer_final_locals
    Object? postBody = friendCreateByNickNameReqDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// nickname으로 친구 추가
  ///
  /// 사용자 nickName을 통해 친구추가를 합니다.
  ///
  /// Parameters:
  ///
  /// * [FriendCreateByNickNameReqDto] friendCreateByNickNameReqDto (required):
  Future<ApiResponseDtoFriendRespDto?> createByNickName(FriendCreateByNickNameReqDto friendCreateByNickNameReqDto,) async {
    final response = await createByNickNameWithHttpInfo(friendCreateByNickNameReqDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoFriendRespDto',) as ApiResponseDtoFriendRespDto;
    
    }
    return null;
  }

  /// 친구 삭제
  ///
  /// 삭제 요청을 한 사용자의 id : requesterId에 삭제를 당하는 사용자의 id : receiverId에 담아서 요청 만약 삭제후, 서로가 삭제된 관계면 친구 관계 컬럼을 삭제함
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [FriendReqDto] friendReqDto (required):
  Future<Response> deleteFriendWithHttpInfo(FriendReqDto friendReqDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/friend/delete';

    // ignore: prefer_final_locals
    Object? postBody = friendReqDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// 친구 삭제
  ///
  /// 삭제 요청을 한 사용자의 id : requesterId에 삭제를 당하는 사용자의 id : receiverId에 담아서 요청 만약 삭제후, 서로가 삭제된 관계면 친구 관계 컬럼을 삭제함
  ///
  /// Parameters:
  ///
  /// * [FriendReqDto] friendReqDto (required):
  Future<ApiResponseDtoBoolean?> deleteFriend(FriendReqDto friendReqDto,) async {
    final response = await deleteFriendWithHttpInfo(friendReqDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoBoolean',) as ApiResponseDtoBoolean;
    
    }
    return null;
  }

  /// 모든 친구 조회
  ///
  /// 유저의 id (user_id 말고 그냥 id)를 통해 모든 친구를 조회합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  ///
  /// * [String] friendStatus (required):
  Future<Response> getAllFriendWithHttpInfo(int id, String friendStatus,) async {
    // ignore: prefer_const_declarations
    final path = r'/friend/get-all';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'id', id));
      queryParams.addAll(_queryParams('', 'friendStatus', friendStatus));

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// 모든 친구 조회
  ///
  /// 유저의 id (user_id 말고 그냥 id)를 통해 모든 친구를 조회합니다.
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  ///
  /// * [String] friendStatus (required):
  Future<ApiResponseDtoListUserFindRespDto?> getAllFriend(int id, String friendStatus,) async {
    final response = await getAllFriendWithHttpInfo(id, friendStatus,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoListUserFindRespDto',) as ApiResponseDtoListUserFindRespDto;
    
    }
    return null;
  }

  /// 연락처에 있는 친구들 관계확인
  ///
  /// 유저의 id와 연락처에 있는 친구들 전화번호를 List로 받아서 관계를 리턴합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  ///
  /// * [List<String>] friendPhoneNums (required):
  Future<Response> getAllFriend1WithHttpInfo(int id, List<String> friendPhoneNums,) async {
    // ignore: prefer_const_declarations
    final path = r'/friend/check-friend-relation';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'id', id));
      queryParams.addAll(_queryParams('multi', 'friendPhoneNums', friendPhoneNums));

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// 연락처에 있는 친구들 관계확인
  ///
  /// 유저의 id와 연락처에 있는 친구들 전화번호를 List로 받아서 관계를 리턴합니다.
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  ///
  /// * [List<String>] friendPhoneNums (required):
  Future<ApiResponseDtoListFriendCheckRespDto?> getAllFriend1(int id, List<String> friendPhoneNums,) async {
    final response = await getAllFriend1WithHttpInfo(id, friendPhoneNums,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoListFriendCheckRespDto',) as ApiResponseDtoListFriendCheckRespDto;
    
    }
    return null;
  }

  /// 친구 차단 해제
  ///
  /// 차단 해제 요청을 한 사용자의 id : requesterId에 차단 해제를 당하는 사용자의 id : receiverId에 담아서 요청차단 해제후에는 친구 관계가 완전 초기화 (삭제) 됩니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [FriendReqDto] friendReqDto (required):
  Future<Response> unBlockFriendWithHttpInfo(FriendReqDto friendReqDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/friend/unblock';

    // ignore: prefer_final_locals
    Object? postBody = friendReqDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// 친구 차단 해제
  ///
  /// 차단 해제 요청을 한 사용자의 id : requesterId에 차단 해제를 당하는 사용자의 id : receiverId에 담아서 요청차단 해제후에는 친구 관계가 완전 초기화 (삭제) 됩니다.
  ///
  /// Parameters:
  ///
  /// * [FriendReqDto] friendReqDto (required):
  Future<ApiResponseDtoBoolean?> unBlockFriend(FriendReqDto friendReqDto,) async {
    final response = await unBlockFriendWithHttpInfo(friendReqDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoBoolean',) as ApiResponseDtoBoolean;
    
    }
    return null;
  }

  /// 친구 상태 업데이트
  ///
  /// 친구 관계 id, 상태 : ACCEPTED, CANCELLED 를 받아 상태를 업데이트합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [FriendUpdateRespDto] friendUpdateRespDto (required):
  Future<Response> updateWithHttpInfo(FriendUpdateRespDto friendUpdateRespDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/friend/update';

    // ignore: prefer_final_locals
    Object? postBody = friendUpdateRespDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// 친구 상태 업데이트
  ///
  /// 친구 관계 id, 상태 : ACCEPTED, CANCELLED 를 받아 상태를 업데이트합니다.
  ///
  /// Parameters:
  ///
  /// * [FriendUpdateRespDto] friendUpdateRespDto (required):
  Future<ApiResponseDtoFriendRespDto?> update(FriendUpdateRespDto friendUpdateRespDto,) async {
    final response = await updateWithHttpInfo(friendUpdateRespDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoFriendRespDto',) as ApiResponseDtoFriendRespDto;
    
    }
    return null;
  }
}
