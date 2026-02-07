//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

import 'package:soi_api_client/api.dart';
import 'package:test/test.dart';


/// tests for PostAPIApi
void main() {
  // final instance = PostAPIApi();

  group('tests for PostAPIApi', () {
    // 게시물 추가
    //
    // 게시물을 추가합니다.
    //
    //Future<ApiResponseDtoBoolean> create1(PostCreateReqDto postCreateReqDto) async
    test('test create1', () async {
      // TODO
    });

    // 게시물 삭제
    //
    // id로 게시물을 삭제합니다.
    //
    //Future<ApiResponseDtoObject> delete2(int postId) async
    test('test delete2', () async {
      // TODO
    });

    // 전체 게시물 조회
    //
    // 사용자가 포함된 카테고리의 모든 게시물을 상태 (활성화, 삭제됨, 비활성화)에따라 리턴해줌  page에 원하는 페이지 번호를 입력 0부터 시작
    //
    //Future<ApiResponseDtoListPostRespDto> findAllByUserId(int userId, String postStatus, { int page }) async
    test('test findAllByUserId', () async {
      // TODO
    });

    // 카테고리에 해당하는 게시물 조회
    //
    // 카테고리 아이디, 유저아이디로 해당 카테고리에 속한 게시물을 조회합니다.  page에 원하는 페이지 번호를 입력 0부터 시작
    //
    //Future<ApiResponseDtoListPostRespDto> findByCategoryId(int categoryId, int userId, { int notificationId, int page }) async
    test('test findByCategoryId', () async {
      // TODO
    });

    // 게시물 상태변경
    //
    // 게시물 상태를 변경합니다. ACTIVE : 활성화 SOFTDELETE : 삭제(휴지통) INACTIVE : 비활성화
    //
    //Future<ApiResponseDtoObject> setPost(int postId, String postStatus) async
    test('test setPost', () async {
      // TODO
    });

    // 단일 게시물 조회
    //
    // 게시물 id로 해당 게시물의 상세정보를 조회합니다.
    //
    //Future<ApiResponseDtoPostRespDto> showDetail(int postId) async
    test('test showDetail', () async {
      // TODO
    });

    // 게시물 수정
    //
    // 게시물을 수정합니다.
    //
    //Future<ApiResponseDtoObject> update3(PostUpdateReqDto postUpdateReqDto) async
    test('test update3', () async {
      // TODO
    });

  });
}
