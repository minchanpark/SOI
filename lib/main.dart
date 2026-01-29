import 'dart:async';
import 'dart:ui';
import 'package:app_links/app_links.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soi/api/controller/audio_controller.dart';
import 'package:soi/api/controller/category_controller.dart' as api_category;
import 'package:soi/api/controller/comment_controller.dart';
import 'package:soi/api/controller/comment_audio_controller.dart';
import 'package:soi/api/controller/contact_controller.dart';
import 'package:soi/api/controller/friend_controller.dart' as api_friend;
import 'package:soi/api/controller/media_controller.dart' as api_media;
import 'package:soi/api/controller/notification_controller.dart'
    as api_notification;
import 'package:soi/api/controller/post_controller.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/views/about_friends/friend_management_screen.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';

import 'package:soi/api/controller/category_search_controller.dart'
    as api_category_search;

// New API Services (Backend REST API)
import 'api/api.dart' as api;
import 'utils/app_route_observer.dart';
import 'views/about_archiving/screens/archive_detail/all_archives_screen.dart';
import 'views/about_archiving/screens/archive_detail/my_archives_screen.dart';
import 'views/about_archiving/screens/archive_detail/shared_archives_screen.dart';
import 'views/about_archiving/screens/api_archive_main_screen.dart';
import 'views/about_camera/camera_screen.dart';
import 'views/about_feed/feed_home.dart';
import 'views/about_feed/manager/feed_data_manager.dart';
import 'views/about_friends/friend_list_add_screen.dart';
import 'views/about_friends/friend_list_screen.dart';
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
  await EasyLocalization.ensureInitialized();
  await _lockPortraitOrientation();
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

  // REST API 클라이언트 초기화
  api.SoiApiClient.instance.initialize();

  // Kakao SDK 초기화
  KakaoSdk.init(nativeAppKey: dotenv.env['KAKAO_NATIVE_APP_KEY']!);

  _configureErrorHandling();

  final userController = UserController();
  final didAutoLogin = await userController.tryAutoLogin();
  if (didAutoLogin) {
    await userController.refreshCurrentUser();
  }

  if (hasSeenLaunchVideo) {
    FlutterNativeSplash.remove();
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ko'), Locale('es')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ko'),
      startLocale: PlatformDispatcher.instance.locale.languageCode == 'es'
          ? const Locale('es')
          : const Locale('ko'),

      child: MyApp(
        hasSeenLaunchVideo: hasSeenLaunchVideo,
        preloadedUserController: userController,
      ),
    ),
  );
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

Future<void> _lockPortraitOrientation() {
  return SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
}

class MyApp extends StatefulWidget {
  final bool hasSeenLaunchVideo;
  final UserController preloadedUserController;
  const MyApp({
    super.key,
    required this.hasSeenLaunchVideo,
    required this.preloadedUserController,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  Uri? _lastHandledUri;
  DateTime? _lastHandledTime;
  //bool _isInviteDialogShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleIncomingUri,
      onError: (error) {
        debugPrint('딥링크 수신 실패: $error');
      },
    );
    _handleInitialLink();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lockPortraitOrientation();
    }
  }

  Future<void> _handleInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) _handleIncomingUri(uri);
    } catch (e) {
      debugPrint('초기 딥링크 확인 실패: $e');
    }
  }

  void _handleIncomingUri(Uri uri) {
    debugPrint('URI: $uri');

    // URI + 시간 기반 중복 방지: 같은 URI를 3초 이내에 다시 처리하지 않음
    final now = DateTime.now();
    final isSameUri = _lastHandledUri == uri;
    final timeDiff = _lastHandledTime != null
        ? now.difference(_lastHandledTime!).inSeconds
        : 999; // 초기값은 충분히 큰 값

    if (isSameUri && timeDiff < 3) {
      debugPrint('중복 URI 무시: 마지막 처리 후 $timeDiff초 경과');
      return;
    }

    _lastHandledUri = uri;
    _lastHandledTime = now;

    final userId =
        uri.queryParameters['userId'] ??
        uri.queryParameters['refUserId'] ??
        uri.queryParameters['inviterId'] ??
        '';
    final nickName =
        uri.queryParameters['nickName'] ??
        uri.queryParameters['refNickname'] ??
        uri.queryParameters['inviter'] ??
        '';

    if (userId.isEmpty && nickName.isEmpty) return;

    unawaited(_processInviteLink(userId: userId, nickName: nickName));
  }

  Future<void> _processInviteLink({
    required String userId,
    required String nickName,
  }) async {
    final context = _navigatorKey.currentContext;
    if (context == null) return;

    final userController = Provider.of<UserController>(context, listen: false);
    final friendController = Provider.of<api_friend.FriendController>(
      context,
      listen: false,
    );
    final currentUser = userController.currentUser;

    if (currentUser != null) {
      final receiverPhoneNum = currentUser.phoneNumber;
      var requesterId = int.tryParse(userId);
      if (requesterId == null && nickName.isNotEmpty && nickName != '친구') {
        final inviterUser = await userController.getUserByNickname(nickName);
        requesterId = inviterUser?.id;
      }

      if (requesterId != null &&
          requesterId != currentUser.id &&
          receiverPhoneNum.isNotEmpty) {
        await friendController.addFriend(
          requesterId: requesterId,
          receiverPhoneNum: receiverPhoneNum,
        );
      }
    }

    /* if (!mounted) return;
    await _showInviteDialog(
      context: context,
      userId: userId,
      nickName: nickName,
    );*/
  }

  /* ㅇ Future<void> _showInviteDialog({
    required BuildContext context,
    required String userId,
    required String nickName,
  }) async {
    if (_isInviteDialogShowing) return;
    _isInviteDialogShowing = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final displayUserId = userId.isEmpty ? '-' : userId;
          final displayNickName = nickName.isEmpty ? '-' : nickName;
          return AlertDialog(
            title: const Text('친구 추가 요청이 왔어요!'),
            content: Text('userId: $displayUserId\nnickName: $displayNickName'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('확인'),
              ),
            ],
          );
        },
      );
    } finally {
      _isInviteDialogShowing = false;
    }
  }*/

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ============================================
        // New Backend API Services (REST API)
        // ============================================
        ChangeNotifierProvider<UserController>.value(
          value: widget.preloadedUserController,
        ),
        ChangeNotifierProvider<api_category.CategoryController>(
          create: (_) => api_category.CategoryController(),
        ),
        ChangeNotifierProvider<api_category_search.CategorySearchController>(
          create: (_) => api_category_search.CategorySearchController(),
        ),
        ChangeNotifierProvider<PostController>(create: (_) => PostController()),
        // 추가: 피드 캐시를 유지하기 위해 FeedDataManager를 전역 Provider로 유지합니다.
        ChangeNotifierProvider<FeedDataManager>(
          create: (_) => FeedDataManager(),
        ),
        ChangeNotifierProvider<api_friend.FriendController>(
          create: (_) => api_friend.FriendController(),
        ),
        ChangeNotifierProvider<CommentController>(
          create: (_) => CommentController(),
        ),
        ChangeNotifierProvider<api_media.MediaController>(
          create: (_) => api_media.MediaController(),
        ),
        ChangeNotifierProvider<api_notification.NotificationController>(
          create: (_) => api_notification.NotificationController(),
        ),
        ChangeNotifierProvider<ContactController>(
          create: (_) => ContactController(),
        ),
        ChangeNotifierProvider<AudioController>(
          create: (_) => AudioController(),
        ),
        // FeedAudioManager.stopAllAudio에서 사용 (댓글 오디오 동시 재생/정지 관리)
        ChangeNotifierProvider<CommentAudioController>(
          create: (_) => CommentAudioController(),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        child: MaterialApp(
          navigatorKey: _navigatorKey,
          initialRoute: widget.hasSeenLaunchVideo ? '/' : '/launch_video',
          navigatorObservers: [appRouteObserver],
          debugShowCheckedModeBanner: false,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,

          builder: (context, child) {
            // 텍스트 크기 조정 제한을 위해서 디바이스의 MediaQuery를 가지고 온다.
            // 그리고 그 값을 복사하여 textScaler의 scale 값을 1.0에서 1.1 사이로 제한한다.
            final mediaQuery = MediaQuery.of(context);
            final clampedScale = mediaQuery.textScaler
                .scale(1.0)
                .clamp(1.0, 1.1);
            final scaledChild = MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(clampedScale),
              ),
              child: child!,
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  return scaledChild;
                }

                return ColoredBox(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: scaledChild,
                    ),
                  ),
                );
              },
            );
          },
          routes: {
            '/launch_video': (context) => const LaunchVideoScreen(),
            '/': (context) => const StartScreen(),
            '/home_navigation_screen': (context) => HomePageNavigationBar(
              key: HomePageNavigationBar.rootKey,
              currentPageIndex: 1,
            ),
            '/camera': (context) => const CameraScreen(),
            '/archiving': (context) => const APIArchiveMainScreen(),
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
