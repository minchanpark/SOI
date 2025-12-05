import 'package:flutter/material.dart';
import 'package:soi_api_client/api.dart';

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

  Future<List<User>> getAllFriends({required int userId}) async {
    _setLoading(true);
    _clearError();

    try {
      final friends = await _friendService.getAllFriends(userId: userId);
      _setLoading(false);
      return friends;
    } catch (e) {
      _setError('친구 목록 조회 실패: $e');
      _setLoading(false);
      return [];
    }
  }

  Future<List<FriendCheckRespDto>> checkFriendRelations({
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

  Future<FriendRespDto?> updateFriendStatus({
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
      return result;
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
