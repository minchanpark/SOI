/// 친구 관계 상태
enum FriendshipRelation {
  friends, // 정상 친구 관계
  blockedByMe, // 내가 상대를 차단
  blockedByOther, // 상대가 나를 차단
  notFriends, // 친구 관계 없음 (삭제되었거나 원래 친구 아님)
  unknown, // 확인 불가
}

extension FriendshipRelationExtension on FriendshipRelation {
  String get displayText {
    switch (this) {
      case FriendshipRelation.friends:
        return '친구';
      case FriendshipRelation.blockedByMe:
        return '차단함';
      case FriendshipRelation.blockedByOther:
        return '차단됨';
      case FriendshipRelation.notFriends:
        return '친구 아님';
      case FriendshipRelation.unknown:
        return '확인 중';
    }
  }

  bool get canAddToCategory {
    return this == FriendshipRelation.friends;
  }

  String get blockingMessage {
    switch (this) {
      case FriendshipRelation.blockedByMe:
        return '차단된 친구는 카테고리에 추가할 수 없습니다.';
      case FriendshipRelation.blockedByOther:
        return '이 사용자가 회원님을 차단하여 카테고리에 추가할 수 없습니다.';
      case FriendshipRelation.notFriends:
        return '삭제된 친구는 카테고리에 추가할 수 없습니다.';
      case FriendshipRelation.unknown:
        return '친구 관계 확인 중 오류가 발생했습니다.';
      case FriendshipRelation.friends:
        return ''; // 추가 가능한 상태
    }
  }
}
