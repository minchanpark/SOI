import 'package:flutter/material.dart';
import 'package:soi_api_client/api.dart';

import '../models/models.dart';

/// 친구 컨트롤러 추상 클래스
///
/// 친구 관련 기능을 정의하는 인터페이스입니다.
/// 구현체를 교체하여 테스트나 다른 백엔드 사용이 가능합니다.
///
/// 사용 예시:
/// ```dart
/// final friendController = Provider.of<FriendController>(context, listen: false);
///
/// // 친구 추가
/// final friend = await friendController.addFriend(
///   requesterId: 1,
///   receiverPhoneNum: '01012345678',
/// );
///
/// // 친구 목록 조회
/// final friends = await friendController.getAllFriends(userId: 1);
///
/// // 친구 차단
/// final blocked = await friendController.blockFriend(
///   requesterId: 1,
///   receiverId: 2,
/// );
/// ```
abstract class FriendController extends ChangeNotifier {
  /// 로딩 상태
  bool get isLoading;

  /// 에러 메시지
  String? get errorMessage;

  // ============================================
  // 친구 추가
  // ============================================

  /// 친구 추가 요청
  ///
  /// [requesterId]가 [receiverPhoneNum]에게 친구 추가 요청을 보냅니다.
  ///
  /// Parameters:
  /// - [requesterId]: 요청자 ID
  /// - [receiverPhoneNum]: 대상 사용자 전화번호
  ///
  /// Returns: 생성된 친구 관계 정보 (Friend)
  Future<Friend?> addFriend({
    required int requesterId,
    required String receiverPhoneNum,
  });

  // ============================================
  // 친구 조회
  // ============================================

  /// 모든 친구 목록 조회
  ///
  /// [userId]의 모든 친구 목록을 조회합니다.
  ///
  /// Returns: 친구 목록 (List<User>)
  Future<List<User>> getAllFriends({required int userId});

  /// 연락처 친구 관계 확인
  ///
  /// [phoneNumbers] 목록에 해당하는 사용자들과의 친구 관계를 확인합니다.
  /// 연락처 기반 친구 찾기에 사용됩니다.
  ///
  /// Parameters:
  /// - [userId]: 요청 사용자 ID
  /// - [phoneNumbers]: 확인할 전화번호 목록
  ///
  /// Returns: 친구 관계 정보 목록 (List<FriendCheckRespDto>)
  Future<List<FriendCheckRespDto>> checkFriendRelations({
    required int userId,
    required List<String> phoneNumbers,
  });

  // ============================================
  // 친구 차단
  // ============================================

  /// 친구 차단
  ///
  /// [requesterId]가 [receiverId]를 차단합니다.
  ///
  /// Returns: 차단 성공 여부
  Future<bool> blockFriend({required int requesterId, required int receiverId});

  /// 친구 차단 해제
  ///
  /// [requesterId]가 [receiverId]의 차단을 해제합니다.
  /// 차단 해제 후 친구 관계는 완전히 초기화됩니다.
  ///
  /// Returns: 차단 해제 성공 여부
  Future<bool> unblockFriend({
    required int requesterId,
    required int receiverId,
  });

  // ============================================
  // 친구 삭제
  // ============================================

  /// 친구 삭제
  ///
  /// [requesterId]가 [receiverId]를 친구에서 삭제합니다.
  /// 서로 모두 삭제한 경우 친구 관계 자체가 삭제됩니다.
  ///
  /// Returns: 삭제 성공 여부
  Future<bool> deleteFriend({
    required int requesterId,
    required int receiverId,
  });

  // ============================================
  // 친구 상태 업데이트
  // ============================================

  /// 친구 관계 상태 업데이트
  ///
  /// 친구 관계의 상태를 변경합니다.
  ///
  /// Parameters:
  /// - [friendId]: 친구 관계 ID
  /// - [status]: 변경할 상태 (ACCEPTED, BLOCKED, CANCELLED)
  ///
  /// Returns: 업데이트된 친구 관계 정보 (FriendRespDto)
  Future<FriendRespDto?> updateFriendStatus({
    required int friendId,
    required FriendStatus status,
  });

  // ============================================
  // 에러 처리
  // ============================================

  /// 에러 초기화
  void clearError();
}
