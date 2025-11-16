import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../models/auth_result.dart';
import '../repositories/notification_repository.dart';
import '../repositories/friend_repository.dart';
import '../repositories/user_search_repository.dart';
import 'category_service.dart';
import 'media_service.dart';
import 'auth_service.dart';
import 'friend_service.dart';

/// 알림 비즈니스 로직을 처리하는 Service
/// Repository를 사용해서 실제 비즈니스 규칙을 적용
class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final NotificationRepository _notificationRepository =
      NotificationRepository();
  final AuthService _authService = AuthService();

  // Lazy initialization으로 순환 의존성 방지
  CategoryService? _categoryService;
  CategoryService get categoryService {
    _categoryService ??= CategoryService();
    return _categoryService!;
  }

  PhotoService? _photoService;
  PhotoService get photoService {
    _photoService ??= PhotoService();
    return _photoService!;
  }

  FriendService? _friendService;
  FriendService get friendService {
    _friendService ??= FriendService(
      friendRepository: FriendRepository(),
      userSearchRepository: UserSearchRepository(),
    );
    return _friendService!;
  }

  // ==================== 알림 생성 비즈니스 로직 ====================

  /// 카테고리 초대 알림 생성
  Future<void> createCategoryInviteNotification({
    required String categoryId,
    required String actorUserId,
    required List<String> recipientUserIds,
    bool requiresAcceptance = false,
    String? categoryInviteId,
    List<String>? pendingMemberIds,
  }) async {
    try {
      if (categoryId.isEmpty ||
          actorUserId.isEmpty ||
          recipientUserIds.isEmpty) {
        throw ArgumentError('필수 파라미터가 누락되었습니다.');
      }

      final categories = await categoryService.getUserCategories(actorUserId);
      final category = categories.firstWhere(
        (cat) => cat.id == categoryId,
        orElse: () => throw Exception('카테고리를 찾을 수 없습니다: $categoryId'),
      );

      debugPrint(
        '카테고리 정보 - 이름: ${category.name}, 멤버 수: ${category.mates.length}, 멤버: ${category.mates}',
      );

      final actor = await _authService.getCurrentUser();
      if (actor == null) {
        throw Exception('사용자 정보를 찾을 수 없습니다: $actorUserId');
      }

      int notificationCount = 0;
      for (String recipientId in recipientUserIds) {
        if (recipientId != actorUserId) {
          await _createNotification(
            recipientUserId: recipientId,
            actorUserId: actorUserId,
            type: NotificationType.categoryInvite,
            title: "${actor.name}님이 '${category.name}' 카테고리에 초대했습니다",
            categoryId: categoryId,
            categoryName: category.name,
            thumbnailUrl: category.categoryPhotoUrl,
            categoryThumbnailUrl: category.categoryPhotoUrl,
            actorName: actor.name,
            actorProfileImage: actor.profileImage,
            requiresAcceptance: requiresAcceptance,
            categoryInviteId: categoryInviteId,
            pendingCategoryMemberIds: pendingMemberIds,
          );
          notificationCount++;
        }
      }

      debugPrint('카테고리 초대 알림 생성 완료 - 생성된 알림 수: $notificationCount');
    } catch (e) {
      debugPrint('카테고리 초대 알림 생성 실패: $e');
      rethrow;
    }
  }

  /// 사진 추가 알림 생성
  Future<void> createPhotoAddedNotification({
    required String categoryId,
    required String photoId,
    required String actorUserId,
    String? photoUrl,
  }) async {
    try {
      if (categoryId.isEmpty || photoId.isEmpty || actorUserId.isEmpty) {
        throw ArgumentError('필수 파라미터가 누락되었습니다.');
      }

      final categories = await categoryService.getUserCategories(actorUserId);
      final category = categories.firstWhere(
        (cat) => cat.id == categoryId,
        orElse: () => throw Exception('카테고리를 찾을 수 없습니다: $categoryId'),
      );

      debugPrint(
        '📁 사진 추가 - 카테고리: ${category.name}, 멤버 수: ${category.mates.length}, 멤버: ${category.mates}',
      );

      String imageUrl = photoUrl ?? '';
      if (imageUrl.isEmpty) {
        // 사진을 찾지 못할 경우 약간의 지연 후 재시도
        await Future.delayed(Duration(milliseconds: 200));

        final photos = await photoService.getPhotosByCategory(categoryId);
        final photo = photos.firstWhere(
          (p) => p.id == photoId,
          orElse: () {
            debugPrint('⚠️ 사진을 찾을 수 없지만 알림 생성 계속 진행: $photoId');
            return photos.isNotEmpty
                ? photos.first
                : throw Exception('사진을 찾을 수 없습니다: $photoId');
          },
        );
        imageUrl = photo.imageUrl;
      }

      final actor = await _authService.getCurrentUser();
      if (actor == null) {
        throw Exception('사용자 정보를 찾을 수 없습니다: $actorUserId');
      }

      int notificationCount = 0;
      for (String memberId in category.mates) {
        if (memberId != actorUserId) {
          await _createNotification(
            recipientUserId: memberId,
            actorUserId: actorUserId,
            type: NotificationType.photoAdded,
            title: "${actor.name}님이 '${category.name}' 카테고리에 사진을 추가했습니다",
            categoryId: categoryId,
            categoryName: category.name,
            photoId: photoId,
            thumbnailUrl: imageUrl,
            categoryThumbnailUrl: category.categoryPhotoUrl,
            photoThumbnailUrl: imageUrl,
            actorName: actor.name,
            actorProfileImage: actor.profileImage,
          );
          notificationCount++;
        }
      }

      debugPrint('✅ 사진 추가 알림 생성 완료 - 생성된 알림 수: $notificationCount');
    } catch (e) {
      debugPrint('❌ 사진 추가 알림 생성 실패: $e');
      rethrow;
    }
  }

  /// 음성 댓글 알림 생성
  Future<void> createVoiceCommentNotification({
    required String photoId,
    required String commentId,
    required String actorUserId,
  }) async {
    try {
      if (photoId.isEmpty || commentId.isEmpty || actorUserId.isEmpty) {
        throw ArgumentError('필수 파라미터가 누락되었습니다.');
      }

      final actor = await _authService.getCurrentUser();
      if (actor == null) {
        throw Exception('사용자 정보를 찾을 수 없습니다: $actorUserId');
      }

      // 모든 카테고리에서 해당 사진이 있는 카테고리 찾기
      final categories = await categoryService.getUserCategories(actorUserId);
      String? targetCategoryId;
      String? targetCategoryName;
      String? photoThumbnailUrl;

      for (final category in categories) {
        final photos = await photoService.getPhotosByCategory(category.id);
        final photo = photos.where((p) => p.id == photoId).firstOrNull;
        if (photo != null) {
          targetCategoryId = category.id;
          targetCategoryName = category.name;
          photoThumbnailUrl = photo.imageUrl;
          break;
        }
      }

      if (targetCategoryId == null) {
        throw Exception('사진이 속한 카테고리를 찾을 수 없습니다: $photoId');
      }

      final targetCategory = categories.firstWhere(
        (cat) => cat.id == targetCategoryId,
      );

      // 카테고리의 다른 멤버들에게 알림 생성
      for (String memberId in targetCategory.mates) {
        if (memberId != actorUserId) {
          await _createNotification(
            recipientUserId: memberId,
            actorUserId: actorUserId,
            type: NotificationType.voiceCommentAdded,
            title: "${actor.name}님이 음성 댓글을 달았습니다",
            categoryId: targetCategoryId,
            categoryName: targetCategoryName,
            photoId: photoId,
            commentId: commentId,
            thumbnailUrl: photoThumbnailUrl,
            categoryThumbnailUrl: targetCategory.categoryPhotoUrl,
            photoThumbnailUrl: photoThumbnailUrl,
            actorName: actor.name,
            actorProfileImage: actor.profileImage,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ 음성 댓글 알림 생성 실패: $e');
      rethrow;
    }
  }

  /// 친구 요청 알림 생성
  Future<void> createFriendRequestNotification({
    required String actorUserId,
    required String recipientUserId,
  }) async {
    try {
      if (actorUserId.isEmpty || recipientUserId.isEmpty) {
        throw ArgumentError('필수 파라미터가 누락되었습니다.');
      }

      if (actorUserId == recipientUserId) {
        debugPrint('자신에게는 친구 요청 알림을 보낼 수 없습니다.');
        return;
      }

      final actor = await _authService.getCurrentUser();
      if (actor == null) {
        throw Exception('사용자 정보를 찾을 수 없습니다: $actorUserId');
      }

      await _createNotification(
        recipientUserId: recipientUserId,
        actorUserId: actorUserId,
        type: NotificationType.friendRequest,
        title: '${actor.name}님이 친구 요청을 보냈습니다',
        actorName: actor.name,
        actorProfileImage: actor.profileImage,
      );

      debugPrint('✅ 친구 요청 알림 생성 완료: $actorUserId -> $recipientUserId');
    } catch (e) {
      debugPrint('❌ 친구 요청 알림 생성 실패: $e');
      rethrow;
    }
  }

  // ==================== 알림 관리 비즈니스 로직 ====================

  /// 사용자의 알림 목록을 실시간 스트림으로 가져오기
  Stream<List<NotificationModel>> getUserNotificationsStream(String userId) {
    if (userId.isEmpty) return Stream.value([]);

    // 차단된 사용자가 있는 알림을 필터링한 스트림 반환
    return _notificationRepository.getUserNotificationsStream(userId).asyncMap((
      notifications,
    ) async {
      return await _filterNotificationsWithBlockedUsers(notifications);
    });
  }

  /// 사용자의 알림 목록을 한 번만 가져오기 (페이징 지원)
  Future<List<NotificationModel>> getUserNotifications(
    String userId, {
    int limit = 10,
  }) async {
    if (userId.isEmpty) return [];

    final notifications = await _notificationRepository.getUserNotifications(
      userId,
      limit: limit,
    );
    return await _filterNotificationsWithBlockedUsers(notifications);
  }

  /// 읽지 않은 알림 개수 실시간 스트림
  Stream<int> getUnreadCountStream(String userId) {
    if (userId.isEmpty) return Stream.value(0);

    // 전체 알림 스트림에서 읽지 않은 것만 카운트 (차단 필터링 포함)
    return getUserNotificationsStream(userId).map((notifications) {
      return notifications.where((notification) => !notification.isRead).length;
    });
  }

  /// 읽지 않은 알림 개수 조회
  Future<int> getUnreadCount(String userId) async {
    if (userId.isEmpty) return 0;

    final notifications = await getUserNotifications(userId);
    return notifications.where((notification) => !notification.isRead).length;
  }

  /// 특정 알림을 읽음으로 표시
  Future<void> markAsRead(String notificationId) async {
    if (notificationId.isEmpty) {
      throw ArgumentError('알림 ID가 비어있습니다.');
    }
    await _notificationRepository.markAsRead(notificationId);
  }

  /// 사용자의 모든 알림을 읽음으로 표시
  Future<void> markAllAsRead(String userId) async {
    if (userId.isEmpty) {
      throw ArgumentError('사용자 ID가 비어있습니다.');
    }
    await _notificationRepository.markAllAsRead(userId);
  }

  /// 특정 알림 삭제
  Future<void> deleteNotification(String notificationId) async {
    if (notificationId.isEmpty) {
      throw ArgumentError('알림 ID가 비어있습니다.');
    }
    await _notificationRepository.deleteNotification(notificationId);
  }

  /// 오래된 알림 정리 (7일 이전 알림 삭제)
  Future<void> cleanupOldNotifications(String userId) async {
    if (userId.isEmpty) {
      throw ArgumentError('사용자 ID가 비어있습니다.');
    }

    try {
      await _notificationRepository.deleteOldNotifications(
        userId,
        daysToKeep: 7,
      );
    } catch (e) {
      debugPrint('❌ 오래된 알림 정리 실패 - 사용자: $userId, 오류: $e');
    }
  }

  /// 전체 알림 시스템의 자동 정리 (모든 사용자 대상)
  Future<void> performSystemCleanup() async {
    try {
      await _notificationRepository.cleanupAllOldNotifications(daysToKeep: 7);
    } catch (e) {
      debugPrint('❌ 시스템 전체 알림 정리 실패: $e');
    }
  }

  /// 사용자 시작시 자동 알림 정리
  Future<void> performUserCleanupOnStart(String userId) async {
    if (userId.isEmpty) return;

    try {
      await cleanupOldNotifications(userId);
    } catch (e) {
      debugPrint('❌ 사용자 시작시 알림 정리 실패 - 사용자: $userId, 오류: $e');
    }
  }

  // ==================== 개발/디버깅용 메서드들 ====================

  /// 개발용: 사용자의 모든 알림 삭제
  Future<void> deleteAllUserNotifications(String userId) async {
    if (userId.isEmpty) {
      throw ArgumentError('사용자 ID가 비어있습니다.');
    }
    await _notificationRepository.deleteAllUserNotifications(userId);
  }

  /// 개발용: 알림 통계 정보
  Future<Map<String, int>> getNotificationStats(String userId) async {
    if (userId.isEmpty) return {};
    return await _notificationRepository.getNotificationStats(userId);
  }

  // ==================== 카테고리 업데이트 관련 ====================

  /// 카테고리 대표사진 변경시 관련 알림들의 썸네일 업데이트
  Future<void> updateCategoryThumbnailInNotifications({
    required String categoryId,
    required String newThumbnailUrl,
  }) async {
    try {
      await _notificationRepository.updateCategoryThumbnailInNotifications(
        categoryId: categoryId,
        newThumbnailUrl: newThumbnailUrl,
      );
    } catch (e) {
      debugPrint('❌ 카테고리 알림 썸네일 업데이트 실패: $e');
      rethrow;
    }
  }

  // ==================== 내부 헬퍼 메서드들 ====================

  Future<AuthResult> acceptCategoryInvite({
    required NotificationModel notification,
    required String userId,
  }) async {
    try {
      final inviteId = notification.categoryInviteId;
      if (inviteId == null || inviteId.isEmpty) {
        return AuthResult.failure('초대 정보를 찾을 수 없습니다.');
      }

      final result = await categoryService.acceptPendingInvite(
        inviteId: inviteId,
        userId: userId,
      );

      if (result.isSuccess) {
        await _notificationRepository.updateNotification(notification.id, {
          'isRead': true,
          'requiresAcceptance': false,
          'pendingCategoryMemberIds': [],
        });
      }
      return result;
    } catch (e) {
      debugPrint('❌ 카테고리 초대 수락 실패: $e');
      return AuthResult.failure('초대 수락 중 오류가 발생했습니다.');
    }
  }

  Future<AuthResult> declineCategoryInvite({
    required NotificationModel notification,
    required String userId,
  }) async {
    try {
      final inviteId = notification.categoryInviteId;
      if (inviteId == null || inviteId.isEmpty) {
        return AuthResult.failure('초대 정보를 찾을 수 없습니다.');
      }

      final result = await categoryService.declinePendingInvite(
        inviteId: inviteId,
        userId: userId,
      );

      if (result.isSuccess) {
        await _notificationRepository.deleteNotification(notification.id);
      }
      return result;
    } catch (e) {
      debugPrint('❌ 카테고리 초대 거절 실패: $e');
      return AuthResult.failure('초대 거절 중 오류가 발생했습니다.');
    }
  }

  /// 차단된 사용자의 알림을 필터링하는 메서드
  Future<List<NotificationModel>> _filterNotificationsWithBlockedUsers(
    List<NotificationModel> notifications,
  ) async {
    try {
      // 내가 차단한 사용자 목록만 조회 (단방향 필터링)
      final blockedByMe = await friendService.getBlockedUsers();

      // 차단한 사용자가 없으면 필터링 불필요
      if (blockedByMe.isEmpty) {
        return notifications;
      }

      // 내가 차단한 사용자의 알림만 필터링 (actorUserId 기준)
      return notifications.where((notification) {
        return !blockedByMe.contains(notification.actorUserId);
      }).toList();
    } catch (e) {
      debugPrint('알림 차단 필터링 중 오류 발생: $e');
      return notifications; // 오류 발생 시 원본 반환
    }
  }

  /// 공통 알림 생성 헬퍼 메서드
  Future<void> _createNotification({
    required String recipientUserId,
    required String actorUserId,
    required NotificationType type,
    required String title,
    String? categoryId,
    String? categoryName,
    String? photoId,
    String? commentId,
    String? thumbnailUrl,
    String? categoryThumbnailUrl,
    String? photoThumbnailUrl,
    String? actorName,
    String? actorProfileImage,
    bool requiresAcceptance = false,
    String? categoryInviteId,
    List<String>? pendingCategoryMemberIds,
  }) async {
    try {
      final notification = NotificationModel(
        id: '',
        recipientUserId: recipientUserId,
        actorUserId: actorUserId,
        type: type,
        title: title,
        categoryId: categoryId,
        categoryName: categoryName,
        photoId: photoId,
        commentId: commentId,
        createdAt: DateTime.now(),
        categoryThumbnailUrl: categoryThumbnailUrl,
        photoThumbnailUrl: photoThumbnailUrl,
        actorName: actorName,
        actorProfileImage: actorProfileImage,
        requiresAcceptance: requiresAcceptance,
        categoryInviteId: categoryInviteId,
        pendingCategoryMemberIds: pendingCategoryMemberIds,
      );

      await _notificationRepository.createNotification(notification);
    } catch (e) {
      debugPrint('❌ 알림 생성 실패: $recipientUserId -> $e');
      rethrow;
    }
  }
}
