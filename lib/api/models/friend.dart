import 'package:soi_api_client/api.dart';

/// 친구 관계 상태
enum FriendStatus {
  pending,   // 요청 대기 중
  accepted,  // 수락됨
  blocked,   // 차단됨
  cancelled, // 취소됨
}

/// 친구 관계 모델
///
/// API의 FriendRespDto를 앱 내부에서 사용하기 위한 모델입니다.
class Friend {
  final int id;
  final int requesterId;
  final int receiverId;
  final int? notificationId;
  final FriendStatus status;
  final DateTime? createdAt;

  const Friend({
    required this.id,
    required this.requesterId,
    required this.receiverId,
    this.notificationId,
    required this.status,
    this.createdAt,
  });

  /// FriendRespDto에서 Friend 모델 생성
  factory Friend.fromDto(FriendRespDto dto) {
    return Friend(
      id: dto.id ?? 0,
      requesterId: dto.requesterId ?? 0,
      receiverId: dto.receiverId ?? 0,
      notificationId: dto.notificationId,
      status: _statusFromDto(dto.status),
      createdAt: dto.createdAt,
    );
  }

  /// DTO 상태를 FriendStatus로 변환
  static FriendStatus _statusFromDto(FriendRespDtoStatusEnum? status) {
    switch (status) {
      case FriendRespDtoStatusEnum.PENDING:
        return FriendStatus.pending;
      case FriendRespDtoStatusEnum.ACCEPTED:
        return FriendStatus.accepted;
      case FriendRespDtoStatusEnum.BLOCKED:
        return FriendStatus.blocked;
      case FriendRespDtoStatusEnum.CANCELLED:
        return FriendStatus.cancelled;
      default:
        return FriendStatus.pending;
    }
  }

  /// JSON에서 Friend 모델 생성
  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'] as int? ?? 0,
      requesterId: json['requesterId'] as int? ?? 0,
      receiverId: json['receiverId'] as int? ?? 0,
      notificationId: json['notificationId'] as int?,
      status: _statusFromString(json['status'] as String?),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  /// 문자열을 FriendStatus로 변환
  static FriendStatus _statusFromString(String? status) {
    switch (status?.toUpperCase()) {
      case 'PENDING':
        return FriendStatus.pending;
      case 'ACCEPTED':
        return FriendStatus.accepted;
      case 'BLOCKED':
        return FriendStatus.blocked;
      case 'CANCELLED':
        return FriendStatus.cancelled;
      default:
        return FriendStatus.pending;
    }
  }

  /// Friend 모델을 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requesterId': requesterId,
      'receiverId': receiverId,
      'notificationId': notificationId,
      'status': status.name.toUpperCase(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  /// 친구 관계가 활성 상태인지 확인
  bool get isActive => status == FriendStatus.accepted;

  /// 대기 중인 요청인지 확인
  bool get isPending => status == FriendStatus.pending;

  /// 차단된 관계인지 확인
  bool get isBlocked => status == FriendStatus.blocked;

  /// copyWith 메서드
  Friend copyWith({
    int? id,
    int? requesterId,
    int? receiverId,
    int? notificationId,
    FriendStatus? status,
    DateTime? createdAt,
  }) {
    return Friend(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      receiverId: receiverId ?? this.receiverId,
      notificationId: notificationId ?? this.notificationId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Friend && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Friend{id: $id, requesterId: $requesterId, receiverId: $receiverId, status: $status}';
  }
}
