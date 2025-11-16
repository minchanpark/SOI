import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:soi/api_firebase/controllers/category_cover_photo_controller.dart';
import 'package:soi/api_firebase/controllers/category_search_controller.dart';
import 'api_firebase/controllers/category_member_controller.dart';
import 'api_firebase/controllers/comment_record_controller.dart';
import 'api_firebase/controllers/contact_controller.dart';
import 'api_firebase/controllers/media_controller.dart';
import 'api_firebase/controllers/friend_request_controller.dart';
import 'api_firebase/controllers/friend_controller.dart';
import 'api_firebase/controllers/user_matching_controller.dart';
import 'api_firebase/controllers/emoji_reaction_controller.dart';
import 'api_firebase/services/friend_request_service.dart';
import 'api_firebase/services/friend_service.dart';
import 'api_firebase/services/user_matching_service.dart';
import 'api_firebase/repositories/friend_request_repository.dart';
import 'api_firebase/repositories/friend_repository.dart';
import 'api_firebase/repositories/user_search_repository.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'views/about_archiving/screens/archive_detail/all_archives_screen.dart';
import 'views/about_archiving/screens/archive_detail/my_archives_screen.dart';
import 'views/about_archiving/screens/archive_detail/shared_archives_screen.dart';
import 'views/about_archiving/screens/archive_main_screen.dart';
import 'views/about_camera/camera_screen.dart';
import 'views/about_feed/feed_home.dart';
import 'views/about_friends/friend_list_add_screen.dart';
import 'views/about_friends/friend_list_screen.dart';
import 'views/about_friends/friend_request_screen.dart';
import 'views/about_login/register_screen.dart';
import 'views/about_login/login_screen.dart';
import 'views/about_login/start_screen.dart';
import 'views/about_notification/notification_screen.dart';
import 'views/about_onboarding/onboarding_main_screen.dart';
import 'views/about_profile/blocked_friend_list_screen.dart';
import 'views/about_profile/deleted_post_list_screen.dart';
import 'views/about_profile/post_management_screen.dart';
import 'views/about_profile/privacy_protect_screen.dart';
import 'views/about_profile/profile_screen.dart';
import 'views/about_setting/privacy.dart';
import 'views/about_friends/friend_management_screen.dart';
import 'api_firebase/controllers/auth_controller.dart';
import 'api_firebase/controllers/category_controller.dart';
import 'api_firebase/controllers/audio_controller.dart';
import 'api_firebase/controllers/comment_audio_controller.dart';
import 'api_firebase/controllers/notification_controller.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'views/home_navigator_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'utils/app_route_observer.dart';
import 'views/launch_video_screen.dart';

/// 앱 진입점
/// firebase-version 코드입니다.
void main() async {
  // Flutter 바인딩 초기화
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // SharedPreferences에서 인트로 비디오 시청 여부 확인
  final prefs = await SharedPreferences.getInstance();

  // 앱 최초 실행 시 인트로 비디오 재생을 위해 스플래시 화면 유지
  final hasSeenLaunchVideo = prefs.getBool('hasSeenLaunchVideo') ?? false;

  // 앱 최초 실행이 아닌 경우에만 스플래시 화면 유지
  if (hasSeenLaunchVideo) {
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  } else {
    FlutterNativeSplash.remove();
  }

  // 환경 변수 로드
  await dotenv.load(fileName: ".env");

  // 날짜 포맷팅 초기화 (한국어 로케일)
  await initializeDateFormatting('ko_KR', null);

  // 메모리 최적화: ImageCache 크기 제한 (메모리 사용량 대폭 감소)
  if (kDebugMode) {
    // Debug 모드: 개발 편의성을 위해 조금 더 여유롭게 설정
    PaintingBinding.instance.imageCache.maximumSize = 50; // 최대 50개 이미지 캐시
    PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;
  } else {
    // Release 모드: 메모리 사용량 최소화
    PaintingBinding.instance.imageCache.maximumSize = 30; // 최대 30개 이미지 캐시
    PaintingBinding.instance.imageCache.maximumSizeBytes = 30 * 1024 * 1024;
  }

  // Firebase 초기화 (더 안전한 방법)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Firebase Auth 설정 (Firebase가 성공적으로 초기화된 경우에만)
    try {
      FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: false,
        forceRecaptchaFlow: false,
      );
    } catch (authError) {
      rethrow;
    }
  } catch (e) {
    rethrow;
  }

  // Supabase 설정: Storage 사용을 위한 초기화
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  try {
    await Supabase.initialize(url: supabaseUrl!, anonKey: supabaseAnonKey!);
  } catch (e) {
    debugPrint('[Supabase][Storage] Initialization failed: $e');
  }

  // 에러 핸들링 추가
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  // 플랫폼 에러 핸들링 (예: 비동기 코드의 에러)
  PlatformDispatcher.instance.onError = (error, stack) {
    // Firebase Auth reCAPTCHA 에러 무시 (사용자에게 영향 없음)
    if (error.toString().contains('reCAPTCHA') ||
        error.toString().contains('web-internal-error')) {
      return true;
    }

    return true;
  };

  debugPaintSizeEnabled = false;

  if (hasSeenLaunchVideo) {
    FlutterNativeSplash.remove();
  }

  runApp(MyApp(hasSeenLaunchVideo: hasSeenLaunchVideo));
}

class MyApp extends StatefulWidget {
  final bool hasSeenLaunchVideo;
  const MyApp({super.key, required this.hasSeenLaunchVideo});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => CategoryController()),
        ChangeNotifierProvider(create: (_) => AudioController()),
        ChangeNotifierProvider(create: (_) => CommentAudioController()),
        ChangeNotifierProvider(create: (_) => CommentRecordController()),
        ChangeNotifierProvider(create: (_) => PhotoController()),
        ChangeNotifierProvider(create: (_) => ContactController()),
        ChangeNotifierProvider(create: (_) => EmojiReactionController()),
        ChangeNotifierProvider(create: (_) => CategoryMemberController()),
        ChangeNotifierProvider(create: (_) => CategoryCoverPhotoController()),
        ChangeNotifierProvider(create: (_) => CategorySearchController()),

        // 친구 관리 관련 컨트롤러들
        ChangeNotifierProvider(
          create: (_) => FriendRequestController(
            friendRequestService: FriendRequestService(
              friendRequestRepository: FriendRequestRepository(),
              friendRepository: FriendRepository(),
              userSearchRepository: UserSearchRepository(),
            ),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => FriendController(
            friendService: FriendService(
              friendRepository: FriendRepository(),
              userSearchRepository: UserSearchRepository(),
            ),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => UserMatchingController(
            userMatchingService: UserMatchingService(
              userSearchRepository: UserSearchRepository(),
              friendRepository: FriendRepository(),
              friendRequestRepository: FriendRequestRepository(),
            ),
            friendRequestService: FriendRequestService(
              friendRequestRepository: FriendRequestRepository(),
              friendRepository: FriendRepository(),
              userSearchRepository: UserSearchRepository(),
            ),
            userSearchRepository: UserSearchRepository(),
          ),
        ),

        // 알림 관리 컨트롤러
        ChangeNotifierProvider(create: (_) => NotificationController()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        child: MaterialApp(
          initialRoute: widget.hasSeenLaunchVideo ? '/' : '/launch_video',
          navigatorObservers: [appRouteObserver],
          debugShowCheckedModeBanner: false,
          routes: {
            '/launch_video': (context) => const LaunchVideoScreen(),
            '/': (context) => const StartScreen(),
            '/home_navigation_screen': (context) =>
                HomePageNavigationBar(currentPageIndex: 1),
            '/camera': (context) => const CameraScreen(),
            '/archiving': (context) => const ArchiveMainScreen(),
            '/start': (context) => const StartScreen(),
            '/auth': (context) => AuthScreen(),
            '/login': (context) => const LoginScreen(),
            '/onboarding': (context) => const OnboardingMainScreen(),

            // 아카이빙 관련 라우트
            '/share_record': (context) => const SharedArchivesScreen(),
            '/my_record': (context) => const MyArchivesScreen(),
            '/all_category': (context) => const AllArchivesScreen(),
            '/privacy_policy': (context) => const PrivacyPolicyScreen(),

            // 친구 관리 라우트
            '/contact_manager': (context) => const FriendManagementScreen(),
            '/friend_list_add': (context) => const FriendListAddScreen(),
            '/friend_list': (context) => const FriendListScreen(),
            '/friend_requests': (context) => const FriendRequestScreen(),

            // 피드 홈 라우트
            '/feed_home': (context) => const FeedHomeScreen(),

            // 프로필 페이지 라우트
            '/profile_screen': (context) => const ProfileScreen(),
            '/privacy_protect': (context) => const PrivacyProtectScreen(),
            '/blocked_friends': (context) => const BlockedFriendListScreen(),
            '/post_management': (context) => const PostManagementScreen(),
            '/delete_photo': (context) => const DeletedPostListScreen(),

            // 알림 페이지 라우트
            '/notifications': (context) => const NotificationScreen(),
          },
          theme: ThemeData(iconTheme: IconThemeData(color: Colors.white)),
        ),
      ),
    );
  }
}
