import 'package:cloud_firestore/cloud_firestore.dart';

/// 알림 유형 열거형
enum NotificationType {
  categoryInvite, // 카테고리 초대
  photoAdded, // 사진 추가
  voiceCommentAdded, // 음성 댓글 추가
  friendRequest, // 친구 요청
}

/// 알림 데이터 모델
class NotificationModel {
  final String id;
  final String recipientUserId; // 알림을 받을 사용자
  final String actorUserId; // 행동을 수행한 사용자
  final NotificationType type; // 알림 유형
  final String title; // 알림 제목

  // 카테고리 초대 관련
  final String? categoryId; // 내가 초대된 카테고리의 ID
  final String? categoryName; // 내가 초대된 카테고리의 이름
  final String? categoryThumbnailUrl; // 내가 초대된 카테고리의 대표 사진 URL
  final bool requiresAcceptance; // 수락 대기 여부
  final String? categoryInviteId; // categoryInvites 문서 ID
  final List<String>? pendingCategoryMemberIds; // 친구가 아닌 기존 멤버 IDs

  // 사진 관련
  final String? photoId; // 내가 속하여져 있는 카테고리에 올라온 사진의 ID
  final String? photoThumbnailUrl; // 내가 속하여져 있는 카테고리에 올라온 사진의 썸네일 URL

  // 댓글 관련
  final String? commentId; // 내가 속하여져 있는 카테고리에 올라온 사진의 댓글 ID --> 사용x

  // 기타
  final DateTime createdAt; // 생성 일시
  final bool isRead; // 알림 읽음 여부 --> 사용x
  final String? actorName; // 알림을 보낸 주체의 이름
  final String? actorProfileImage; // 알림을 보낸 주체의 프로필 이미지 URL

  NotificationModel({
    required this.id,
    required this.recipientUserId,
    required this.actorUserId,
    required this.type,
    required this.title,
    this.categoryId,
    this.categoryName,
    this.categoryThumbnailUrl,
    this.requiresAcceptance = false,
    this.categoryInviteId,
    this.pendingCategoryMemberIds,
    this.photoId,
    this.photoThumbnailUrl,
    this.commentId,
    required this.createdAt,
    this.isRead = false,
    this.actorName,
    this.actorProfileImage,
  });

  /// Firestore 문서에서 NotificationModel 생성
  factory NotificationModel.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    return NotificationModel(
      id: id,
      recipientUserId: data['recipientUserId'] ?? '',
      actorUserId: data['actorUserId'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => NotificationType.categoryInvite,
      ),
      title: data['title'] ?? '',
      categoryId: data['categoryId'],
      categoryName: data['categoryName'],
      categoryThumbnailUrl: data['categoryThumbnailUrl'],
      requiresAcceptance: data['requiresAcceptance'] ?? false,
      categoryInviteId: data['categoryInviteId'],
      pendingCategoryMemberIds:
          data['pendingCategoryMemberIds'] != null
              ? List<String>.from(data['pendingCategoryMemberIds'] as List)
              : null,
      photoId: data['photoId'],
      commentId: data['commentId'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      actorName: data['actorName'],
      actorProfileImage: data['actorProfileImage'],
    );
  }

  /// Firestore에 저장할 Map 변환
  Map<String, dynamic> toFirestore() {
    return {
      'recipientUserId': recipientUserId,
      'actorUserId': actorUserId,
      'type': type.name,
      'title': title,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'categoryThumbnailUrl': categoryThumbnailUrl,
      'requiresAcceptance': requiresAcceptance,
      'categoryInviteId': categoryInviteId,
      'pendingCategoryMemberIds': pendingCategoryMemberIds,
      'photoId': photoId,
      'commentId': commentId,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'actorName': actorName,
      'actorProfileImage': actorProfileImage,
    };
  }

  /// 서버 타임스탬프를 사용하여 Firestore에 저장할 Map 변환
  Map<String, dynamic> toFirestoreWithServerTimestamp() {
    final data = toFirestore();
    data['createdAt'] = FieldValue.serverTimestamp();
    return data;
  }

  /// 알림 정보 업데이트를 위한 copyWith
  NotificationModel copyWith({
    String? id,
    String? recipientUserId,
    String? actorUserId,
    NotificationType? type,
    String? title,
    String? categoryId,
    String? categoryName,
    String? photoId,
    String? commentId,
    DateTime? createdAt,
    bool? isRead,
    String? thumbnailUrl,
    String? categoryThumbnailUrl,
    String? photoThumbnailUrl,
    String? actorName,
    String? actorProfileImage,
    bool? requiresAcceptance,
    String? categoryInviteId,
    List<String>? pendingCategoryMemberIds,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      recipientUserId: recipientUserId ?? this.recipientUserId,
      actorUserId: actorUserId ?? this.actorUserId,
      type: type ?? this.type,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryThumbnailUrl: categoryThumbnailUrl ?? this.categoryThumbnailUrl,
      requiresAcceptance: requiresAcceptance ?? this.requiresAcceptance,
      categoryInviteId: categoryInviteId ?? this.categoryInviteId,
      pendingCategoryMemberIds:
          pendingCategoryMemberIds ?? this.pendingCategoryMemberIds,
      photoId: photoId ?? this.photoId,
      commentId: commentId ?? this.commentId,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      actorName: actorName ?? this.actorName,
      actorProfileImage: actorProfileImage ?? this.actorProfileImage,
    );
  }

  /// 카테고리 초대 수락이 필요한 알림인지 여부
  bool get isCategoryInvitePending => requiresAcceptance && !isRead;

  /// 알림 타입별 아이콘 이름 반환
  String get typeIconName {
    switch (type) {
      case NotificationType.categoryInvite:
        return 'person_add';
      case NotificationType.photoAdded:
        return 'photo_camera';
      case NotificationType.voiceCommentAdded:
        return 'mic';
      case NotificationType.friendRequest:
        return 'person_add_alt';
    }
  }

  @override
  String toString() {
    return 'NotificationModel{id: $id, type: $type, title: $title, isRead: $isRead}';
  }
}
