import 'package:soi_api_client/api.dart';

/// 사용자 모델
///
/// API의 UserRespDto를 앱 내부에서 사용하기 위한 모델입니다.
/// null 처리와 비즈니스 로직을 이 모델에서 관리합니다.
class User {
  // 고유 ID
  final int id;

  // 사용자가 설정한 ID
  final String userId;

  // 사용자 이름
  final String name;

  // 프로필 이미지 URL
  final String? profileImageUrlKey;

  // 생년월일 (YYYY-MM-DD 형식)
  final String? birthDate;

  // 전화번호
  final String phoneNumber;

  // 활성화 상태 (친구 찾기 등에서 사용)
  final bool active;

  const User({
    required this.id,
    required this.userId,
    required this.name,
    this.profileImageUrlKey,
    this.birthDate,
    required this.phoneNumber,
    this.active = false,
  });

  /// UserRespDto에서 User 모델 생성
  factory User.fromDto(UserRespDto dto) {
    return User(
      id: dto.id ?? 0,
      userId: dto.nickname ?? '',
      name: dto.name ?? '',
      profileImageUrlKey: dto.profileImageKey,
      birthDate: dto.birthDate,
      phoneNumber: dto.phoneNum ?? '',
    );
  }

  /// UserFindRespDto에서 User 모델 생성
  ///
  /// 친구 목록, 검색 결과 등에서 사용됩니다.
  /// UserFindRespDto에는 birthDate, phoneNum이 없으므로 빈 값으로 처리됩니다.
  factory User.fromFindDto(UserFindRespDto dto) {
    return User(
      id: dto.id ?? 0,
      userId: dto.nickname ?? '',
      name: dto.name ?? '',
      profileImageUrlKey: dto.profileImageKey,
      birthDate: null,
      phoneNumber: '',
      active: dto.active ?? false,
    );
  }

  /// JSON에서 User 모델 생성
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int? ?? 0,
      userId: json['userId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      profileImageUrlKey: json['profileImageUrl'] as String?,
      birthDate: json['birthDate'] as String?,
      phoneNumber: json['phoneNum'] as String? ?? '',
    );
  }

  /// User 모델을 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'profileImageUrl': profileImageUrlKey,
      'birthDate': birthDate,
      'phoneNum': phoneNumber,
    };
  }

  /// 프로필 이미지 유무 확인
  bool get hasProfileImageUrl =>
      profileImageUrlKey != null && profileImageUrlKey!.isNotEmpty;

  /// copyWith 메서드
  User copyWith({
    int? id,
    String? userId,
    String? name,
    String? profileImageUrl,
    String? birthDate,
    String? phoneNumber,
  }) {
    return User(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      profileImageUrlKey: profileImageUrlKey,
      birthDate: birthDate ?? this.birthDate,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId;

  @override
  int get hashCode => id.hashCode ^ userId.hashCode;

  @override
  String toString() {
    return 'User{id: $id, userId: $userId, name: $name, phoneNumber: $phoneNumber}';
  }
}
