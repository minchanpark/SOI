//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class APIApi {
  APIApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Presigned URL 요청
  ///
  /// DB에 저장된 S3 key를 입력하면 1시간 유효한 접근 URL을 반환합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [List<String>] key (required):
  Future<Response> getPresignedUrlWithHttpInfo(List<String> key,) async {
    // ignore: prefer_const_declarations
    final path = r'/media/get-url';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('multi', 'key', key));

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

  /// Presigned URL 요청
  ///
  /// DB에 저장된 S3 key를 입력하면 1시간 유효한 접근 URL을 반환합니다.
  ///
  /// Parameters:
  ///
  /// * [List<String>] key (required):
  Future<ApiResponseDtoListString?> getPresignedUrl(List<String> key,) async {
    final response = await getPresignedUrlWithHttpInfo(key,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoListString',) as ApiResponseDtoListString;
    
    }
    return null;
  }

  /// 미디어 업로드
  ///
  /// 단일, 여러개의 파일을 올릴 수 있습니다. 여러개의 파일 업로드시 , 로 구분해서 type을 명시합니다.id값은 고유 id를 받습니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [List<String>] types (required):
  ///
  /// * [List<String>] usageTypes (required):
  ///
  /// * [int] userId (required):
  ///
  /// * [int] refId (required):
  ///
  /// * [int] usageCount (required):
  ///
  /// * [List<MultipartFile>] files (required):
  Future<Response> uploadMediaWithHttpInfo(List<String> types, List<String> usageTypes, int userId, int refId, int usageCount, List<MultipartFile> files,) async {
    // ignore: prefer_const_declarations
    final path = r'/media/upload';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('multi', 'types', types));
      queryParams.addAll(_queryParams('multi', 'usageTypes', usageTypes));
      queryParams.addAll(_queryParams('', 'userId', userId));
      queryParams.addAll(_queryParams('', 'refId', refId));
      queryParams.addAll(_queryParams('', 'usageCount', usageCount));

    const contentTypes = <String>['multipart/form-data'];

    bool hasFields = false;
    final mp = MultipartRequest('POST', Uri.parse(path));
    if (files.isNotEmpty) {
      hasFields = true;
      mp.files.addAll(files);
    }
    if (hasFields) {
      postBody = mp;
    }

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

  /// 미디어 업로드
  ///
  /// 단일, 여러개의 파일을 올릴 수 있습니다. 여러개의 파일 업로드시 , 로 구분해서 type을 명시합니다.id값은 고유 id를 받습니다.
  ///
  /// Parameters:
  ///
  /// * [List<String>] types (required):
  ///
  /// * [List<String>] usageTypes (required):
  ///
  /// * [int] userId (required):
  ///
  /// * [int] refId (required):
  ///
  /// * [int] usageCount (required):
  ///
  /// * [List<MultipartFile>] files (required):
  Future<ApiResponseDtoListString?> uploadMedia(List<String> types, List<String> usageTypes, int userId, int refId, int usageCount, List<MultipartFile> files,) async {
    final response = await uploadMediaWithHttpInfo(types, usageTypes, userId, refId, usageCount, files,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoListString',) as ApiResponseDtoListString;
    
    }
    return null;
  }
}
