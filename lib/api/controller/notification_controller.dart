import 'package:flutter/material.dart';

import '../models/notification.dart';

/// 알림 컨트롤러 추상 클래스
///
/// 알림 관련 기능을 정의하는 인터페이스입니다.
/// 구현체를 교체하여 테스트나 다른 백엔드 사용이 가능합니다.
///
/// 사용 예시:
/// ```dart
/// final notificationController = Provider.of<NotificationController>(context, listen: false);
///
/// // 모든 알림 조회
/// final result = await notificationController.getAllNotifications(userId: 1);
///
/// // 친구 관련 알림 조회
/// final friendNotifications = await notificationController.getFriendNotifications(userId: 1);
/// ```
abstract class NotificationController extends ChangeNotifier {
  /// 로딩 상태
  bool get isLoading;

  /// 에러 메시지
  String? get errorMessage;

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
  Future<NotificationGetAllResult> getAllNotifications({required int userId});

  /// 친구 관련 알림 조회
  ///
  /// [userId]의 친구 요청 관련 알림만 조회합니다.
  ///
  /// Parameters:
  /// - [userId]: 사용자 ID
  ///
  /// Returns: 친구 관련 알림 목록 (List<AppNotification>)
  Future<List<AppNotification>> getFriendNotifications({required int userId});

  /// 친구 요청 개수 조회 (편의 메서드)
  ///
  /// Returns: 친구 요청 개수
  Future<int> getFriendRequestCount({required int userId});

  /// 알림 개수 조회 (편의 메서드)
  ///
  /// Returns: 전체 알림 개수
  Future<int> getNotificationCount({required int userId});

  // ============================================
  // 에러 처리
  // ============================================

  /// 에러 초기화
  void clearError();
}
