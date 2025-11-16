import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../services/contact_service.dart';

/// 연락처 관련 UI 상태 관리를 담당하는 Controller
class ContactController extends ChangeNotifier {
  final ContactService _contactService = ContactService();

  // 상태 변수들
  bool _contactSyncEnabled = false;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isSyncPaused = false;
  bool _disposed = false; // dispose 상태 추가

  // Getters
  bool get contactSyncEnabled => _contactSyncEnabled;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isSyncPaused => _isSyncPaused;

  /// 초기화 (앱 시작 시 호출)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _contactService.initialize();
      _contactSyncEnabled = _contactService.contactSyncEnabled;
      _isInitialized = true;
      _safeNotifyListeners();
    } catch (e) {
      // debugPrint('ContactController 초기화 실패: $e');
    }
  }

  /// 페이지 진입 시 연락처 권한 자동 요청 및 설정 로드
  Future<ContactInitResult> initializeContactPermission() async {
    _setLoading(true);
    _safeNotifyListeners();

    try {
      final result = await _contactService.initializeContactPermission();

      // 상태 업데이트
      _contactSyncEnabled = result.isEnabled;
      _setLoading(false);
      _safeNotifyListeners();

      return result;
    } catch (e) {
      _setLoading(false);
      _safeNotifyListeners();

      return ContactInitResult.error(
        message: '초기화 중 오류가 발생했습니다: $e',
        isEnabled: false,
      );
    }
  }

  /// 토글 상태 변경 처리
  Future<ContactToggleResult> handleToggleChange() async {
    final result = await _contactService.handleToggleChange();

    // 성공한 경우에만 상태 업데이트
    if (result.type == ContactToggleResultType.success) {
      _contactSyncEnabled = result.isEnabled;
      _safeNotifyListeners();
    }

    return result;
  }

  /// 설정에서 돌아온 후 권한 상태 재확인
  Future<ContactToggleResult> checkPermissionAfterSettings() async {
    _setLoading(true);
    _safeNotifyListeners();

    try {
      final result = await _contactService.checkPermissionAfterSettings();

      // 상태 업데이트
      _contactSyncEnabled = result.isEnabled;
      _setLoading(false);
      _safeNotifyListeners();

      return result;
    } catch (e) {
      _setLoading(false);
      _safeNotifyListeners();

      return ContactToggleResult.error(
        message: '권한 확인 중 오류가 발생했습니다: $e',
        isEnabled: false,
      );
    }
  }

  /// 로딩 상태 설정
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
    }
  }

  /// 연락처 목록 가져오기 (권한이 있을 때)
  Future<List<Contact>> getContacts({bool forceRefresh = false}) async {
    return await _contactService.getContacts(forceRefresh: forceRefresh);
  }

  /// 특정 연락처 정보 가져오기
  Future<Contact?> getContact(String id) async {
    return await _contactService.getContact(id);
  }

  /// 연락처 검색
  Future<List<Contact>> searchContacts(String query) async {
    return await _contactService.searchContacts(query);
  }

  /// 동기화 일시 중지
  void pauseSync() {
    if (_contactSyncEnabled && !_isSyncPaused) {
      _isSyncPaused = true;
      _safeNotifyListeners();
    }
  }

  /// 동기화 재개
  void resumeSync() {
    if (_contactSyncEnabled && _isSyncPaused) {
      _isSyncPaused = false;
      _safeNotifyListeners();
    }
  }

  /// 동기화가 활성 상태인지 확인 (일시중지가 아닌 경우)
  bool get isActivelySyncing => _contactSyncEnabled && !_isSyncPaused;

  /// 안전한 notifyListeners 호출
  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
