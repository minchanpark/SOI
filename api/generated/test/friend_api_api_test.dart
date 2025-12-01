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


/// tests for FriendAPIApi
void main() {
  // final instance = FriendAPIApi();

  group('tests for FriendAPIApi', () {
    // 친구 차단
    //
    // 차단 요청을 한 사용자의 id : requesterId에 차단을 당하는 사용자의 id : receiverId에 담아서 요청
    //
    //Future<ApiResponseDtoBoolean> blockFriend(FriendReqDto friendReqDto) async
    test('test blockFriend', () async {
      // TODO
    });

    // 친구 추가
    //
    // 사용자 id를 통해 친구추가를 합니다.
    //
    //Future<ApiResponseDtoFriendRespDto> create(FriendReqDto friendReqDto) async
    test('test create', () async {
      // TODO
    });

    // 친구 삭제
    //
    // 삭제 요청을 한 사용자의 id : requesterId에 삭제를 당하는 사용자의 id : receiverId에 담아서 요청 만약 삭제후, 서로가 삭제된 관계면 친구 관계 컬럼을 삭제함
    //
    //Future<ApiResponseDtoBoolean> deleteFriend(FriendReqDto friendReqDto) async
    test('test deleteFriend', () async {
      // TODO
    });

    // 모든 친구 조회
    //
    // 유저의 id (user_id 말고 그냥 id)를 통해 모든 친구를 조회합니다.
    //
    //Future<ApiResponseDtoListUserFindRespDto> getAllFriend(int id) async
    test('test getAllFriend', () async {
      // TODO
    });

    // 친구 차단 해제
    //
    // 차단 해제 요청을 한 사용자의 id : requesterId에 차단 해제를 당하는 사용자의 id : receiverId에 담아서 요청차단 해제후에는 친구 관계가 완전 초기화 (삭제) 됩니다.
    //
    //Future<ApiResponseDtoBoolean> unBlockFriend(FriendReqDto friendReqDto) async
    test('test unBlockFriend', () async {
      // TODO
    });

    // 친구 상태 업데이트
    //
    // 친구 관계 id, 상태 : ACCEPTED, BLOCKED, CANCELLED 를 받아 상태를 업데이트합니다.
    //
    //Future<ApiResponseDtoFriendRespDto> update(FriendUpdateRespDto friendUpdateRespDto) async
    test('test update', () async {
      // TODO
    });

  });
}
