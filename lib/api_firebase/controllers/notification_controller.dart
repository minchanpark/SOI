import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../models/auth_result.dart';
import '../repositories/friend_repository.dart';
import '../repositories/user_search_repository.dart';
import '../services/friend_service.dart';
import '../services/notification_service.dart';

/// Notification Controller - 알림 관련 UI와 비즈니스 로직을 연결하는 Controller
/// Service를 사용해서 알림 상태를 관리하고 사용자 피드백을 제공
class NotificationController extends ChangeNotifier {
  // 기본 상태 변수들
  bool _isLoading = false;
  bool _isMarkingRead = false;
  String? _error;

  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  Map<String, int> _notificationStats = {};
  final Map<String, List<String>> _categoryUnknownMembersCache = {};

  // 페이지네이션 상태
  bool _hasMore = true;
  bool _isLoadingMore = false;
  static const int _pageSize = 20;

  StreamSubscription<List<NotificationModel>>? _notificationsSubscription;
  StreamSubscription<int>? _unreadCountSubscription;

  // Service 인스턴스 - 모든 비즈니스 로직은 Service에서 처리
  final NotificationService _notificationService = NotificationService();
  FriendService? _friendService;

  FriendService get friendService {
    _friendService ??= FriendService(
      friendRepository: FriendRepository(),
      userSearchRepository: UserSearchRepository(),
    );
    return _friendService!;
  }

  // ==================== Getters ====================

  bool get isLoading => _isLoading;
  bool get isMarkingRead => _isMarkingRead;
  String? get error => _error;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  Map<String, int> get notificationStats => _notificationStats;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  // 읽지 않은 알림들만 필터링
  List<NotificationModel> get unreadNotifications =>
      _notifications.where((notification) => !notification.isRead).toList();

  // 알림 타입별 그룹화
  Map<NotificationType, List<NotificationModel>> get notificationsByType {
    final Map<NotificationType, List<NotificationModel>> grouped = {};
    for (final notification in _notifications) {
      if (!grouped.containsKey(notification.type)) {
        grouped[notification.type] = [];
      }
      grouped[notification.type]!.add(notification);
    }
    return grouped;
  }

  // ==================== 알림 조회 메서드들 ====================

  /// 사용자의 알림 목록을 실시간으로 구독 시작
  Future<void> startListening(String userId) async {
    if (userId.isEmpty) {
      _setError('사용자 ID가 비어있습니다.');
      return;
    }

    try {
      _setLoading(true);
      _clearError();

      await stopListening();
      _performBackgroundCleanup(userId);

      _notificationsSubscription = _notificationService
          .getUserNotificationsStream(userId)
          .listen(_onNotificationsUpdated, onError: _onNotificationsError);

      _unreadCountSubscription = _notificationService
          .getUnreadCountStream(userId)
          .listen(_onUnreadCountUpdated, onError: _onUnreadCountError);
    } catch (e) {
      _setError('알림 구독 시작 실패: $e');
      debugPrint('알림 구독 시작 실패: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// 실시간 구독 중지
  Future<void> stopListening() async {
    await _notificationsSubscription?.cancel();
    await _unreadCountSubscription?.cancel();
    _notificationsSubscription = null;
    _unreadCountSubscription = null;
  }

  /// 알림 목록 새로고침
  Future<void> refreshNotifications(String userId) async {
    if (userId.isEmpty) {
      _setError('사용자 ID가 비어있습니다.');
      return;
    }

    try {
      _setLoading(true);
      _clearError();

      final notifications = await _notificationService.getUserNotifications(
        userId,
        limit: _pageSize,
      );

      _notifications = notifications;
      _hasMore = notifications.length >= _pageSize;
      notifyListeners();
    } catch (e) {
      _setError('알림 새로고침 실패: $e');
      debugPrint('알림 새로고침 실패: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// 추가 알림 로드 (페이지네이션)
  Future<void> loadMoreNotifications(String userId) async {
    if (_isLoadingMore || !_hasMore || userId.isEmpty) return;

    try {
      _setLoadingMore(true);

      final moreNotifications = await _notificationService.getUserNotifications(
        userId,
        limit: _pageSize,
      );

      if (moreNotifications.isNotEmpty) {
        _notifications.addAll(moreNotifications);
        _hasMore = moreNotifications.length >= _pageSize;
        notifyListeners();
      } else {
        _hasMore = false;
      }
    } catch (e) {
      _setError('추가 알림 로드 실패: $e');
      debugPrint('추가 알림 로드 실패: $e');
    } finally {
      _setLoadingMore(false);
    }
  }

  // ==================== 알림 액션 메서드들 ====================

  /// 특정 알림을 읽음으로 표시
  Future<void> markAsRead(String notificationId) async {
    if (notificationId.isEmpty) {
      _setError('알림 ID가 비어있습니다.');
      return;
    }

    try {
      _setMarkingRead(true);
      _clearError();

      await _notificationService.markAsRead(notificationId);

      final notificationIndex = _notifications.indexWhere(
        (n) => n.id == notificationId,
      );
      if (notificationIndex != -1) {
        _notifications[notificationIndex] = _notifications[notificationIndex]
            .copyWith(isRead: true);
        if (_unreadCount > 0) {
          _unreadCount--;
        }
        notifyListeners();
      }
    } catch (e) {
      _setError('알림 읽음 처리 실패: $e');
      debugPrint('알림 읽음 처리 실패: $e');
    } finally {
      _setMarkingRead(false);
    }
  }

  /// 모든 알림을 읽음으로 표시
  Future<void> markAllAsRead(String userId) async {
    if (userId.isEmpty) {
      _setError('사용자 ID가 비어있습니다.');
      return;
    }

    try {
      _setMarkingRead(true);
      _clearError();

      await _notificationService.markAllAsRead(userId);

      for (int i = 0; i < _notifications.length; i++) {
        if (!_notifications[i].isRead) {
          _notifications[i] = _notifications[i].copyWith(isRead: true);
        }
      }
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      _setError('모든 알림 읽음 처리 실패: $e');
      debugPrint('모든 알림 읽음 처리 실패: $e');
    } finally {
      _setMarkingRead(false);
    }
  }

  /// 특정 알림 삭제
  Future<void> deleteNotification(String notificationId) async {
    if (notificationId.isEmpty) {
      _setError('알림 ID가 비어있습니다.');
      return;
    }

    try {
      _clearError();

      await _notificationService.deleteNotification(notificationId);

      final notificationIndex = _notifications.indexWhere(
        (n) => n.id == notificationId,
      );
      final wasUnread =
          notificationIndex != -1 && !_notifications[notificationIndex].isRead;

      _notifications.removeWhere((n) => n.id == notificationId);

      if (wasUnread && _unreadCount > 0) {
        _unreadCount--;
      }

      notifyListeners();
    } catch (e) {
      _setError('알림 삭제 실패: $e');
      debugPrint('알림 삭제 실패: $e');
    }
  }

  /// 알림 탭 처리 (읽음 처리 + 네비게이션)
  Future<void> onNotificationTap(NotificationModel notification) async {
    if (!notification.isRead) {
      await markAsRead(notification.id);
    }
  }

  // ==================== 통계 및 유틸리티 메서드들 ====================

  /// 알림 통계 정보 로드
  Future<void> loadNotificationStats(String userId) async {
    if (userId.isEmpty) return;

    try {
      final stats = await _notificationService.getNotificationStats(userId);
      _notificationStats = stats;
      notifyListeners();
    } catch (e) {
      debugPrint('알림 통계 로드 실패: $e');
    }
  }

  /// 오래된 알림 정리
  Future<void> cleanupOldNotifications(String userId) async {
    if (userId.isEmpty) return;

    try {
      await _notificationService.cleanupOldNotifications(userId);
      await refreshNotifications(userId);
    } catch (e) {
      debugPrint('오래된 알림 정리 실패: $e');
    }
  }

  /// 카테고리 초대 알림에서 친구가 아닌 사용자 목록 반환
  Future<List<String>> getUnknownCategoryMembers({
    required NotificationModel notification,
    required String currentUserId,
  }) async {
    if (notification.pendingCategoryMemberIds != null &&
        notification.pendingCategoryMemberIds!.isNotEmpty) {
      return notification.pendingCategoryMemberIds!;
    }

    final categoryId = notification.categoryId;
    if (categoryId == null || categoryId.isEmpty) {
      return [];
    }

    final cached = _categoryUnknownMembersCache[categoryId];
    if (cached != null) {
      return cached;
    }

    try {
      final category = await _notificationService.categoryService.getCategory(
        categoryId,
      );
      if (category == null) {
        _categoryUnknownMembersCache[categoryId] = const [];
        return [];
      }

      final mates = category.mates;
      if (mates.isEmpty) {
        _categoryUnknownMembersCache[categoryId] = const [];
        return [];
      }

      final friends = await friendService.getFriendsList().first;
      final friendUids = friends.map((f) => f.userId).toSet();
      final friendIds = friends.map((f) => f.id).toSet();

      final Set<String> unknownSet = {};
      for (final mate in mates) {
        if (mate.isEmpty) continue;
        if (mate == currentUserId) continue;
        if (friendUids.contains(mate)) continue;
        if (friendIds.contains(mate)) continue;
        unknownSet.add(mate);
      }

      final unknownList = unknownSet.toList();
      _categoryUnknownMembersCache[categoryId] = unknownList;
      return unknownList;
    } catch (e) {
      debugPrint('모르는 사용자 검사 실패: $e');
      return [];
    }
  }

  Future<AuthResult> acceptCategoryInvite({
    required NotificationModel notification,
    required String currentUserId,
  }) async {
    final result = await _notificationService.acceptCategoryInvite(
      notification: notification,
      userId: currentUserId,
    );

    if (result.isSuccess) {
      _notifications =
          _notifications.map((n) {
            if (n.id == notification.id) {
              return n.copyWith(
                isRead: true,
                requiresAcceptance: false,
                pendingCategoryMemberIds: [],
              );
            }
            return n;
          }).toList();

      if (notification.categoryId != null) {
        _categoryUnknownMembersCache.remove(notification.categoryId!);
      }

      notifyListeners();
    }

    return result;
  }

  Future<AuthResult> declineCategoryInvite({
    required NotificationModel notification,
    required String currentUserId,
  }) async {
    final result = await _notificationService.declineCategoryInvite(
      notification: notification,
      userId: currentUserId,
    );

    if (result.isSuccess) {
      _notifications.removeWhere((n) => n.id == notification.id);
      if (notification.categoryId != null) {
        _categoryUnknownMembersCache.remove(notification.categoryId!);
      }
      notifyListeners();
    }
    return result;
  }

  /// 백그라운드에서 자동 알림 정리 수행
  void _performBackgroundCleanup(String userId) {
    Future.delayed(Duration(seconds: 2), () {
      _notificationService.performUserCleanupOnStart(userId).catchError((e) {
        debugPrint('백그라운드 알림 정리 실패: $e');
      });
    });
  }

  // ==================== 개발용 메서드들 ====================

  /// 개발용: 모든 알림 삭제
  Future<void> deleteAllNotifications(String userId) async {
    if (userId.isEmpty) return;

    try {
      await _notificationService.deleteAllUserNotifications(userId);

      _notifications.clear();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      _setError('모든 알림 삭제 실패: $e');
      debugPrint('모든 알림 삭제 실패: $e');
    }
  }

  // ==================== 내부 헬퍼 메서드들 ====================

  /// 실시간 알림 업데이트 처리
  void _onNotificationsUpdated(List<NotificationModel> notifications) {
    _categoryUnknownMembersCache.clear();
    _notifications = notifications;
    notifyListeners();
  }

  /// 실시간 알림 에러 처리
  void _onNotificationsError(dynamic error) {
    _setError('실시간 알림 업데이트 오류: $error');
    debugPrint('실시간 알림 오류: $error');
  }

  /// 실시간 읽지 않은 개수 업데이트 처리
  void _onUnreadCountUpdated(int count) {
    _unreadCount = count;
    notifyListeners();
  }

  /// 실시간 읽지 않은 개수 에러 처리
  void _onUnreadCountError(dynamic error) {
    debugPrint('읽지 않은 개수 업데이트 오류: $error');
  }

  /// 로딩 상태 설정
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// 추가 로딩 상태 설정
  void _setLoadingMore(bool loading) {
    if (_isLoadingMore != loading) {
      _isLoadingMore = loading;
      notifyListeners();
    }
  }

  /// 읽음 처리 상태 설정
  void _setMarkingRead(bool marking) {
    if (_isMarkingRead != marking) {
      _isMarkingRead = marking;
      notifyListeners();
    }
  }

  /// 에러 설정
  void _setError(String? error) {
    if (_error != error) {
      _error = error;
      notifyListeners();
    }
  }

  /// 에러 제거
  void _clearError() {
    _setError(null);
  }

  // ==================== 생명주기 관리 ====================

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
