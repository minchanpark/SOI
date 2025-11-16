import 'package:cloud_firestore/cloud_firestore.dart';

/// 사용자 검색 결과 데이터 모델
class UserSearchModel {
  /// Firebase Auth에 등록된 고유 UID (백엔드 식별자)
  final String uid;

  /// SOI 내부에서 노출되는 사용자 ID(닉네임 역할, 검색/표시용)
  final String id;

  /// 가입 시 입력한 실명 (프로필 상세 등에서 사용)
  final String name;

  /// 프로필 이미지의 공개 URL (없으면 기본 아바타 적용)
  final String? profileImageUrl;

  /// 연락처 기반 친구추천을 위한 전화번호 해시 값(원본 번호는 저장하지 않음)
  final String? phoneNumber;

  /// 전화번호로 자신을 검색하도록 허용하는지 여부
  final bool allowPhoneSearch;

  /// 계정이 생성된 시각 (최신 순 정렬/필터링에 활용)
  final DateTime createdAt;

  const UserSearchModel({
    required this.uid,
    required this.id,
    required this.name,
    this.profileImageUrl,
    this.phoneNumber,
    required this.allowPhoneSearch,
    required this.createdAt,
  });

  /// Firestore 문서에서 모델 생성
  factory UserSearchModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw Exception('Document data is null');
    }

    return UserSearchModel.fromJson(data, doc.id);
  }

  /// JSON에서 모델 생성
  factory UserSearchModel.fromJson(Map<String, dynamic> json, String uid) {
    return UserSearchModel(
      uid: uid,
      id:
          json['id'] as String? ??
          json['name'] as String? ??
          '', // id이 없으면 name 사용
      name: json['name'] as String? ?? '',
      profileImageUrl:
          json['profileImageUrl'] as String? ??
          json['profile_image'] as String?, // profile_image 필드도 확인
      phoneNumber: json['phone'] as String?, // 'phoneNumber' → 'phone'으로 변경
      allowPhoneSearch: json['allowPhoneSearch'] as bool? ?? true,
      createdAt:
          json['createdAt'] != null
              ? (json['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  /// 동등성 비교
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserSearchModel &&
        other.uid == uid &&
        other.id == id &&
        other.name == name &&
        other.profileImageUrl == profileImageUrl &&
        other.phoneNumber == phoneNumber &&
        other.allowPhoneSearch == allowPhoneSearch &&
        other.createdAt == createdAt;
  }

  /// 해시코드
  @override
  int get hashCode {
    return uid.hashCode ^
        id.hashCode ^
        name.hashCode ^
        profileImageUrl.hashCode ^
        phoneNumber.hashCode ^
        allowPhoneSearch.hashCode ^
        createdAt.hashCode;
  }
}
