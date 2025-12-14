import 'package:soi_api_client/api.dart';

/// 알림 모델
///
/// API의 NotificationRespDto를 앱 내부에서 사용하기 위한 모델입니다.
class AppNotification {
  /// 알림 ID
  final int? id;

  /// 알림 텍스트
  final String? text;

  /// 관련 사용자 이름 (표시용)
  final String? name;

  /// 관련 사용자 닉네임/아이디 (표시용)
  final String? nickname;

  /// 관련 사용자 프로필 이미지 Key(또는 URL)
  final String? userProfileKey;

  /// 기존 UI 호환용 별칭 (userProfileKey와 동일)
  String? get userProfile => userProfileKey;

  /// 관련 이미지 URL
  final String? imageUrl;

  /// 알림 타입
  final NotificationRespDtoTypeEnum? type;

  /// 읽음 여부
  final bool? isRead;

  /// 게시물 알림의 경우, 게시물이 속한 카테고리 ID
  final int? categoryIdForPost;

  /// 관련 ID (예: 친구 요청 ID, 게시물 ID 등)
  /// 친구 관련 알림일 경우 --> 친구 요청 ID
  /// 게시물 관련 알림일 경우 --> Post ID
  /// 댓글 관련 알림일 경우 --> Comment ID
  ///   - TODO: 댓글 관련 알림일 경우에도 Post ID를 리턴하도록 API 수정 필요(서버에 요청하였음)
  final int? relatedId;

  const AppNotification({
    this.id,
    this.text,
    this.name,
    this.nickname,
    this.userProfileKey,
    this.imageUrl,
    this.type,
    this.isRead,
    this.categoryIdForPost,
    this.relatedId,
  });

  /// NotificationRespDto에서 AppNotification 모델 생성
  factory AppNotification.fromDto(NotificationRespDto dto) {
    return AppNotification(
      id: dto.id,
      text: dto.text,
      name: dto.name,
      nickname: dto.nickname,
      userProfileKey: dto.userProfileKey,
      imageUrl: dto.imageUrl,
      type: dto.type,
      isRead: dto.isRead,
      categoryIdForPost: dto.categoryIdForPost,
      relatedId: dto.relatedId,
    );
  }

  /// JSON에서 AppNotification 모델 생성
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final dynamic typeValue = json['type'];
    return AppNotification(
      id: json['id'] as int?,
      text: json['text'] as String?,
      name: json['name'] as String?,
      nickname: json['nickname'] as String?,
      userProfileKey:
          (json['userProfileKey'] as String?) ??
          (json['userProfile'] as String?),
      imageUrl: json['imageUrl'] as String?,
      type: typeValue is String
          ? NotificationRespDtoTypeEnum.fromJson(typeValue)
          : null,
      isRead: json['isRead'] as bool?,
      categoryIdForPost: json['categoryIdForPost'] as int?,
      relatedId: json['relatedId'] as int?,
    );
  }

  /// AppNotification 모델을 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'name': name,
      'nickname': nickname,
      'userProfileKey': userProfileKey,
      'imageUrl': imageUrl,
      'type': type?.toJson(),
      'isRead': isRead,
      'categoryIdForPost': categoryIdForPost,
      'relatedId': relatedId,
    };
  }

  /// 텍스트 유무 확인
  bool get hasText => text != null && text!.isNotEmpty;

  /// 이미지 유무 확인
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  /// 사용자 프로필 유무 확인
  bool get hasUserProfile =>
      userProfileKey != null && userProfileKey!.isNotEmpty;

  /// copyWith 메서드
  AppNotification copyWith({
    int? id,
    String? text,
    String? name,
    String? nickname,
    String? userProfileKey,
    String? imageUrl,
    NotificationRespDtoTypeEnum? type,
    bool? isRead,
    int? categoryIdForPost,
    int? relatedId,
  }) {
    return AppNotification(
      id: id ?? this.id,
      text: text ?? this.text,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      userProfileKey: userProfileKey ?? this.userProfileKey,
      imageUrl: imageUrl ?? this.imageUrl,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      categoryIdForPost: categoryIdForPost ?? this.categoryIdForPost,
      relatedId: relatedId ?? this.relatedId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          text == other.text &&
          relatedId == other.relatedId &&
          type == other.type;

  @override
  int get hashCode =>
      (id?.hashCode ?? 0) ^
      (text?.hashCode ?? 0) ^
      (relatedId?.hashCode ?? 0) ^
      (type?.hashCode ?? 0);

  @override
  String toString() {
    return 'AppNotification{id: $id, type: $type, relatedId: $relatedId, text: $text}';
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
