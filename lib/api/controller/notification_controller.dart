import 'package:flutter/material.dart';

import '../models/notification.dart';
import '../services/notification_service.dart';

/// REST API 기반 알림 컨트롤러
///
/// NotificationService를 사용하여 알림 관련 기능을 구현합니다.
class NotificationController extends ChangeNotifier {
  final NotificationService _notificationService;

  bool _isLoading = false;
  String? _errorMessage;

  // 캐시된 알림 데이터
  NotificationGetAllResult? _cachedResult;
  List<AppNotification>? _cachedFriendNotifications;
  int? _lastLoadedUserId;
  DateTime? _lastLoadTime;
  static const Duration _cacheTimeout = Duration(seconds: 30);

  NotificationController({NotificationService? notificationService})
    : _notificationService = notificationService ?? NotificationService();

  /// 로딩 상태
  bool get isLoading => _isLoading;

  /// 에러 메시지
  String? get errorMessage => _errorMessage;

  /// 캐시된 알림 결과
  NotificationGetAllResult? get cachedResult => _cachedResult;

  /// 캐시된 친구 알림
  List<AppNotification>? get cachedFriendNotifications =>
      _cachedFriendNotifications;

  // ============================================
  // 알림 조회
  // ============================================

  /// 모든 알림 조회
  ///
  /// [userId]의 모든 알림을 조회합니다.
  /// 친구 요청 개수와 전체 알림 목록을 반환합니다.
  ///
  /// Parameters:
  /// - [userId]: 사용자 ID
  ///
  /// Returns: 알림 결과 (NotificationGetAllResult)
  Future<NotificationGetAllResult> getAllNotifications({
    required int userId,
  }) async {
    // 캐시 확인
    final now = DateTime.now();
    final isCacheValid =
        _lastLoadTime != null &&
        now.difference(_lastLoadTime!) < _cacheTimeout &&
        _lastLoadedUserId == userId;

    if (isCacheValid && _cachedResult != null) {
      return _cachedResult!;
    }

    _setLoading(true);
    _clearError();

    try {
      final result = await _notificationService.getAllNotifications(
        userId: userId,
      );

      // 캐시 저장
      _cachedResult = result;
      _lastLoadedUserId = userId;
      _lastLoadTime = DateTime.now();

      _setLoading(false);
      return result;
    } catch (e) {
      _setError('알림 조회 실패: $e');
      _setLoading(false);
      return const NotificationGetAllResult();
    }
  }

  /// 친구 관련 알림 조회
  ///
  /// [userId]의 친구 요청 관련 알림만 조회합니다.
  ///
  /// Parameters:
  /// - [userId]: 사용자 ID
  ///
  /// Returns: 친구 관련 알림 목록 (List<AppNotification>)
  Future<List<AppNotification>> getFriendNotifications({
    required int userId,
    int page = 0,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final notifications = await _notificationService.getFriendNotifications(
        userId: userId,
        page: page,
      );

      // 캐시 저장
      _cachedFriendNotifications = notifications;

      _setLoading(false);
      return notifications;
    } catch (e) {
      _setError('친구 알림 조회 실패: $e');
      _setLoading(false);
      return [];
    }
  }

  /// 친구 관련 알림 전체 조회 (페이지 순회)
  ///
  /// 알림 API의 get-friend 응답을 페이지 단위로 전부 가져와서 반환합니다.
  /// 친구 요청 개수는 이 리스트의 길이로 계산할 수 있습니다.
  Future<List<AppNotification>> getAllFriendNotifications({
    required int userId,
    int maxPages = 20,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final all = <AppNotification>[];
      for (var page = 0; page < maxPages; page++) {
        final items = await _notificationService.getFriendNotifications(
          userId: userId,
          page: page,
        );
        if (items.isEmpty) break;
        all.addAll(items);
      }

      _cachedFriendNotifications = all;
      _setLoading(false);
      return all;
    } catch (e) {
      _setError('친구 알림 조회 실패: $e');
      _setLoading(false);
      return [];
    }
  }

  /// 친구 요청 개수 조회 (편의 메서드)
  ///
  /// Returns: 친구 요청 개수
  Future<int> getFriendRequestCount({required int userId}) async {
    _setLoading(true);
    _clearError();

    try {
      final count = await _notificationService.getFriendRequestCount(
        userId: userId,
      );
      _setLoading(false);
      return count;
    } catch (e) {
      _setError('친구 요청 개수 조회 실패: $e');
      _setLoading(false);
      return 0;
    }
  }

  /// 알림 개수 조회 (편의 메서드)
  ///
  /// Returns: 전체 알림 개수
  Future<int> getNotificationCount({required int userId}) async {
    _setLoading(true);
    _clearError();

    try {
      final count = await _notificationService.getNotificationCount(
        userId: userId,
      );
      _setLoading(false);
      return count;
    } catch (e) {
      _setError('알림 개수 조회 실패: $e');
      _setLoading(false);
      return 0;
    }
  }

  // ============================================
  // 캐시 관리
  // ============================================

  /// 캐시 무효화
  void invalidateCache() {
    _cachedResult = null;
    _cachedFriendNotifications = null;
    _lastLoadedUserId = null;
    _lastLoadTime = null;
    notifyListeners();
  }

  /// 강제 새로고침
  Future<NotificationGetAllResult> refreshNotifications({
    required int userId,
  }) async {
    invalidateCache();
    return getAllNotifications(userId: userId);
  }

  // ============================================
  // 에러 처리
  // ============================================

  /// 에러 초기화
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
