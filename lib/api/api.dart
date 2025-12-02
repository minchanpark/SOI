/// SOI API 래퍼 레이어
///
/// 이 파일은 SOI 앱에서 백엔드 API를 사용하기 위한 래퍼 레이어입니다.
/// 자동 생성된 OpenAPI 클라이언트를 간편하게 사용할 수 있도록 래핑합니다.
///
/// ## 주요 기능
/// - 간편한 API 호출 (복잡한 DTO 래핑 자동 처리)
/// - 일관된 에러 핸들링 (SoiApiException 계층 구조)
/// - Provider 패턴 지원
///
/// ## 초기화
/// 앱 시작 시 반드시 초기화해주세요:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   SoiApiClient.instance.initialize();
///   runApp(MyApp());
/// }
/// ```
///
/// ## 사용 예시
/// ```dart
/// // Provider 등록
/// MultiProvider(
///   providers: [
///     Provider(create: (_) => AuthService()),
///     Provider(create: (_) => UserService()),
///     Provider(create: (_) => CategoryService()),
///     Provider(create: (_) => PostService()),
///     Provider(create: (_) => FriendService()),
///     Provider(create: (_) => CommentService()),
///     Provider(create: (_) => MediaService()),
///   ],
///   child: MyApp(),
/// )
///
/// // 서비스 사용
/// final authService = Provider.of<AuthService>(context, listen: false);
/// try {
///   final success = await authService.sendSmsVerification('01012345678');
/// } on NetworkException catch (e) {
///   // 네트워크 에러 처리
/// } on SoiApiException catch (e) {
///   // 기타 API 에러 처리
/// }
/// ```
library soi_api;

// ============================================
// 클라이언트 설정
// ============================================
export 'api_client.dart';

// ============================================
// 예외 클래스
// ============================================
export 'api_exception.dart';

// ============================================
// 서비스 클래스
// ============================================
export 'services/user_service.dart';
export 'services/category_service.dart';
export 'services/post_service.dart';
export 'services/friend_service.dart';
export 'services/comment_service.dart';
export 'services/media_service.dart';

// ============================================
// 생성된 API 모델 re-export (필요시 직접 사용)
// ============================================
export 'package:soi_api_client/api.dart'
    show
        // 요청 DTO
        AuthCheckReqDto,
        UserCreateReqDto,
        UserUpdateReqDto,
        CategoryCreateReqDto,
        CategoryInviteReqDto,
        CategoryInviteResponseReqDto,
        PostCreateReqDto,
        PostUpdateReqDto,
        FriendCreateReqDto,
        FriendReqDto,
        FriendUpdateRespDto,
        CommentReqDto,
        // 응답 DTO
        UserRespDto,
        UserFindRespDto,
        CategoryRespDto,
        PostRespDto,
        FriendRespDto,
        FriendCheckRespDto,
        CommentRespDto;
