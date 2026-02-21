//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class CommentAPIApi {
  CommentAPIApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// 댓글 추가
  ///
  /// 댓글을 추가합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [CommentReqDto] commentReqDto (required):
  Future<Response> create3WithHttpInfo(CommentReqDto commentReqDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/comment/create';

    // ignore: prefer_final_locals
    Object? postBody = commentReqDto;

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

  /// 댓글 추가
  ///
  /// 댓글을 추가합니다.
  ///
  /// Parameters:
  ///
  /// * [CommentReqDto] commentReqDto (required):
  Future<ApiResponseDtoObject?> create3(CommentReqDto commentReqDto,) async {
    final response = await create3WithHttpInfo(commentReqDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoObject',) as ApiResponseDtoObject;
    
    }
    return null;
  }

  /// 댓글 삭제
  ///
  /// id를 통해서 댓글을 삭제합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] postId (required):
  Future<Response> deleteCommentWithHttpInfo(int postId,) async {
    // ignore: prefer_const_declarations
    final path = r'/comment/delete';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'postId', postId));

    const contentTypes = <String>[];


    return apiClient.invokeAPI(
      path,
      'DELETE',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// 댓글 삭제
  ///
  /// id를 통해서 댓글을 삭제합니다.
  ///
  /// Parameters:
  ///
  /// * [int] postId (required):
  Future<ApiResponseDtoListObject?> deleteComment(int postId,) async {
    final response = await deleteCommentWithHttpInfo(postId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoListObject',) as ApiResponseDtoListObject;
    
    }
    return null;
  }

  /// 사용자가 작성한 댓글 조회
  ///
  /// 사용자가 작성한 모든 댓글을 조회합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] userId (required):
  ///
  /// * [int] page (required):
  Future<Response> getAllCommentByUserIdWithHttpInfo(int userId, int page,) async {
    // ignore: prefer_const_declarations
    final path = r'/comment/get/by-user-id';

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
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// 사용자가 작성한 댓글 조회
  ///
  /// 사용자가 작성한 모든 댓글을 조회합니다.
  ///
  /// Parameters:
  ///
  /// * [int] userId (required):
  ///
  /// * [int] page (required):
  Future<ApiResponseDtoSliceCommentRespDto?> getAllCommentByUserId(int userId, int page,) async {
    final response = await getAllCommentByUserIdWithHttpInfo(userId, page,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoSliceCommentRespDto',) as ApiResponseDtoSliceCommentRespDto;
    
    }
    return null;
  }

  /// 대댓글 조회
  ///
  /// 댓글에 달린 대댓글을 조회합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] parentCommentId (required):
  ///
  /// * [int] page (required):
  Future<Response> getChildCommentWithHttpInfo(int parentCommentId, int page,) async {
    // ignore: prefer_const_declarations
    final path = r'/comment/get-child';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'parentCommentId', parentCommentId));
      queryParams.addAll(_queryParams('', 'page', page));

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

  /// 대댓글 조회
  ///
  /// 댓글에 달린 대댓글을 조회합니다.
  ///
  /// Parameters:
  ///
  /// * [int] parentCommentId (required):
  ///
  /// * [int] page (required):
  Future<ApiResponseDtoSliceCommentRespDto?> getChildComment(int parentCommentId, int page,) async {
    final response = await getChildCommentWithHttpInfo(parentCommentId, page,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoSliceCommentRespDto',) as ApiResponseDtoSliceCommentRespDto;
    
    }
    return null;
  }

  /// 원댓글 조회
  ///
  /// 게시물에 달린 댓글을 조회합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] postId (required):
  ///
  /// * [int] page (required):
  Future<Response> getParentCommentWithHttpInfo(int postId, int page,) async {
    // ignore: prefer_const_declarations
    final path = r'/comment/get-parent';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'postId', postId));
      queryParams.addAll(_queryParams('', 'page', page));

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

  /// 원댓글 조회
  ///
  /// 게시물에 달린 댓글을 조회합니다.
  ///
  /// Parameters:
  ///
  /// * [int] postId (required):
  ///
  /// * [int] page (required):
  Future<ApiResponseDtoSliceCommentRespDto?> getParentComment(int postId, int page,) async {
    final response = await getParentCommentWithHttpInfo(postId, page,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoSliceCommentRespDto',) as ApiResponseDtoSliceCommentRespDto;
    
    }
    return null;
  }
}
