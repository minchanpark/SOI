//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class NotificationAPIApi {
  NotificationAPIApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// 알림 조회
  ///
  /// 알림들을 조회합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] userId (required):
  ///
  /// * [int] page (required):
  Future<Response> getAllWithHttpInfo(int userId, int page,) async {
    // ignore: prefer_const_declarations
    final path = r'/notification/get-all';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'userId', userId));
      queryParams.addAll(_queryParams('', 'page', page));

    const contentTypes = <String>[];


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

  /// 알림 조회
  ///
  /// 알림들을 조회합니다.
  ///
  /// Parameters:
  ///
  /// * [int] userId (required):
  ///
  /// * [int] page (required):
  Future<ApiResponseDtoNotificationGetAllRespDto?> getAll(int userId, int page,) async {
    final response = await getAllWithHttpInfo(userId, page,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoNotificationGetAllRespDto',) as ApiResponseDtoNotificationGetAllRespDto;
    
    }
    return null;
  }

  /// 친구관련 알림 조회
  ///
  /// 친구 요청 알림들을 조회합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] userId (required):
  ///
  /// * [int] page (required):
  Future<Response> getFriendWithHttpInfo(int userId, int page,) async {
    // ignore: prefer_const_declarations
    final path = r'/notification/get-friend';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'userId', userId));
      queryParams.addAll(_queryParams('', 'page', page));

    const contentTypes = <String>[];


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

  /// 친구관련 알림 조회
  ///
  /// 친구 요청 알림들을 조회합니다.
  ///
  /// Parameters:
  ///
  /// * [int] userId (required):
  ///
  /// * [int] page (required):
  Future<ApiResponseDtoListNotificationRespDto?> getFriend(int userId, int page,) async {
    final response = await getFriendWithHttpInfo(userId, page,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoListNotificationRespDto',) as ApiResponseDtoListNotificationRespDto;
    
    }
    return null;
  }
}
