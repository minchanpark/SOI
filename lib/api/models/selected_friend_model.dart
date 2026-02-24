/// 선택된 친구 정보를 전달하기 위한 모델
class SelectedFriendModel {
  /// Firebase Auth 기준 친구의 UID (카테고리 멤버 추가 등 식별용)
  final String uid;

  /// 화면에 노출할 친구 이름 또는 닉네임 문자열
  final String name;

  /// 프로필 썸네일을 표시하기 위한 이미지 URL (없으면 기본 아바타 사용)
  final String? profileImageUrl;

  const SelectedFriendModel({
    required this.uid,
    required this.name,
    this.profileImageUrl,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SelectedFriendModel &&
        other.uid == uid &&
        other.name == name &&
        other.profileImageUrl == profileImageUrl;
  }

  @override
  int get hashCode => uid.hashCode ^ name.hashCode ^ profileImageUrl.hashCode;
}
