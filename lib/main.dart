import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soi/api/controller/api_category_controller.dart';
import 'package:soi/api/controller/api_comment_controller.dart';
import 'package:soi/api/controller/api_friend_controller.dart';
import 'package:soi/api/controller/api_media_controller.dart';
import 'package:soi/api/controller/api_post_controller.dart';
import 'package:soi/api/controller/api_user_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_firebase/controllers/audio_controller.dart';
import 'api_firebase/controllers/auth_controller.dart';
import 'api_firebase/controllers/category_controller.dart';
import 'api_firebase/controllers/category_cover_photo_controller.dart';
import 'api_firebase/controllers/category_member_controller.dart';
import 'api_firebase/controllers/category_search_controller.dart';
import 'api_firebase/controllers/comment_audio_controller.dart';
import 'api_firebase/controllers/comment_record_controller.dart';
import 'api_firebase/controllers/contact_controller.dart';
import 'api_firebase/controllers/emoji_reaction_controller.dart';
import 'api_firebase/controllers/friend_controller.dart';
import 'api_firebase/controllers/friend_request_controller.dart';
import 'api_firebase/controllers/media_controller.dart';
import 'api_firebase/controllers/notification_controller.dart';
import 'api_firebase/controllers/user_matching_controller.dart';
import 'api_firebase/repositories/friend_repository.dart';
import 'api_firebase/repositories/friend_request_repository.dart';
import 'api_firebase/repositories/user_search_repository.dart';
import 'api_firebase/services/friend_request_service.dart';
import 'api_firebase/services/friend_service.dart';
import 'api_firebase/services/user_matching_service.dart';
// New API Services (Backend REST API)
import 'api/api.dart' as api;
import 'firebase_options.dart';
import 'utils/app_route_observer.dart';
import 'views/about_archiving/screens/archive_detail/all_archives_screen.dart';
import 'views/about_archiving/screens/archive_detail/my_archives_screen.dart';
import 'views/about_archiving/screens/archive_detail/shared_archives_screen.dart';
import 'views/about_archiving/screens/archive_main_screen.dart';
import 'views/about_camera/camera_screen.dart';
import 'views/about_feed/feed_home.dart';
import 'views/about_friends/friend_list_add_screen.dart';
import 'views/about_friends/friend_list_screen.dart';
import 'views/about_friends/friend_management_screen.dart';
import 'views/about_friends/friend_request_screen.dart';
import 'views/about_login/login_screen.dart';
import 'views/about_login/register_screen.dart';
import 'views/about_login/start_screen.dart';
import 'views/about_notification/notification_screen.dart';
import 'views/about_onboarding/onboarding_main_screen.dart';
import 'views/about_profile/blocked_friend_list_screen.dart';
import 'views/about_profile/deleted_post_list_screen.dart';
import 'views/about_profile/post_management_screen.dart';
import 'views/about_profile/profile_screen.dart';
import 'views/about_profile/privacy_protect_screen.dart';
import 'views/about_setting/privacy.dart';
import 'views/about_setting/terms_of_service.dart';
import 'views/home_navigator_screen.dart';
import 'views/launch_video_screen.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final hasSeenLaunchVideo = prefs.getBool('hasSeenLaunchVideo') ?? false;

  // 비디오가 재생된 적이 있다면, 스플래시 화면을 유지
  // 비디오가 재생된 적이 없다면, 스플래시 화면 제거하고 비디오 재생
  _configureSplash(binding, hasSeenLaunchVideo);

  // .env 파일 로드
  await dotenv.load(fileName: ".env");

  // 한국어 로케일 초기화
  await initializeDateFormatting('ko_KR', null);

  // 이미지 캐시 설정
  _configureImageCache();

  // Firebase 초기화
  await _initFirebase();

  // Supabase 초기화
  await _initSupabase();

  // REST API 클라이언트 초기화
  api.SoiApiClient.instance.initialize();

  _configureErrorHandling();

  if (hasSeenLaunchVideo) {
    FlutterNativeSplash.remove();
  }

  runApp(MyApp(hasSeenLaunchVideo: hasSeenLaunchVideo));
}

void _configureSplash(WidgetsBinding binding, bool hasSeenLaunchVideo) {
  hasSeenLaunchVideo
      ? FlutterNativeSplash.preserve(widgetsBinding: binding)
      : FlutterNativeSplash.remove();
}

void _configureImageCache() {
  final cache = PaintingBinding.instance.imageCache;
  const maxItems = kDebugMode ? 50 : 30;
  const maxBytes = maxItems * 1024 * 1024;

  cache.maximumSize = maxItems;
  cache.maximumSizeBytes = maxBytes;
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAuth.instance.setSettings(
      appVerificationDisabledForTesting: false,
      forceRecaptchaFlow: false,
    );
  } catch (_) {
    rethrow;
  }
}

Future<void> _initSupabase() async {
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseAnonKey == null) return;

  try {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  } catch (e) {
    debugPrint('[Supabase][Storage] Initialization failed: $e');
  }
}

void _configureErrorHandling() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (error.toString().contains('reCAPTCHA') ||
        error.toString().contains('web-internal-error')) {
      return true;
    }
    return true;
  };

  debugPaintSizeEnabled = false;
}

class MyApp extends StatelessWidget {
  final bool hasSeenLaunchVideo;
  const MyApp({super.key, required this.hasSeenLaunchVideo});

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
        ChangeNotifierProvider(create: (_) => NotificationController()),
        // ============================================
        // New Backend API Services (REST API)
        // ============================================
        ChangeNotifierProvider<ApiUserController>(
          create: (_) => ApiUserController(),
        ),
        ChangeNotifierProvider<ApiCategoryController>(
          create: (_) => ApiCategoryController(),
        ),
        ChangeNotifierProvider<ApiPostController>(
          create: (_) => ApiPostController(),
        ),
        ChangeNotifierProvider<ApiFriendController>(
          create: (_) => ApiFriendController(),
        ),
        ChangeNotifierProvider<ApiCommentController>(
          create: (_) => ApiCommentController(),
        ),
        ChangeNotifierProvider<ApiMediaController>(
          create: (_) => ApiMediaController(),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        child: MaterialApp(
          initialRoute: hasSeenLaunchVideo ? '/' : '/launch_video',
          navigatorObservers: [appRouteObserver],
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            // 텍스트 크기 조정 제한을 위해서 디바이스의 MediaQuery를 가지고 온다.
            // 그리고 그 값을 복사하여 textScaler의 scale 값을 1.0에서 1.1 사이로 제한한다.
            final mediaQuery = MediaQuery.of(context);
            final clampedScale = mediaQuery.textScaler
                .scale(1.0)
                .clamp(1.0, 1.1);

            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(clampedScale),
              ),
              child: child!,
            );
          },
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
            '/share_record': (context) => const SharedArchivesScreen(),
            '/my_record': (context) => const MyArchivesScreen(),
            '/all_category': (context) => const AllArchivesScreen(),
            '/privacy_policy': (context) => const PrivacyPolicyScreen(),
            '/contact_manager': (context) => const FriendManagementScreen(),
            '/friend_list_add': (context) => const FriendListAddScreen(),
            '/friend_list': (context) => const FriendListScreen(),
            '/friend_requests': (context) => const FriendRequestScreen(),
            '/feed_home': (context) => const FeedHomeScreen(),
            '/profile_screen': (context) => const ProfileScreen(),
            '/privacy_protect': (context) => const PrivacyProtectScreen(),
            '/terms_of_service': (context) => const TermsOfService(),
            '/blocked_friends': (context) => const BlockedFriendListScreen(),
            '/post_management': (context) => const PostManagementScreen(),
            '/delete_photo': (context) => const DeletedPostListScreen(),
            '/notifications': (context) => const NotificationScreen(),
          },
          theme: ThemeData(iconTheme: IconThemeData(color: Colors.white)),
        ),
      ),
    );
  }
}
