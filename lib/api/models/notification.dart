import 'package:soi_api_client/api.dart';

/// 알림 모델
///
/// API의 NotificationRespDto를 앱 내부에서 사용하기 위한 모델입니다.
class AppNotification {
  /// 알림 텍스트
  final String? text;

  /// 관련 사용자 프로필 이미지 URL
  final String? userProfile;

  /// 관련 이미지 URL
  final String? imageUrl;

  /// 관련 ID (친구 요청 ID, 게시물 ID 등)
  final int? relatedId;

  const AppNotification({
    this.text,
    this.userProfile,
    this.imageUrl,
    this.relatedId,
  });

  /// NotificationRespDto에서 AppNotification 모델 생성
  factory AppNotification.fromDto(NotificationRespDto dto) {
    return AppNotification(
      text: dto.text,
      userProfile: dto.userProfile,
      imageUrl: dto.imageUrl,
      relatedId: dto.relatedId,
    );
  }

  /// JSON에서 AppNotification 모델 생성
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      text: json['text'] as String?,
      userProfile: json['userProfile'] as String?,
      imageUrl: json['imageUrl'] as String?,
      relatedId: json['relatedId'] as int?,
    );
  }

  /// AppNotification 모델을 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'userProfile': userProfile,
      'imageUrl': imageUrl,
      'relatedId': relatedId,
    };
  }

  /// 텍스트 유무 확인
  bool get hasText => text != null && text!.isNotEmpty;

  /// 이미지 유무 확인
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  /// 사용자 프로필 유무 확인
  bool get hasUserProfile => userProfile != null && userProfile!.isNotEmpty;

  /// copyWith 메서드
  AppNotification copyWith({
    String? text,
    String? userProfile,
    String? imageUrl,
    int? relatedId,
  }) {
    return AppNotification(
      text: text ?? this.text,
      userProfile: userProfile ?? this.userProfile,
      imageUrl: imageUrl ?? this.imageUrl,
      relatedId: relatedId ?? this.relatedId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          relatedId == other.relatedId;

  @override
  int get hashCode => (text?.hashCode ?? 0) ^ (relatedId?.hashCode ?? 0);

  @override
  String toString() {
    return 'AppNotification{text: $text, relatedId: $relatedId}';
  }
}

/// 전체 알림 응답 모델
///
/// API의 NotificationGetAllRespDto를 앱 내부에서 사용하기 위한 모델입니다.
class NotificationGetAllResult {
  /// 친구 요청 개수
  final int friendRequestCount;

  /// 알림 목록
  final List<AppNotification> notifications;

  const NotificationGetAllResult({
    this.friendRequestCount = 0,
    this.notifications = const [],
  });

  /// NotificationGetAllRespDto에서 NotificationGetAllResult 모델 생성
  factory NotificationGetAllResult.fromDto(NotificationGetAllRespDto dto) {
    return NotificationGetAllResult(
      friendRequestCount: dto.friendReqCount ?? 0,
      notifications: dto.notifications
          .map((n) => AppNotification.fromDto(n))
          .toList(),
    );
  }

  /// JSON에서 NotificationGetAllResult 모델 생성
  factory NotificationGetAllResult.fromJson(Map<String, dynamic> json) {
    return NotificationGetAllResult(
      friendRequestCount: json['friendReqCount'] as int? ?? 0,
      notifications:
          (json['notifications'] as List<dynamic>?)
              ?.map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// NotificationGetAllResult 모델을 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'friendReqCount': friendRequestCount,
      'notifications': notifications.map((n) => n.toJson()).toList(),
    };
  }

  /// 알림이 있는지 확인
  bool get hasNotifications => notifications.isNotEmpty;

  /// 친구 요청이 있는지 확인
  bool get hasFriendRequests => friendRequestCount > 0;

  /// 전체 알림 개수
  int get totalCount => notifications.length;

  /// copyWith 메서드
  NotificationGetAllResult copyWith({
    int? friendRequestCount,
    List<AppNotification>? notifications,
  }) {
    return NotificationGetAllResult(
      friendRequestCount: friendRequestCount ?? this.friendRequestCount,
      notifications: notifications ?? this.notifications,
    );
  }

  @override
  String toString() {
    return 'NotificationGetAllResult{friendRequestCount: $friendRequestCount, notificationCount: ${notifications.length}}';
  }
}
