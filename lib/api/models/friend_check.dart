import 'package:soi_api_client/api.dart';

import 'friend.dart';

/// 친구 관계 확인 결과 모델
///
/// API의 FriendCheckRespDto를 앱 내부에서 사용하기 위한 모델입니다.
/// 전화번호 기반 친구 관계 확인 결과를 나타냅니다.
class FriendCheck {
  /// 확인 대상 전화번호
  final String phoneNumber;

  /// 친구 여부
  final bool isFriend;

  /// 친구 관계 상태
  final FriendStatus status;

  const FriendCheck({
    required this.phoneNumber,
    required this.isFriend,
    required this.status,
  });

  /// FriendCheckRespDto에서 FriendCheck 모델 생성
  factory FriendCheck.fromDto(FriendCheckRespDto dto) {
    return FriendCheck(
      phoneNumber: dto.phoneNum ?? '',
      isFriend: dto.isFriend ?? false,
      status: _statusFromDto(dto.status),
    );
  }

  /// DTO 상태를 FriendStatus로 변환
  static FriendStatus _statusFromDto(FriendCheckRespDtoStatusEnum? status) {
    switch (status) {
      case FriendCheckRespDtoStatusEnum.PENDING:
        return FriendStatus.pending;
      case FriendCheckRespDtoStatusEnum.ACCEPTED:
        return FriendStatus.accepted;
      case FriendCheckRespDtoStatusEnum.BLOCKED:
        return FriendStatus.blocked;
      case FriendCheckRespDtoStatusEnum.CANCELLED:
        return FriendStatus.cancelled;
      default:
        return FriendStatus.none;
    }
  }

  /// 상태 문자열 반환 (UI용)
  String get statusString {
    if (status == FriendStatus.pending) {
      return 'pending';
    }
    if (status == FriendStatus.blocked) {
      return 'blocked';
    }
    if (status == FriendStatus.accepted || isFriend) {
      return 'accepted';
    }
    return 'none';
  }

  @override
  String toString() {
    return 'FriendCheck{phoneNumber: $phoneNumber, isFriend: $isFriend, status: $status}';
  }
}
