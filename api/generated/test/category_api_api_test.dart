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


/// tests for CategoryAPIApi
void main() {
  // final instance = CategoryAPIApi();

  group('tests for CategoryAPIApi', () {
    // 카테고리 알림설정
    //
    // 유저아이디와 카테고리 아이디로 알림을 설정합니다.
    //
    //Future<ApiResponseDtoBoolean> categoryAlert(int categoryId, int userId) async
    test('test categoryAlert', () async {
      // TODO
    });

    // 카테고리 고정
    //
    // 카테고리 아이디, 유저 아이디로 카테고리를 고정 혹은 고정해제 시킵니다.
    //
    //Future<ApiResponseDtoBoolean> categoryPinned(int categoryId, int userId) async
    test('test categoryPinned', () async {
      // TODO
    });

    // 카테고리 추가
    //
    // 카테고리를 추가합니다.
    //
    //Future<ApiResponseDtoLong> create4(CategoryCreateReqDto categoryCreateReqDto) async
    test('test create4', () async {
      // TODO
    });

    // 카테고리 이름수정
    //
    // 카테고리 아이디, 유저 아이디, 수정할 이름을 받아 카테고리 이름을 수정합니다. 커스텀한 이름을 삭제하길 원하면 name에 그냥 빈값 \"\" 을 넣으면 커스텀 이름이 삭제됩니다.
    //
    //Future<ApiResponseDtoBoolean> customName(int categoryId, int userId, { String name }) async
    test('test customName', () async {
      // TODO
    });

    // 카테고리 프로필 수정
    //
    // 카테고리 아이디, 유저 아이디, 수정할 프로필 사진을 받아 프로필을 수정합니다. 기본 프로필로 변경하고싶으면 profileImageKey에 \"\" 을 넣으면 됩니다.
    //
    //Future<ApiResponseDtoBoolean> customProfile(int categoryId, int userId, { String profileImageKey }) async
    test('test customProfile', () async {
      // TODO
    });

    // 카테고리 나가기 (삭제)
    //
    // 카테고리를 나갑니다. (만약 카테고리에 속한 유저가 본인밖에 없으면 관련 데이터 다 삭제)
    //
    //Future<ApiResponseDtoObject> delete(int userId, int categoryId) async
    test('test delete', () async {
      // TODO
    });

    // 유저가 속한 카테고리 리스트를 가져오는 API
    //
    // CategoryFilter : ALL, PUBLIC, PRIVATE -> 옵션에 따라서 전체, 그룹, 개인으로 가져올 수 있음
    //
    //Future<ApiResponseDtoListCategoryRespDto> getCategories(String categoryFilter, int userId, { int page }) async
    test('test getCategories', () async {
      // TODO
    });

    // 카테고리에 초대된 유저가 초대 승낙여부를 결정하는 API
    //
    // status에 넣을 수 있는 상태 : PENDING, ACCEPTED, DECLINED, EXPIRED
    //
    //Future<ApiResponseDtoBoolean> inviteResponse(CategoryInviteResponseReqDto categoryInviteResponseReqDto) async
    test('test inviteResponse', () async {
      // TODO
    });

    //  카테고리에 유저 추가(초대)
    //
    // 이미 생성된 카테고리에 유저를 추가(초대)할 때 사용합니다.
    //
    //Future<ApiResponseDtoBoolean> inviteUser(CategoryInviteReqDto categoryInviteReqDto) async
    test('test inviteUser', () async {
      // TODO
    });

  });
}
