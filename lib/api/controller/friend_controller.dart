import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/friend_service.dart';

/// 친구 컨트롤러
///
/// 친구 관련 UI 상태 관리 및 비즈니스 로직을 담당합니다.
/// FriendService를 내부적으로 사용하며, API 변경 시 Service만 수정하면 됩니다.
///
/// 사용 예시:
/// ```dart
/// final controller = Provider.of<FriendController>(context, listen: false);
///
/// // 친구 추가
/// final friend = await controller.addFriend(
///   requesterId: 1,
///   receiverPhoneNum: '01012345678',
/// );
///
/// // 친구 목록 조회
/// final friends = await controller.getAllFriends(userId: 1);
/// ```
class FriendController extends ChangeNotifier {
  final FriendService _friendService;

  bool _isLoading = false;
  String? _errorMessage;

  /// 생성자
  ///
  /// [friendService]를 주입받아 사용합니다. 테스트 시 MockFriendService를 주입할 수 있습니다.
  FriendController({FriendService? friendService})
    : _friendService = friendService ?? FriendService();

  /// 로딩 상태
  bool get isLoading => _isLoading;

  /// 에러 메시지
  String? get errorMessage => _errorMessage;

  // ============================================
  // 친구 추가
  // ============================================

  /// 친구 추가
  /// 친구 추가 요청을 보내고, 친구 추가 결과를 반환합니다.
  ///
  /// Parameters:
  ///   - [requesterId]: 친구 요청자 ID
  ///   - [receiverPhoneNum]: 친구 수신자 전화번호
  ///
  /// Returns:
  ///   - [Friend]: 추가된 친구 정보 (실패 시 null)
  ///   - null: 친구 추가 실패
  ///     - 실패한 경우에는, 클라이언트에서 문자로 앱 설치 링크나 앱 설치 안내 페이지를 보내도록 처리해야 합니다.
  Future<Friend?> addFriend({
    required int requesterId,
    required String receiverPhoneNum,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final friend = await _friendService.addFriend(
        requesterId: requesterId,
        receiverPhoneNum: receiverPhoneNum,
      );
      _setLoading(false);
      return friend;
    } catch (e) {
      _setError('친구 추가 실패: $e');
      _setLoading(false);
      return null;
    }
  }

  // ============================================
  // 친구 조회
  // ============================================

  /// 모든 친구 조회
  /// 주어진 사용자 ID에 대한 모든 친구 목록을 반환합니다.
  ///
  /// Parameters:
  ///   - [userId]: 친구 목록을 조회할 사용자 ID
  ///
  /// Returns:
  ///   - [List<User>]: 친구 목록 (실패 시 빈 리스트)
  Future<List<User>> getAllFriends({
    required int userId,
    FriendStatus status = FriendStatus.accepted,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final friends = await _friendService.getAllFriends(
        userId: userId,
        status: status,
      );
      _setLoading(false);
      return friends;
    } catch (e) {
      _setError('친구 목록 조회 실패: $e');
      _setLoading(false);
      return [];
    }
  }

  /// 친구관계 확인
  /// 주어진 전화번호 목록에 대한 친구 관계를 확인합니다.
  ///
  /// Parameters:
  ///   - [userId]: 친구 관계를 확인할 사용자 ID
  ///   - [phoneNumbers]: 친구 관계를 확인할 전화번호 목록
  ///
  /// Returns:
  ///   - [List<FriendCheck>]: 친구 관계 확인 결과 목록 (실패 시 빈 리스트)
  Future<List<FriendCheck>> checkFriendRelations({
    required int userId,
    required List<String> phoneNumbers,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final relations = await _friendService.checkFriendRelations(
        userId: userId,
        phoneNumbers: phoneNumbers,
      );
      _setLoading(false);
      return relations;
    } catch (e) {
      _setError('친구 관계 확인 실패: $e');
      _setLoading(false);
      return [];
    }
  }

  // ============================================
  // 친구 차단
  // ============================================

  /// 친구 차단
  /// 주어진 친구를 차단합니다.
  ///
  /// Parameters:
  ///   - [requesterId]: 차단 요청자 ID
  ///   - [receiverId]: 차단 대상자 ID
  ///
  /// Returns:
  ///   - [bool]: 차단 성공 여부
  ///     - true: 차단 성공
  ///     - false: 차단 실패
  Future<bool> blockFriend({
    required int requesterId,
    required int receiverId,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _friendService.blockFriend(
        requesterId: requesterId,
        receiverId: receiverId,
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('친구 차단 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  /// 차단 해제
  /// 주어진 친구의 차단을 해제합니다.
  ///
  /// Parameters:
  ///   - [requesterId]: 차단 해제 요청자 ID
  ///   - [receiverId]: 차단 해제 대상자 ID
  ///
  /// Returns:
  ///   - [bool]: 차단 해제 성공 여부
  ///     - true: 차단 해제 성공
  ///     - false: 차단 해제 실패
  Future<bool> unblockFriend({
    required int requesterId,
    required int receiverId,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _friendService.unblockFriend(
        requesterId: requesterId,
        receiverId: receiverId,
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('차단 해제 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  // ============================================
  // 친구 삭제
  // ============================================

  /// 친구 삭제
  /// 주어진 친구를 삭제합니다.
  ///
  /// Parameters:
  ///   - [requesterId]: 삭제 요청자 ID
  ///   - [receiverId]: 삭제 대상자 ID
  ///
  /// Returns:
  ///   - [bool]: 삭제 성공 여부
  ///     - true: 삭제 성공
  ///     - false: 삭제 실패
  Future<bool> deleteFriend({
    required int requesterId,
    required int receiverId,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _friendService.deleteFriend(
        requesterId: requesterId,
        receiverId: receiverId,
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('친구 삭제 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  // ============================================
  // 친구 상태 업데이트
  // ============================================

  /// 친구 상태 업데이트
  /// 주어진 친구의 상태를 업데이트합니다.
  ///
  /// Parameters:
  ///   - [friendId]: 상태를 업데이트할 친구 ID
  ///   - [status]: 업데이트할 친구 상태 (FriendStatus enum)
  ///
  /// Returns:
  ///   - [Friend?]: 업데이트된 친구 정보 (실패 시 null)
  Future<Friend?> updateFriendStatus({
    required int friendId,
    required FriendStatus status,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _friendService.updateFriendStatus(
        friendId: friendId,
        status: status,
      );
      _setLoading(false);
      // DTO를 Friend 모델로 변환
      return Friend.fromDto(result);
    } catch (e) {
      _setError('친구 상태 업데이트 실패: $e');
      _setLoading(false);
      return null;
    }
  }

  // ============================================
  // 에러 처리
  // ============================================

  void clearError() {
    _clearError();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}
