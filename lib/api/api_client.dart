import 'package:soi_api_client/api.dart';

import 'api_exception.dart';

/// SOI API 클라이언트 설정 및 관리 클래스
///
/// 이 클래스는 싱글톤 패턴으로 구현되어 앱 전체에서 하나의 인스턴스만 사용합니다.
/// API 클라이언트의 기본 설정, 헤더 관리, 에러 핸들링 등을 담당합니다.
///
/// 사용 예시:
/// ```dart
/// // 앱 시작 시 초기화
/// SoiApiClient.instance.initialize(basePath: 'https://newdawnsoi.site');
///
/// // 서비스에서 사용
/// final userApi = SoiApiClient.instance.userApi;
/// ```
class SoiApiClient {
  // ============================================
  // 싱글톤 패턴 구현
  // ============================================

  static final SoiApiClient _instance = SoiApiClient._internal();

  /// 싱글톤 인스턴스 접근자
  static SoiApiClient get instance => _instance;

  SoiApiClient._internal();

  // ============================================
  // API 클라이언트 설정
  // ============================================

  /// 기본 API 서버 URL
  static const String defaultBasePath = 'https://newdawnsoi.site';

  /// OpenAPI 생성 클라이언트
  late ApiClient _apiClient;

  /// 초기화 여부
  bool _isInitialized = false;

  /// 현재 인증 토큰 (향후 JWT 사용시)
  String? _authToken;

  // ============================================
  // API 인스턴스들 (Lazy initialization)
  // ============================================

  UserAPIApi? _userApi;
  CategoryAPIApi? _categoryApi;
  PostAPIApi? _postApi;
  FriendAPIApi? _friendApi;
  CommentAPIApi? _commentApi;
  NotificationAPIApi? _notificationApi;
  APIApi? _mediaApi;

  // ============================================
  // 초기화 메서드
  // ============================================

  /// API 클라이언트 초기화
  ///
  /// [basePath]를 지정하지 않으면 기본값 'https://newdawnsoi.site' 사용
  /// 앱 시작 시 한 번 호출해주세요.
  ///
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   SoiApiClient.instance.initialize();
  ///   runApp(MyApp());
  /// }
  /// ```
  void initialize({String basePath = defaultBasePath}) {
    _apiClient = ApiClient(basePath: basePath);
    _isInitialized = true;

    // API 인스턴스들 초기화
    _userApi = null;
    _categoryApi = null;
    _postApi = null;
    _friendApi = null;
    _commentApi = null;
    _notificationApi = null;
    _mediaApi = null;
  }

  /// 초기화 확인
  void _checkInitialized() {
    if (!_isInitialized) {
      throw const SoiApiException(
        message: 'SoiApiClient가 초기화되지 않았습니다. initialize()를 먼저 호출해주세요.',
      );
    }
  }

  // ============================================
  // 인증 토큰 관리 (향후 JWT 사용시)
  // ============================================

  /// 인증 토큰 설정
  ///
  /// JWT 또는 Bearer 토큰을 설정합니다.
  /// 설정 후 모든 API 요청에 Authorization 헤더가 추가됩니다.
  void setAuthToken(String token) {
    _authToken = token;
    _apiClient.addDefaultHeader('Authorization', 'Bearer $token');
  }

  /// 인증 토큰 제거
  ///
  /// 로그아웃 시 호출합니다.
  void clearAuthToken() {
    _authToken = null;
    _apiClient.defaultHeaderMap.remove('Authorization');
  }

  /// 현재 인증 토큰 확인
  String? get authToken => _authToken;

  /// 인증 상태 확인
  bool get isAuthenticated => _authToken != null;

  // ============================================
  // API 인스턴스 Getter들
  // ============================================

  /// 사용자 API
  UserAPIApi get userApi {
    _checkInitialized();
    return _userApi ??= UserAPIApi(_apiClient);
  }

  /// 카테고리 API
  CategoryAPIApi get categoryApi {
    _checkInitialized();
    return _categoryApi ??= CategoryAPIApi(_apiClient);
  }

  /// 게시물 API
  PostAPIApi get postApi {
    _checkInitialized();
    return _postApi ??= PostAPIApi(_apiClient);
  }

  /// 친구 API
  FriendAPIApi get friendApi {
    _checkInitialized();
    return _friendApi ??= FriendAPIApi(_apiClient);
  }

  /// 댓글 API
  CommentAPIApi get commentApi {
    _checkInitialized();
    return _commentApi ??= CommentAPIApi(_apiClient);
  }

  /// 알림 API
  NotificationAPIApi get notificationApi {
    _checkInitialized();
    return _notificationApi ??= NotificationAPIApi(_apiClient);
  }

  /// 미디어 API
  APIApi get mediaApi {
    _checkInitialized();
    return _mediaApi ??= APIApi(_apiClient);
  }

  /// 기본 ApiClient 접근 (고급 사용자용)
  ApiClient get apiClient {
    _checkInitialized();
    return _apiClient;
  }

  // ============================================
  // 기본 헤더 관리
  // ============================================

  /// 기본 헤더 추가
  void addDefaultHeader(String key, String value) {
    _checkInitialized();
    _apiClient.addDefaultHeader(key, value);
  }

  /// 기본 헤더 제거
  void removeDefaultHeader(String key) {
    _checkInitialized();
    _apiClient.defaultHeaderMap.remove(key);
  }
}
