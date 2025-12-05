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
  Future<Response> create2WithHttpInfo(CommentReqDto commentReqDto,) async {
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
  Future<ApiResponseDtoObject?> create2(CommentReqDto commentReqDto,) async {
    final response = await create2WithHttpInfo(commentReqDto,);
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

  /// 댓글 조회
  ///
  /// 게시물에 달린 댓글을 조회합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] postId (required):
  Future<Response> getCommentWithHttpInfo(int postId,) async {
    // ignore: prefer_const_declarations
    final path = r'/comment/get';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'postId', postId));

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

  /// 댓글 조회
  ///
  /// 게시물에 달린 댓글을 조회합니다.
  ///
  /// Parameters:
  ///
  /// * [int] postId (required):
  Future<ApiResponseDtoListCommentRespDto?> getComment(int postId,) async {
    final response = await getCommentWithHttpInfo(postId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoListCommentRespDto',) as ApiResponseDtoListCommentRespDto;
    
    }
    return null;
  }
}
