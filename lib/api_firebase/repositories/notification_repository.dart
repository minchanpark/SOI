import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';

/// 알림 데이터 접근 레이어 (Repository)
/// Firestore와의 모든 알림 관련 데이터 작업을 처리
class NotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'notifications';

  // ==================== 기본 CRUD 메서드들 ====================

  /// 새 알림 생성
  Future<String> createNotification(NotificationModel notification) async {
    try {
      final docRef = await _firestore
          .collection(_collectionPath)
          .add(notification.toFirestoreWithServerTimestamp());
      return docRef.id;
    } catch (e) {
      debugPrint('❌ 알림 생성 실패: $e');
      rethrow;
    }
  }

  /// 특정 알림 조회
  Future<NotificationModel?> getNotification(String notificationId) async {
    try {
      final doc =
          await _firestore
              .collection(_collectionPath)
              .doc(notificationId)
              .get();

      if (!doc.exists) return null;
      return NotificationModel.fromFirestore(doc.data()!, doc.id);
    } catch (e) {
      debugPrint('❌ 알림 조회 실패 - ID: $notificationId, 오류: $e');
      rethrow;
    }
  }

  /// 사용자의 알림 목록 조회 (페이징 지원)
  Future<List<NotificationModel>> getUserNotifications(
    String userId, {
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _firestore
          .collection(_collectionPath)
          .where('recipientUserId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map(
            (doc) => NotificationModel.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('❌ 사용자 알림 조회 실패 - 사용자: $userId, 오류: $e');
      rethrow;
    }
  }

  /// 알림 정보 업데이트
  Future<void> updateNotification(
    String notificationId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore
          .collection(_collectionPath)
          .doc(notificationId)
          .update(updates);
    } catch (e) {
      debugPrint('❌ 알림 업데이트 실패 - ID: $notificationId, 오류: $e');
      rethrow;
    }
  }

  /// 알림 삭제
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection(_collectionPath).doc(notificationId).delete();
    } catch (e) {
      debugPrint('❌ 알림 삭제 실패 - ID: $notificationId, 오류: $e');
      rethrow;
    }
  }

  // ==================== 실시간 스트림 메서드들 ====================

  /// 사용자의 알림 목록 실시간 스트림
  Stream<List<NotificationModel>> getUserNotificationsStream(
    String userId, {
    int limit = 50,
  }) {
    try {
      return _firestore
          .collection(_collectionPath)
          .where('recipientUserId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs
                    .map(
                      (doc) =>
                          NotificationModel.fromFirestore(doc.data(), doc.id),
                    )
                    .toList(),
          );
    } catch (e) {
      debugPrint('❌ 실시간 알림 스트림 오류 - 사용자: $userId, 오류: $e');
      return Stream.error(e);
    }
  }

  /// 읽지 않은 알림 개수 실시간 스트림
  Stream<int> getUnreadCountStream(String userId) {
    try {
      return _firestore
          .collection(_collectionPath)
          .where('recipientUserId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .map((snapshot) => snapshot.docs.length);
    } catch (e) {
      debugPrint('❌ 읽지 않은 알림 개수 스트림 오류 - 사용자: $userId, 오류: $e');
      return Stream.error(e);
    }
  }

  // ==================== 유틸리티 메서드들 ====================

  /// 특정 알림을 읽음으로 표시
  Future<void> markAsRead(String notificationId) async {
    try {
      await updateNotification(notificationId, {'isRead': true});
    } catch (e) {
      debugPrint('❌ 알림 읽음 처리 실패 - ID: $notificationId, 오류: $e');
      rethrow;
    }
  }

  /// 사용자의 모든 알림을 읽음으로 표시
  Future<void> markAllAsRead(String userId) async {
    try {
      final unreadNotifications =
          await _firestore
              .collection(_collectionPath)
              .where('recipientUserId', isEqualTo: userId)
              .where('isRead', isEqualTo: false)
              .get();

      if (unreadNotifications.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('❌ 모든 알림 읽음 처리 실패 - 사용자: $userId, 오류: $e');
      rethrow;
    }
  }

  /// 읽지 않은 알림 개수 조회 (한 번만)
  Future<int> getUnreadCount(String userId) async {
    try {
      final querySnapshot =
          await _firestore
              .collection(_collectionPath)
              .where('recipientUserId', isEqualTo: userId)
              .where('isRead', isEqualTo: false)
              .get();
      return querySnapshot.docs.length;
    } catch (e) {
      debugPrint('❌ 읽지 않은 알림 개수 조회 실패 - 사용자: $userId, 오류: $e');
      rethrow;
    }
  }

  /// 특정 타입의 알림들 조회
  Future<List<NotificationModel>> getNotificationsByType(
    String userId,
    NotificationType type, {
    int limit = 20,
  }) async {
    try {
      final querySnapshot =
          await _firestore
              .collection(_collectionPath)
              .where('recipientUserId', isEqualTo: userId)
              .where('type', isEqualTo: type.name)
              .orderBy('createdAt', descending: true)
              .limit(limit)
              .get();

      return querySnapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('❌ 타입별 알림 조회 실패 - 사용자: $userId, 타입: ${type.name}, 오류: $e');
      rethrow;
    }
  }

  /// 오래된 알림들 삭제 (데이터 정리용)
  Future<void> deleteOldNotifications(
    String userId, {
    int daysToKeep = 7,
  }) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      final oldNotifications =
          await _firestore
              .collection(_collectionPath)
              .where('recipientUserId', isEqualTo: userId)
              .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
              .get();

      if (oldNotifications.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in oldNotifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('❌ 오래된 알림 삭제 실패 - 사용자: $userId, 오류: $e');
      rethrow;
    }
  }

  /// 모든 사용자의 오래된 알림 일괄 정리 (관리자용)
  Future<void> cleanupAllOldNotifications({int daysToKeep = 7}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      final oldNotifications =
          await _firestore
              .collection(_collectionPath)
              .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
              .get();

      if (oldNotifications.docs.isEmpty) return;

      const int batchSize = 500;
      for (int i = 0; i < oldNotifications.docs.length; i += batchSize) {
        final batch = _firestore.batch();
        final endIndex =
            (i + batchSize < oldNotifications.docs.length)
                ? i + batchSize
                : oldNotifications.docs.length;

        for (int j = i; j < endIndex; j++) {
          batch.delete(oldNotifications.docs[j].reference);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('❌ 전체 오래된 알림 정리 실패: $e');
      rethrow;
    }
  }

  // ==================== 개발/디버깅용 메서드들 ====================

  /// 개발용: 사용자의 모든 알림 삭제
  Future<void> deleteAllUserNotifications(String userId) async {
    try {
      final allNotifications =
          await _firestore
              .collection(_collectionPath)
              .where('recipientUserId', isEqualTo: userId)
              .get();

      if (allNotifications.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in allNotifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('❌ 모든 알림 삭제 실패 - 사용자: $userId, 오류: $e');
      rethrow;
    }
  }

  /// 개발용: 알림 통계 정보
  Future<Map<String, int>> getNotificationStats(String userId) async {
    try {
      final allNotifications =
          await _firestore
              .collection(_collectionPath)
              .where('recipientUserId', isEqualTo: userId)
              .get();

      final stats = <String, int>{
        'total': allNotifications.docs.length,
        'unread': 0,
        'categoryInvite': 0,
        'photoAdded': 0,
        'voiceCommentAdded': 0,
      };

      for (final doc in allNotifications.docs) {
        final data = doc.data();
        if (!(data['isRead'] ?? false)) {
          stats['unread'] = stats['unread']! + 1;
        }

        final type = data['type'] ?? '';
        if (stats.containsKey(type)) {
          stats[type] = stats[type]! + 1;
        }
      }
      return stats;
    } catch (e) {
      debugPrint('❌ 알림 통계 조회 실패 - 사용자: $userId, 오류: $e');
      rethrow;
    }
  }

  // ==================== 카테고리 업데이트 관련 ====================

  /// 카테고리 대표사진 변경시 관련 알림들의 썸네일 업데이트
  Future<void> updateCategoryThumbnailInNotifications({
    required String categoryId,
    required String newThumbnailUrl,
  }) async {
    try {
      final categoryNotifications =
          await _firestore
              .collection(_collectionPath)
              .where('categoryId', isEqualTo: categoryId)
              .where('type', isEqualTo: 'categoryInvite')
              .get();

      if (categoryNotifications.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in categoryNotifications.docs) {
        batch.update(doc.reference, {'categoryThumbnailUrl': newThumbnailUrl});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('❌ 카테고리 알림 썸네일 업데이트 실패 - 카테고리: $categoryId, 오류: $e');
      rethrow;
    }
  }
}
