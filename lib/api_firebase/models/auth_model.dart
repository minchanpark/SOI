import 'package:cloud_firestore/cloud_firestore.dart';

/// 사용자 데이터 모델 (순수 데이터 클래스)
class AuthModel {
  // 고유 사용자 ID (Firebase Auth UID)
  final String uid;

  // 사용자 아이디-회원가입할 떄, 사용자가 입력하는 아이디
  final String id;

  // 사용자 이름-회원가입할 때, 사용자가 입력하는 이름s
  final String name;

  // 사용자 전화번호-회원가입할 때, 사용자가 입력하는 전화번호
  final String phone;

  // 사용자 생년월일-회원가입할 때, 사용자가 입력하는 생년월일
  final String birthDate;

  // 사용자 프로필 이미지 URL
  final String profileImage;

  // 계정 생성 일시
  final DateTime createdAt;

  // 마지막 로그인 일시
  final DateTime lastLogin;

  // 계정 비활성화 상태
  // 기본값은 false (활성화 상태)
  // 이게 비활성화 상태가 되면, 내가 올린 사진이 모두 내려지고, 보관함으로 이동함
  final bool isDeactivated;

  AuthModel({
    required this.uid,
    required this.id,
    required this.name,
    required this.phone,
    required this.birthDate,
    this.profileImage = '',
    required this.createdAt,
    required this.lastLogin,
    this.isDeactivated = false, // 기본값 false
  });

  /// Firestore 문서에서 UserModel 생성
  factory AuthModel.fromFirestore(Map<String, dynamic> data) {
    return AuthModel(
      uid: data['uid'] ?? '',
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      birthDate: data['birth_date'] ?? '',
      profileImage: data['profile_image'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastLogin: (data['lastLogin'] as Timestamp).toDate(),
      isDeactivated: data['isDeactivated'] ?? false, // 비활성화 상태 추가
    );
  }

  /// 서버 타임스탬프를 사용하여 Firestore에 저장할 Map 변환
  Map<String, dynamic> toFirestoreWithServerTimestamp({bool isUpdate = false}) {
    final data = {
      'uid': uid,
      'id': id,
      'name': name,
      'phone': phone,
      'birth_date': birthDate,
      'profile_image': profileImage,
      'lastLogin': FieldValue.serverTimestamp(),
      'isDeactivated': isDeactivated, // 비활성화 상태 추가
    };

    if (!isUpdate) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    return data;
  }
}
