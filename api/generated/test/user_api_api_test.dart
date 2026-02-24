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


/// tests for UserAPIApi
void main() {
  // final instance = UserAPIApi();

  group('tests for UserAPIApi', () {
    // 전화번호 인증
    //
    // 사용자가 입력한 전화번호로 인증을 발송합니다.
    //
    //Future<bool> authSMS(String phoneNum) async
    test('test authSMS', () async {
      // TODO
    });

    // 전화번호 인증확인
    //
    // 사용자 전화번호와 사용자가 입력한 인증코드를 보내서 인증확인을 진행합니다.
    //
    //Future<bool> checkAuthSMS(AuthCheckReqDto authCheckReqDto) async
    test('test checkAuthSMS', () async {
      // TODO
    });

    // 사용자 생성
    //
    // 새로운 사용자를 등록합니다.
    //
    //Future<ApiResponseDtoUserRespDto> createUser(UserCreateReqDto userCreateReqDto) async
    test('test createUser', () async {
      // TODO
    });

    // Id로 사용자 삭제
    //
    // Id 로 사용자를 삭제합니다.
    //
    //Future<ApiResponseDtoUserRespDto> deleteUser(int id) async
    test('test deleteUser', () async {
      // TODO
    });

    // 키워드로 사용자 검색
    //
    // 키워드가 포함된 userId를 갖고있는 사용자를 전부 검색합니다.
    //
    //Future<ApiResponseDtoListUserRespDto> findUser(String nickname) async
    test('test findUser', () async {
      // TODO
    });

    // 모든유저 조회
    //
    // 모든유저를 조회합니다.
    //
    //Future<ApiResponseDtoListUserFindRespDto> getAllUsers() async
    test('test getAllUsers', () async {
      // TODO
    });

    // 특정유저 조회
    //
    // 유저의 id값(Long)으로 유저를 조회합니다.
    //
    //Future<ApiResponseDtoUserRespDto> getUser(int id) async
    test('test getUser', () async {
      // TODO
    });

    // 사용자 id 중복 체크
    //
    // 사용자 id 중복 체크합니다. 사용가능 : true, 사용불가(중복) : false
    //
    //Future<ApiResponseDtoBoolean> idCheck(String userId) async
    test('test idCheck', () async {
      // TODO
    });

    // 사용자 로그인(전화번호로)
    //
    // 인증이 완료된 전화번호로 로그인을 합니다.
    //
    //Future<ApiResponseDtoUserRespDto> loginByNickname(String nickName) async
    test('test loginByNickname', () async {
      // TODO
    });

    // 사용자 로그인(전화번호로)
    //
    // 인증이 완료된 전화번호로 로그인을 합니다.
    //
    //Future<ApiResponseDtoUserRespDto> loginByPhone(String phoneNum) async
    test('test loginByPhone', () async {
      // TODO
    });

    // 유저정보 업데이트
    //
    // 새로운 데이터로 유저정보를 업데이트합니다.
    //
    //Future<ApiResponseDtoUserRespDto> update1(UserUpdateReqDto userUpdateReqDto) async
    test('test update1', () async {
      // TODO
    });

    // 유저 프로필 업데이트
    //
    // 유저의 프로필을 업데이트 합니다. 기본 프로필로 변경하고싶으면 profileImageKey에 \"\" 을 넣으면 됩니다.
    //
    //Future<ApiResponseDtoUserRespDto> updateProfile(int userId, { String profileImageKey }) async
    test('test updateProfile', () async {
      // TODO
    });

  });
}
