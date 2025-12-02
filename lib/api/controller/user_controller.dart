import 'package:flutter/material.dart';
import 'package:soi/api/models/user.dart';

/// 사용자 및 인증 컨트롤러 추상 클래스
///
/// 사용자 관련 기능과 인증 기능을 정의하는 인터페이스입니다.
/// 구현체를 교체하여 테스트나 다른 백엔드 사용이 가능합니다.
abstract class UserController extends ChangeNotifier {
  // ============================================
  // 인증 상태
  // ============================================

  /// 현재 로그인된 사용자
  User? get currentUser;

  /// 로그인 상태
  bool get isLoggedIn;

  /// 로딩 상태
  bool get isLoading;

  /// 에러 메시지
  String? get errorMessage;

  // ============================================
  // SMS 인증
  // ============================================

  /// 전화번호로 SMS 인증 요청
  ///
  /// [phoneNumber]: 인증할 전화번호
  /// Returns: 인증 요청 성공 여부
  ///   true: 요청 성공
  ///   false: 요청 실패
  Future<bool> requestSmsVerification(String phoneNumber);

  /// SMS 인증 코드 확인
  ///
  /// [phoneNumber]: 전화번호
  /// [code]: 인증 코드
  /// Returns: 인증 성공 여부
  ///  true: 인증 성공
  ///  false: 인증 실패
  Future<bool> verifySmsCode(String phoneNumber, String code);

  // ============================================
  // 로그인/로그아웃
  // ============================================

  /// 로그인 (전화번호 기반)
  ///
  /// [phoneNumber]: 전화번호
  /// Returns: 로그인된 사용자 정보
  ///   - User: 로그인 성공
  ///     userId: 사용자가 설정한 id
  ///     name: 사용자 이름
  ///     phoneNumber: 전화번호
  ///     profileImageUrl: 프로필 이미지 URL (없을 수 있음)
  ///     birthDate: 생년월일 (없을 수 있음)
  ///   - null: 로그인 실패
  Future<User?> login(String phoneNumber);

  /// 로그아웃
  Future<void> logout();

  /// 현재 사용자 정보 갱신
  Future<void> refreshCurrentUser();

  // ============================================
  // 사용자 생성
  // ============================================

  /// 새 사용자 생성 (회원가입)
  ///
  /// Parameters:
  /// - [name]: 사용자 이름
  /// - [userId]: 사용자 아이디 (고유)
  /// - [phoneNum]: 전화번호
  /// - [birthDate]: 생년월일 (yyyy-MM-dd 형식)
  /// - [profileImageKey]: 프로필 이미지 키 (선택)
  /// - [serviceAgreed]: 서비스 약관 동의 여부
  /// - [privacyPolicyAgreed]: 개인정보 처리방침 동의 여부
  /// - [marketingAgreed]: 마케팅 수신 동의 여부 (선택)
  ///
  /// Returns: 생성된 사용자 정보 (User)
  Future<User?> createUser({
    required String name,
    required String userId,
    required String phoneNum,
    required String birthDate,
    String? profileImageKey,
    bool serviceAgreed = true,
    bool privacyPolicyAgreed = true,
    bool marketingAgreed = false,
  });

  // ============================================
  // 사용자 조회
  // ============================================

  /// ID로 사용자 조회
  ///
  /// Returns: 사용자 정보 (User)
  Future<User?> getUser(int id);

  /// 모든 사용자 조회
  ///
  /// Returns: 사용자 목록 (List<User>)
  Future<List<User>> getAllUsers();

  /// 키워드로 사용자 검색
  ///
  /// Returns: 검색된 사용자 목록 (List<User>)
  Future<List<User>> findUsersByKeyword(String keyword);

  // ============================================
  // 사용자 ID 중복 확인
  // ============================================

  /// 사용자 ID 중복 확인
  ///
  /// Returns:
  /// - true: 사용 가능
  /// - false: 이미 사용 중 (중복)
  Future<bool> checkUserIdAvailable(String userId);

  // ============================================
  // 사용자 정보 수정
  // ============================================

  /// 사용자 정보 수정
  ///
  /// Returns: 수정된 사용자 정보 (User)
  Future<User?> updateUser({
    required int id,
    String? name,
    String? userId,
    String? phoneNum,
    String? birthDate,
    String? profileImageKey,
  });

  /// 프로필 이미지 수정
  ///
  /// Returns: 수정된 사용자 정보 (User)
  Future<User?> updateprofileImageUrl({
    required int userId,
    required String profileImageKey,
  });

  // ============================================
  // 사용자 삭제
  // ============================================

  /// 사용자 삭제 (회원탈퇴)
  ///
  /// Returns: 삭제된 사용자 정보 (User)
  Future<User?> deleteUser(int id);

  // ============================================
  // 로그인 상태 저장/복원 (자동 로그인)
  // ============================================

  /// 로그인 상태를 SharedPreferences에 저장
  ///
  /// Parameters:
  /// - [userId]: 사용자 ID (int)
  /// - [phoneNumber]: 전화번호
  Future<void> saveLoginState({
    required int userId,
    required String phoneNumber,
  });

  /// 온보딩 완료 상태를 저장합니다.
  Future<void> setOnboardingCompleted(bool completed);

  /// 온보딩 완료 여부를 확인합니다.
  Future<bool> isOnboardingCompleted();

  /// 저장된 로그인 상태 확인
  ///
  /// Returns: 로그인 상태 여부
  Future<bool> isLoggedInPersisted();

  /// 저장된 사용자 정보 가져오기
  ///
  /// Returns: {userId, phoneNumber} 또는 null
  Future<Map<String, dynamic>?> getSavedUserInfo();

  /// 자동 로그인 시도
  ///
  /// 저장된 사용자 정보로 자동 로그인을 시도합니다.
  /// Returns: 성공 여부
  Future<bool> tryAutoLogin();

  /// 로그인 상태 삭제 (로그아웃 시 호출)
  Future<void> clearLoginState();

  // ============================================
  // 에러 처리
  // ============================================

  /// 에러 초기화
  void clearError();
}
