import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/api/models/user.dart';
import 'package:soi/api/services/user_service.dart';

/// REST API 기반 사용자 및 인증 컨트롤러 구현체
///
/// UserService를 사용하여 사용자 및 인증 관련 기능을 구현합니다.
/// UserController를 상속받아 구현합니다.
///   - UserController: 사용자 및 인증 관련 기능 정의
///   - ApiUserController: REST API 기반 구현체
class ApiUserController extends UserController {
  final UserService _userService;

  // SharedPreferences 키 상수
  static const String _keyIsLoggedIn = 'api_is_logged_in';
  static const String _keyUserId = 'api_user_id';
  static const String _keyPhoneNumber = 'api_phone_number';
  static const String _keyOnboardingCompleted = 'api_onboarding_completed';

  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  ApiUserController({UserService? userService})
    : _userService = userService ?? UserService();

  @override
  User? get currentUser => _currentUser;

  @override
  bool get isLoggedIn => _currentUser != null;

  @override
  bool get isLoading => _isLoading;

  @override
  String? get errorMessage => _errorMessage;

  // ============================================
  // SMS 인증
  // ============================================

  @override
  Future<bool> requestSmsVerification(String phoneNumber) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _userService.sendSmsVerification(phoneNumber);
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('SMS 인증 요청 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  @override
  Future<bool> verifySmsCode(String phoneNumber, String code) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _userService.verifySmsCode(phoneNumber, code);
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('인증 코드 확인 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  // ============================================
  // 로그인/로그아웃
  // ============================================

  @override
  Future<User?> login(String phoneNumber) async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _userService.loginWithPhone(phoneNumber);
      _currentUser = user;

      // 로그인 성공 시 상태 저장
      if (user != null) {
        await saveLoginState(userId: user.id, phoneNumber: phoneNumber);
      }

      _setLoading(false);
      notifyListeners();
      return user;
    } catch (e) {
      _setError('로그인 실패: $e');
      _setLoading(false);
      return null;
    }
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
    _clearError();
    await clearLoginState(); // 저장된 로그인 상태도 삭제
    notifyListeners();
  }

  @override
  Future<void> refreshCurrentUser() async {
    if (_currentUser == null) return;

    _setLoading(true);
    try {
      final user = await _userService.getUser(_currentUser!.id);
      _currentUser = user;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('사용자 정보 갱신 실패: $e');
      _setLoading(false);
    }
  }

  /// 현재 사용자 설정 (외부에서 직접 설정 필요 시)
  void setCurrentUser(User? user) {
    _currentUser = user;
    notifyListeners();
  }

  // ============================================
  // 사용자 생성
  // ============================================

  @override
  Future<User?> createUser({
    required String name,
    required String userId,
    required String phoneNum,
    required String birthDate,
    String? profileImage,
    bool serviceAgreed = true,
    bool privacyPolicyAgreed = true,
    bool marketingAgreed = false,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _userService.createUser(
        name: name,
        userId: userId,
        phoneNum: phoneNum,
        birthDate: birthDate,
        profileImage: profileImage,
        serviceAgreed: serviceAgreed,
        privacyPolicyAgreed: privacyPolicyAgreed,
        marketingAgreed: marketingAgreed,
      );
      _setLoading(false);
      return user;
    } catch (e) {
      _setError('사용자 생성 실패: $e');
      _setLoading(false);
      return null;
    }
  }

  // ============================================
  // 사용자 조회
  // ============================================

  @override
  Future<User?> getUser(int id) async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _userService.getUser(id);
      _setLoading(false);
      return user;
    } catch (e) {
      _setError('사용자 조회 실패: $e');
      _setLoading(false);
      return null;
    }
  }

  @override
  Future<List<User>> getAllUsers() async {
    _setLoading(true);
    _clearError();

    try {
      final users = await _userService.getAllUsers();
      _setLoading(false);
      return users;
    } catch (e) {
      _setError('사용자 목록 조회 실패: $e');
      _setLoading(false);
      return [];
    }
  }

  @override
  Future<List<User>> findUsersByKeyword(String keyword) async {
    _setLoading(true);
    _clearError();

    try {
      final users = await _userService.findUsersByKeyword(keyword);
      _setLoading(false);
      return users;
    } catch (e) {
      _setError('사용자 검색 실패: $e');
      _setLoading(false);
      return [];
    }
  }

  // ============================================
  // 사용자 ID 중복 확인
  // ============================================

  @override
  Future<bool> checkUserIdAvailable(String userId) async {
    _setLoading(true);
    _clearError();

    try {
      final isAvailable = await _userService.checkUserIdAvailable(userId);
      _setLoading(false);
      return isAvailable;
    } catch (e) {
      _setError('ID 중복 확인 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  // ============================================
  // 사용자 정보 수정
  // ============================================

  @override
  Future<User?> updateUser({
    required int id,
    String? name,
    String? userId,
    String? phoneNum,
    String? birthDate,
    String? profileImage,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _userService.updateUser(
        id: id,
        name: name,
        userId: userId,
        phoneNum: phoneNum,
        birthDate: birthDate,
        profileImage: profileImage,
      );
      _setLoading(false);
      return user;
    } catch (e) {
      _setError('사용자 정보 수정 실패: $e');
      _setLoading(false);
      return null;
    }
  }

  @override
  Future<User?> updateProfileImage({
    required int userId,
    required String profileImage,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _userService.updateProfileImage(
        userId: userId,
        profileImage: profileImage,
      );
      _setLoading(false);
      return user;
    } catch (e) {
      _setError('프로필 이미지 수정 실패: $e');
      _setLoading(false);
      return null;
    }
  }

  // ============================================
  // 사용자 삭제
  // ============================================

  @override
  Future<User?> deleteUser(int id) async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _userService.deleteUser(id);
      _setLoading(false);
      return user;
    } catch (e) {
      _setError('사용자 삭제 실패: $e');
      _setLoading(false);
      return null;
    }
  }

  @override
  void clearError() {
    _clearError();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  // ============================================================
  // 로그인 상태 유지 (SharedPreferences) 메서드
  // ============================================================

  /// 로그인 상태를 SharedPreferences에 저장합니다.
  @override
  Future<void> saveLoginState({
    required int userId,
    required String phoneNumber,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setInt(_keyUserId, userId);
      await prefs.setString(_keyPhoneNumber, phoneNumber);
      debugPrint('[ApiUserController] 로그인 상태 저장 완료: userId=$userId');
    } catch (e) {
      debugPrint('[ApiUserController] 로그인 상태 저장 실패: $e');
    }
  }

  /// 온보딩 완료 상태를 저장합니다.
  @override
  Future<void> setOnboardingCompleted(bool completed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyOnboardingCompleted, completed);
      debugPrint('[ApiUserController] 온보딩 완료 상태 저장: $completed');
    } catch (e) {
      debugPrint('[ApiUserController] 온보딩 완료 상태 저장 실패: $e');
    }
  }

  /// 온보딩 완료 여부를 확인합니다.
  @override
  Future<bool> isOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyOnboardingCompleted) ?? false;
    } catch (e) {
      debugPrint('[ApiUserController] 온보딩 완료 상태 확인 실패: $e');
      return false;
    }
  }

  /// 저장된 로그인 상태를 확인합니다.
  @override
  Future<bool> isLoggedInPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyIsLoggedIn) ?? false;
    } catch (e) {
      debugPrint('[ApiUserController] 로그인 상태 확인 실패: $e');
      return false;
    }
  }

  /// 저장된 사용자 정보를 가져옵니다.
  @override
  Future<Map<String, dynamic>?> getSavedUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;

      if (!isLoggedIn) {
        return null;
      }

      final userId = prefs.getInt(_keyUserId);
      final phoneNumber = prefs.getString(_keyPhoneNumber);

      if (userId == null) {
        return null;
      }

      return {
        'userId': userId,
        'phoneNumber': phoneNumber,
        'onboardingCompleted': prefs.getBool(_keyOnboardingCompleted) ?? false,
      };
    } catch (e) {
      debugPrint('[ApiUserController] 저장된 사용자 정보 조회 실패: $e');
      return null;
    }
  }

  /// 자동 로그인을 시도합니다.
  /// 저장된 사용자 ID로 서버에서 사용자 정보를 가져옵니다.
  @override
  Future<bool> tryAutoLogin() async {
    try {
      debugPrint('[ApiUserController] 자동 로그인 시도...');

      final savedInfo = await getSavedUserInfo();
      if (savedInfo == null) {
        debugPrint('[ApiUserController] 저장된 로그인 정보 없음');
        return false;
      }

      final userId = savedInfo['userId'] as int;
      debugPrint('[ApiUserController] 저장된 userId: $userId');

      // 서버에서 사용자 정보 조회
      final user = await getUser(userId);
      if (user != null) {
        _currentUser = user;
        notifyListeners();
        debugPrint('ApiUserController] 자동 로그인 성공: ${user.name}');
        return true;
      } else {
        debugPrint('[ApiUserController] 사용자 정보 조회 실패, 로그인 상태 초기화');
        await clearLoginState();
        return false;
      }
    } catch (e) {
      debugPrint('[ApiUserController] 자동 로그인 실패: $e');
      await clearLoginState();
      return false;
    }
  }

  /// 저장된 로그인 상태를 삭제합니다.
  @override
  Future<void> clearLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyIsLoggedIn);
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyPhoneNumber);
      await prefs.remove(_keyOnboardingCompleted);
      debugPrint('[ApiUserController] 로그인 상태 삭제 완료');
    } catch (e) {
      debugPrint('[ApiUserController] 로그인 상태 삭제 실패: $e');
    }
  }
}
