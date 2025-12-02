//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class PostAPIApi {
  PostAPIApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// 게시물 추가
  ///
  /// 게시물을 추가합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [PostCreateReqDto] postCreateReqDto (required):
  Future<Response> createWithHttpInfo(PostCreateReqDto postCreateReqDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/post/create';

    // ignore: prefer_final_locals
    Object? postBody = postCreateReqDto;

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

  /// 게시물 추가
  ///
  /// 게시물을 추가합니다.
  ///
  /// Parameters:
  ///
  /// * [PostCreateReqDto] postCreateReqDto (required):
  Future<ApiResponseDtoBoolean?> create(PostCreateReqDto postCreateReqDto,) async {
    final response = await createWithHttpInfo(postCreateReqDto,);
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

  /// 게시물 삭제
  ///
  /// 게시물을 삭제합니다. 삭제된건 일단 휴지통으로 이동됨
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] postId (required):
  Future<Response> delete1WithHttpInfo(int postId,) async {
    // ignore: prefer_const_declarations
    final path = r'/post/delete';

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

  /// 게시물 삭제
  ///
  /// 게시물을 삭제합니다. 삭제된건 일단 휴지통으로 이동됨
  ///
  /// Parameters:
  ///
  /// * [int] postId (required):
  Future<ApiResponseDtoObject?> delete1(int postId,) async {
    final response = await delete1WithHttpInfo(postId,);
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

  /// 메인페이지에 띄울 게시물 조회
  ///
  /// 사용자가 포함된 카테고리의 모든 게시물을 리턴해줌
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] userId (required):
  Future<Response> findAllByUserIdWithHttpInfo(int userId,) async {
    // ignore: prefer_const_declarations
    final path = r'/post/find-all';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'userId', userId));

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

  /// 메인페이지에 띄울 게시물 조회
  ///
  /// 사용자가 포함된 카테고리의 모든 게시물을 리턴해줌
  ///
  /// Parameters:
  ///
  /// * [int] userId (required):
  Future<ApiResponseDtoListPostRespDto?> findAllByUserId(int userId,) async {
    final response = await findAllByUserIdWithHttpInfo(userId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoListPostRespDto',) as ApiResponseDtoListPostRespDto;
    
    }
    return null;
  }

  /// 카테고리에 해당하는 게시물 조회
  ///
  /// 카테고리 아이디, 유저아이디로 해당 카테고리에 속한 게시물을 조회합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] categoryId (required):
  ///
  /// * [int] userId (required):
  Future<Response> findByCategoryIdWithHttpInfo(int categoryId, int userId,) async {
    // ignore: prefer_const_declarations
    final path = r'/post/find-by/category';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'categoryId', categoryId));
      queryParams.addAll(_queryParams('', 'userId', userId));

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

  /// 카테고리에 해당하는 게시물 조회
  ///
  /// 카테고리 아이디, 유저아이디로 해당 카테고리에 속한 게시물을 조회합니다.
  ///
  /// Parameters:
  ///
  /// * [int] categoryId (required):
  ///
  /// * [int] userId (required):
  Future<ApiResponseDtoListPostRespDto?> findByCategoryId(int categoryId, int userId,) async {
    final response = await findByCategoryIdWithHttpInfo(categoryId, userId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoListPostRespDto',) as ApiResponseDtoListPostRespDto;
    
    }
    return null;
  }

  /// 단일 게시물 조회
  ///
  /// 게시물 id로 해당 게시물의 상세정보를 조회합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] postId (required):
  Future<Response> showDetailWithHttpInfo(int postId,) async {
    // ignore: prefer_const_declarations
    final path = r'/post/detail';

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

  /// 단일 게시물 조회
  ///
  /// 게시물 id로 해당 게시물의 상세정보를 조회합니다.
  ///
  /// Parameters:
  ///
  /// * [int] postId (required):
  Future<ApiResponseDtoPostRespDto?> showDetail(int postId,) async {
    final response = await showDetailWithHttpInfo(postId,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoPostRespDto',) as ApiResponseDtoPostRespDto;
    
    }
    return null;
  }

  /// 게시물 수정
  ///
  /// 게시물을 수정합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [PostUpdateReqDto] postUpdateReqDto (required):
  Future<Response> update2WithHttpInfo(PostUpdateReqDto postUpdateReqDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/post/update';

    // ignore: prefer_final_locals
    Object? postBody = postUpdateReqDto;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];


    return apiClient.invokeAPI(
      path,
      'PATCH',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// 게시물 수정
  ///
  /// 게시물을 수정합니다.
  ///
  /// Parameters:
  ///
  /// * [PostUpdateReqDto] postUpdateReqDto (required):
  Future<ApiResponseDtoObject?> update2(PostUpdateReqDto postUpdateReqDto,) async {
    final response = await update2WithHttpInfo(postUpdateReqDto,);
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
}
