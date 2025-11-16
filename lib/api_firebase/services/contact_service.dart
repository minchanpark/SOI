import 'package:flutter_contacts/flutter_contacts.dart';
import '../repositories/contact_repository.dart';

/// 연락처 관련 비즈니스 로직을 담당하는 서비스 클래스
class ContactService {
  final ContactRepository _repository = ContactRepository();

  /// 싱글톤 인스턴스
  static final ContactService _instance = ContactService._internal();
  factory ContactService() => _instance;
  ContactService._internal();

  /// 연락처 동기화 상태
  bool _contactSyncEnabled = false;
  bool get contactSyncEnabled => _contactSyncEnabled;

  /// 로딩 상태
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// 초기화 완료 여부
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // ContactService에 캐싱 추가
  List<Contact>? _cachedContacts;
  DateTime? _lastFetchTime;

  /// 초기화 (앱 시작 시 호출)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadContactSyncSetting();
      _isInitialized = true;
    } catch (e) {
      // // debugPrint('ContactService 초기화 실패: $e');
    }
  }

  /// 페이지 진입 시 연락처 권한 자동 요청 및 설정 로드
  Future<ContactInitResult> initializeContactPermission() async {
    _setLoading(true);

    try {
      // 1. 저장된 설정 먼저 로드
      await _loadContactSyncSetting();

      // 2. 자동으로 권한 요청
      final result = await _repository.requestContactPermission();

      if (result) {
        // 권한이 허용된 경우 토글을 true로 설정
        _contactSyncEnabled = true;
        await _saveContactSyncSetting(true);

        return ContactInitResult.success(
          message: '연락처 동기화가 활성화되었습니다',
          isEnabled: true,
        );
      } else {
        // 권한이 거부된 경우
        _contactSyncEnabled = false;
        await _saveContactSyncSetting(false);

        return ContactInitResult.failure(
          message: '연락처 권한이 거부되었습니다',
          isEnabled: false,
        );
      }
    } catch (e) {
      return ContactInitResult.error(
        message: '초기화 중 오류가 발생했습니다: $e',
        isEnabled: false,
      );
    } finally {
      _setLoading(false);
    }
  }

  /// 토글 상태 변경 처리
  Future<ContactToggleResult> handleToggleChange() async {
    if (_contactSyncEnabled) {
      // 토글을 끄려고 하는 경우 - 설정 이동 필요
      return ContactToggleResult.requiresSettings(
        message: '연락처 동기화를 비활성화하려면 기기 설정에서 연락처 권한을 직접 해제해주세요.',
      );
    } else {
      // 토글을 켜려고 하는 경우 - 권한 재요청
      return await _requestContactPermission();
    }
  }

  /// 설정에서 돌아온 후 권한 상태 재확인
  Future<ContactToggleResult> checkPermissionAfterSettings() async {
    try {
      final hasPermission = await _repository.requestContactPermission();
      _contactSyncEnabled = hasPermission;
      await _saveContactSyncSetting(hasPermission);

      return ContactToggleResult.success(
        message: hasPermission ? '연락처 동기화가 활성화되었습니다' : '연락처 동기화가 비활성화되었습니다',
        isEnabled: hasPermission,
      );
    } catch (e) {
      return ContactToggleResult.error(
        message: '권한 확인 중 오류가 발생했습니다: $e',
        isEnabled: false,
      );
    }
  }

  /// Repository에서 연락처 동기화 설정 로드
  Future<void> _loadContactSyncSetting() async {
    _contactSyncEnabled = await _repository.loadContactSyncSetting();
  }

  /// Repository에 연락처 동기화 설정 저장
  Future<void> _saveContactSyncSetting(bool value) async {
    await _repository.saveContactSyncSetting(value);
  }

  /// 연락처 권한 요청 (내부 메서드)
  Future<ContactToggleResult> _requestContactPermission() async {
    _setLoading(true);

    try {
      final result = await _repository.requestContactPermission();

      if (result) {
        _contactSyncEnabled = true;
        await _saveContactSyncSetting(true);

        return ContactToggleResult.success(
          message: '연락처 동기화가 활성화되었습니다',
          isEnabled: true,
        );
      } else {
        return ContactToggleResult.failure(
          message: '연락처 권한이 필요합니다',
          isEnabled: false,
        );
      }
    } catch (e) {
      return ContactToggleResult.error(
        message: '권한 요청 중 오류가 발생했습니다: $e',
        isEnabled: false,
      );
    } finally {
      _setLoading(false);
    }
  }

  /// 로딩 상태 설정
  void _setLoading(bool loading) {
    _isLoading = loading;
  }

  /// 연락처 목록 가져오기 (권한이 있을 때)
  Future<List<Contact>> getContacts({bool forceRefresh = false}) async {
    if (!_contactSyncEnabled) {
      throw Exception('연락처 동기화가 비활성화되어 있습니다');
    }

    // 가져온 데이터가 있으면 캐시 사용
    if (!forceRefresh && _cachedContacts != null && _lastFetchTime != null) {
      return _cachedContacts!;
    }

    try {
      // 새로 가져오기
      _cachedContacts = await _repository.getContacts();
      _lastFetchTime = DateTime.now();
      return _cachedContacts!;
    } catch (e) {
      throw Exception('연락처 목록을 가져오는데 실패했습니다: $e');
    }
  }

  /// 특정 연락처 정보 가져오기
  Future<Contact?> getContact(String id) async {
    if (!_contactSyncEnabled) {
      throw Exception('연락처 동기화가 비활성화되어 있습니다');
    }

    try {
      return await _repository.getContact(id);
    } catch (e) {
      throw Exception('연락처 정보를 가져오는데 실패했습니다: $e');
    }
  }

  /// 연락처 검색
  Future<List<Contact>> searchContacts(String query) async {
    if (!_contactSyncEnabled) {
      throw Exception('연락처 동기화가 비활성화되어 있습니다');
    }

    try {
      return await _repository.searchContacts(query);
    } catch (e) {
      throw Exception('연락처 검색에 실패했습니다: $e');
    }
  }
}

/// 연락처 초기화 결과
class ContactInitResult {
  final bool isSuccess;
  final bool isEnabled;
  final String message;
  final ContactInitResultType type;

  ContactInitResult._({
    required this.isSuccess,
    required this.isEnabled,
    required this.message,
    required this.type,
  });

  factory ContactInitResult.success({
    required String message,
    required bool isEnabled,
  }) => ContactInitResult._(
    isSuccess: true,
    isEnabled: isEnabled,
    message: message,
    type: ContactInitResultType.success,
  );

  factory ContactInitResult.failure({
    required String message,
    required bool isEnabled,
  }) => ContactInitResult._(
    isSuccess: false,
    isEnabled: isEnabled,
    message: message,
    type: ContactInitResultType.failure,
  );

  factory ContactInitResult.error({
    required String message,
    required bool isEnabled,
  }) => ContactInitResult._(
    isSuccess: false,
    isEnabled: isEnabled,
    message: message,
    type: ContactInitResultType.error,
  );
}

/// 연락처 토글 결과
class ContactToggleResult {
  final bool isSuccess;
  final bool isEnabled;
  final String message;
  final ContactToggleResultType type;

  ContactToggleResult._({
    required this.isSuccess,
    required this.isEnabled,
    required this.message,
    required this.type,
  });

  factory ContactToggleResult.success({
    required String message,
    required bool isEnabled,
  }) => ContactToggleResult._(
    isSuccess: true,
    isEnabled: isEnabled,
    message: message,
    type: ContactToggleResultType.success,
  );

  factory ContactToggleResult.failure({
    required String message,
    required bool isEnabled,
  }) => ContactToggleResult._(
    isSuccess: false,
    isEnabled: isEnabled,
    message: message,
    type: ContactToggleResultType.failure,
  );

  factory ContactToggleResult.error({
    required String message,
    required bool isEnabled,
  }) => ContactToggleResult._(
    isSuccess: false,
    isEnabled: isEnabled,
    message: message,
    type: ContactToggleResultType.error,
  );

  factory ContactToggleResult.requiresSettings({required String message}) =>
      ContactToggleResult._(
        isSuccess: false,
        isEnabled: true, // 현재는 활성화된 상태
        message: message,
        type: ContactToggleResultType.requiresSettings,
      );
}

/// 연락처 초기화 결과 타입
enum ContactInitResultType { success, failure, error }

/// 연락처 토글 결과 타입
enum ContactToggleResultType { success, failure, error, requiresSettings }
