//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class ReportControllerApi {
  ReportControllerApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// 신고 추가
  ///
  /// 신고 내용을 추가합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [ReportCreateRequestDto] reportCreateRequestDto (required):
  Future<Response> createWithHttpInfo(ReportCreateRequestDto reportCreateRequestDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/report/create';

    // ignore: prefer_final_locals
    Object? postBody = reportCreateRequestDto;

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

  /// 신고 추가
  ///
  /// 신고 내용을 추가합니다.
  ///
  /// Parameters:
  ///
  /// * [ReportCreateRequestDto] reportCreateRequestDto (required):
  Future<ApiResponseDtoBoolean?> create(ReportCreateRequestDto reportCreateRequestDto,) async {
    final response = await createWithHttpInfo(reportCreateRequestDto,);
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

  /// 신고 삭제
  ///
  /// id값으로 신고 삭제합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<Response> delete1WithHttpInfo(int id,) async {
    // ignore: prefer_const_declarations
    final path = r'/report/delete';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

      queryParams.addAll(_queryParams('', 'id', id));

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

  /// 신고 삭제
  ///
  /// id값으로 신고 삭제합니다.
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<ApiResponseDtoBoolean?> delete1(int id,) async {
    final response = await delete1WithHttpInfo(id,);
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

  /// 신고 내용 조회
  ///
  /// 신고 내용을 조회합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [ReportSearchRequestDto] reportSearchRequestDto (required):
  Future<Response> findWithHttpInfo(ReportSearchRequestDto reportSearchRequestDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/report/find';

    // ignore: prefer_final_locals
    Object? postBody = reportSearchRequestDto;

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

  /// 신고 내용 조회
  ///
  /// 신고 내용을 조회합니다.
  ///
  /// Parameters:
  ///
  /// * [ReportSearchRequestDto] reportSearchRequestDto (required):
  Future<ApiResponseDtoListReportResponseDto?> find(ReportSearchRequestDto reportSearchRequestDto,) async {
    final response = await findWithHttpInfo(reportSearchRequestDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoListReportResponseDto',) as ApiResponseDtoListReportResponseDto;
    
    }
    return null;
  }

  /// 신고 상태 업데이트
  ///
  /// 신고 상태를 업데이트 및 관리자 커멘트를 추가합니다.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [ReportUpdateReqDto] reportUpdateReqDto (required):
  Future<Response> update2WithHttpInfo(ReportUpdateReqDto reportUpdateReqDto,) async {
    // ignore: prefer_const_declarations
    final path = r'/report/update';

    // ignore: prefer_final_locals
    Object? postBody = reportUpdateReqDto;

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

  /// 신고 상태 업데이트
  ///
  /// 신고 상태를 업데이트 및 관리자 커멘트를 추가합니다.
  ///
  /// Parameters:
  ///
  /// * [ReportUpdateReqDto] reportUpdateReqDto (required):
  Future<ApiResponseDtoReportResponseDto?> update2(ReportUpdateReqDto reportUpdateReqDto,) async {
    final response = await update2WithHttpInfo(reportUpdateReqDto,);
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(await _decodeBodyBytes(response), 'ApiResponseDtoReportResponseDto',) as ApiResponseDtoReportResponseDto;
    
    }
    return null;
  }
}
