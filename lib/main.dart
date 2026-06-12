import 'dart:async';
import 'dart:ui';

// == 패키지 ==
import 'package:app_links/app_links.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soi/api/controller/audio_controller.dart';
import 'package:soi/api/controller/friend_controller.dart' as api_friend;
import 'package:soi/api/controller/user_controller.dart';

// == API ==
import 'api/api.dart' as api;
import 'app/app_constants.dart';
import 'app/app_container_builder.dart';
import 'app/app_providers.dart';
import 'app/app_routes.dart';
import 'app/push/app_push_coordinator.dart';
import 'firebase_options.dart';
import 'utils/analytics_service.dart';
import 'utils/app_route_observer.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await _lockPortraitOrientation();
  final initialLocale = resolveSupportedLocale(
    PlatformDispatcher.instance.locale,
  );

  // 앱 시작시 로딩 페이지 표시 여부 결정
  final prefs = await SharedPreferences.getInstance();

  // 앱 시작시 로딩 페이지 표시 여부 결정
  final hasSeenLaunchVideo =
      prefs.getBool(AppConstant.hasSeenLaunchVideoKey) ?? false;

  // 로딩 페이지 표시
  if (hasSeenLaunchVideo) {
    FlutterNativeSplash.preserve(widgetsBinding: binding);
  } else {
    FlutterNativeSplash.remove();
  }

  await dotenv.load(fileName: '.env');
  await _initializeSupportedDateFormatting();
  _configureImageCache();
  api.SoiApiClient.instance.initialize();
  if (supportsFirebaseMessaging) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  KakaoSdk.init(nativeAppKey: dotenv.env[AppConstant.kakaoNativeAppKey]!);
  _configureErrorHandling();

  // AnalyticsService 인스턴스를 생성합니다.
  // 이 과정에서 Mixpanel SDK가 초기화되고, 앱의 플랫폼과 빌드 모드에 대한 슈퍼 프로퍼티가 등록됩니다.
  final analyticsService = await _createAnalyticsService();

  final userController = UserController();
  final audioController = AudioController();
  final didAutoLogin = await userController.tryAutoLogin();
  if (didAutoLogin) {
    await userController.refreshCurrentUser();
  }

  if (hasSeenLaunchVideo) {
    FlutterNativeSplash.remove();
  }

  runApp(
    EasyLocalization(
      supportedLocales: supportedLocales,
      path: 'assets/translations',
      saveLocale: false,
      fallbackLocale: englishLocale,
      startLocale: initialLocale,
      child: MyApp(
        hasSeenLaunchVideo: hasSeenLaunchVideo,
        preloadedUserController: userController,
        preloadedAudioController: audioController,
        analyticsService: analyticsService,
      ),
    ),
  );
}

/// 지원되는 날짜 형식을 초기화하는 함수입니다.
Future<void> _initializeSupportedDateFormatting() async {
  await Future.wait(
    supportedDateFormattingLocales.map(
      (locale) => initializeDateFormatting(locale, null),
    ),
  );
}

/// AnalyticsService 인스턴스를 생성합니다.
Future<AnalyticsService> _createAnalyticsService() async {
  final token = dotenv.env[AppConstant.mixpanelProjectToken]?.trim();
  if (token == null || token.isEmpty) {
    throw StateError('MIXPANEL_PROJECT_TOKEN is not configured.');
  }
  return AnalyticsService.create(token: token);
}

/// 앱 전체에서 사용되는 이미지 캐시 설정을 구성하는 함수입니다.
void _configureImageCache() {
  // Flutter의 전역 이미지 캐시 인스턴스입니다.
  final cache = PaintingBinding.instance.imageCache;

  // 디버그 모드에서는 더 많은 이미지를 캐시하도록 설정해서 개발 중에 이미지 로딩이 더 원활하게 느껴지도록 합니다.
  // 릴리즈 모드에서는 메모리 사용을 줄이기 위해 캐시 크기를 제한합니다.
  const maxItems = kDebugMode
      ? AppConstant.imageCacheMaxItemsDebug
      : AppConstant.imageCacheMaxItemsRelease;

  // 최대 캐시 크기를 MB 단위로 계산합니다.
  const maxBytes = maxItems * AppConstant.bytesPerMb;

  cache.maximumSize = maxItems; // 캐시할 최대 이미지 수를 설정합니다.
  cache.maximumSizeBytes = maxBytes; // 캐시할 최대 이미지 크기를 바이트 단위로 설정합니다.
}

/// 앱의 에러 핸들링을 구성하는 함수입니다.
/// FlutterError.onError와 PlatformDispatcher.instance.onError를 설정해서,
/// Flutter 프레임워크와 플랫폼 레벨에서 발생하는 에러를 처리할 수 있도록 합니다.
void _configureErrorHandling() {
  FlutterError.onError = FlutterError.presentError;
  PlatformDispatcher.instance.onError = (error, stack) => true;
}

/// 앱 전체를 세로 모드로 고정하는 함수입니다.
Future<void> _lockPortraitOrientation() {
  return SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
}

class MyApp extends StatefulWidget {
  final bool hasSeenLaunchVideo;
  final UserController preloadedUserController;
  final AudioController? preloadedAudioController;

  // AnalyticsService 인스턴스를 MyApp의 생성자로 전달받아서 멤버 변수로 저장합니다.
  final AnalyticsService analyticsService;

  const MyApp({
    super.key,
    required this.hasSeenLaunchVideo,
    required this.preloadedUserController,
    required this.preloadedAudioController,
    required this.analyticsService,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _appLinks = AppLinks();
  late final AudioController _audioController;
  late int _lastHandledSessionExpiredRevision;

  /// 앱 푸시 코디네이터 인스턴스를 멤버 변수로 저장합니다.
  /// 이렇게 하면 앱 전체에서 푸시 코디네이터의 상태를 유지할 수 있고, 필요할 때마다 접근할 수 있습니다.
  /// 앱 푸시 코디네이터: 푸시 알림과 관련된 모든 로직을 담당하는 클래스입니다. 사용자 인증 상태에 따른 토큰 등록/삭제, 푸시 알림 수신 시 처리 로직 등을 포함합니다.
  final _pushCoordinator = AppPushCoordinator.instance;

  StreamSubscription<Uri>? _linkSubscription;
  Uri? _lastHandledUri;
  DateTime? _lastHandledTime;

  // 마지막으로 AnalyticsService에 identify로 전달한 사용자 ID를 저장하는 변수입니다.
  // 사용자가 로그인하거나 로그아웃할 때 이 값을 업데이트해서 중복된 identify 호출을 방지하는 데 사용됩니다.
  int? _lastAnalyticsUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioController = widget.preloadedAudioController ?? AudioController();
    _lastHandledSessionExpiredRevision =
        widget.preloadedUserController.sessionExpiredRevision;

    // UserController의 상태가 변경될 때마다
    // _syncAnalyticsIdentity를 호출해서 AnalyticsService의 사용자 식별 정보를 최신 상태로 유지합니다.
    widget.preloadedUserController.addListener(_syncAnalyticsIdentity);

    // UserController의 상태가 변경될 때마다 _syncPushIdentity를 호출해서 AppPushCoordinator의 사용자 인증 상태를 최신 상태로 유지합니다.
    widget.preloadedUserController.addListener(_syncPushIdentity);
    widget.preloadedUserController.addListener(_handleSessionExpirationRoute);

    // 앱 시작 직후 권한이 이미 허용된 미디어 입력 리소스를 데워
    // 첫 카메라/녹음 진입 때의 네이티브 준비 지연을 줄입니다.
    _primeMediaInputResources();
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleIncomingUri,
      onError: (error) => debugPrint('딥링크 수신 실패: $error'),
    );
    _handleInitialLink();
    _syncAnalyticsIdentity();
    unawaited(_bindPushCoordinator()); // 앱 푸시 코디네이터를 초기화하고 사용자 인증 상태를 동기화합니다.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.preloadedUserController.removeListener(_syncAnalyticsIdentity);
    widget.preloadedUserController.removeListener(_syncPushIdentity);
    widget.preloadedUserController.removeListener(
      _handleSessionExpirationRoute,
    );
    _linkSubscription?.cancel();
    unawaited(_pushCoordinator.dispose());
    _audioController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lockPortraitOrientation();
    }
  }

  /// _primeMediaInputResources는 사진 라이브러리 권한 프리패치와 녹음기 워밍업을 순차로 걸어
  /// 앱 부트 직후 첫 미디어 입력 지연을 줄이되 새 권한 팝업 타이밍은 바꾸지 않습니다.
  void _primeMediaInputResources() {
    Future.microtask(() async {
      try {
        await PhotoManager.requestPermissionExtend();
      } catch (e) {
        debugPrint('Photo permission prefetch failed: $e');
      }

      await _audioController.primeRecorderIfPermitted();
    });
  }

  /// 백그라운드 API 요청에서 refresh가 실패해도 앱 루트가 한 번만 시작 화면으로 되돌아가게 합니다.
  void _handleSessionExpirationRoute() {
    final latestRevision =
        widget.preloadedUserController.sessionExpiredRevision;
    if (latestRevision == _lastHandledSessionExpiredRevision) {
      return;
    }
    _lastHandledSessionExpiredRevision = latestRevision;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = _navigatorKey.currentState;
      if (navigator == null) {
        return;
      }
      navigator.pushNamedAndRemoveUntil(AppRoute.start, (route) => false);
    });
  }

  /// 앱 푸시 코디네이터에서 사용자 인증 상태에 따른 토큰 등록/삭제 로직을 처리하는 함수입니다.
  Future<void> _bindPushCoordinator() async {
    // 푸시 코디네이터를 초기화할 때 navigatorKey를 전달해서, 푸시 알림 수신 시 네비게이션 처리를 할 수 있도록 합니다.
    await _pushCoordinator.initialize(navigatorKey: _navigatorKey);

    // 앱이 시작될 때 UserController의 현재 사용자 ID를 푸시 코디네이터에 동기화해서, 푸시 알림과 관련된 초기 설정이 올바르게 처리되도록 합니다.
    await _pushCoordinator.syncAuthenticatedUser(
      widget.preloadedUserController.currentUserId,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        _pushCoordinator.processPendingNavigation(),
      ); // 앱이 활성화된 후에 푸시 알림으로 인한 대기 중인 네비게이션이 있으면 처리합니다.
    });
  }

  Future<void> _handleInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) _handleIncomingUri(uri);
    } catch (e) {
      debugPrint('초기 딥링크 확인 실패: $e');
    }
  }

  /// AnalyticsService의 사용자 식별 정보를 UserController의 상태에 맞게 동기화하는 함수입니다.
  void _syncAnalyticsIdentity() {
    final currentUserId = widget.preloadedUserController.currentUserId;
    if (currentUserId == _lastAnalyticsUserId) {
      return;
    }

    // 이전에 identify로 전달했던 사용자 ID를 저장해둡니다.
    final previousUserId = _lastAnalyticsUserId;

    // 현재 사용자 ID로 업데이트합니다.
    _lastAnalyticsUserId = currentUserId;

    if (currentUserId == null) {
      if (previousUserId != null) {
        // 사용자가 로그아웃한 경우에는 AnalyticsService의 사용자 식별 정보를 초기화합니다.
        unawaited(widget.analyticsService.reset());
      }
      return;
    }

    // 사용자가 로그인한 경우에는 AnalyticsService에
    // identify로 사용자 ID를 전달해서 사용자를 식별합니다.
    unawaited(widget.analyticsService.identify(userId: currentUserId));
  }

  void _syncPushIdentity() {
    unawaited(
      _pushCoordinator.syncAuthenticatedUser(
        widget.preloadedUserController.currentUserId,
      ),
    );
  }

  void _handleIncomingUri(Uri uri) {
    final now = DateTime.now();
    final timeDiff = _lastHandledTime == null
        ? AppConstant.deepLinkInitTimeDiffSeconds
        : now.difference(_lastHandledTime!).inSeconds;

    if (_lastHandledUri == uri &&
        timeDiff < AppConstant.deepLinkDuplicationWindowSeconds) {
      return;
    }

    _lastHandledUri = uri;
    _lastHandledTime = now;

    final userId =
        uri.queryParameters[AppConstant.userIdQueryKey] ??
        uri.queryParameters[AppConstant.refUserIdQueryKey] ??
        uri.queryParameters[AppConstant.inviterIdQueryKey] ??
        '';
    final nickName =
        uri.queryParameters[AppConstant.nickNameQueryKey] ??
        uri.queryParameters[AppConstant.refNicknameQueryKey] ??
        uri.queryParameters[AppConstant.inviterQueryKey] ??
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
    if (currentUser == null || currentUser.phoneNumber.isEmpty) return;

    var requesterId = int.tryParse(userId);
    if (requesterId == null &&
        nickName.isNotEmpty &&
        nickName != AppConstant.inviteFriendFallbackName) {
      final inviterUser = await userController.getUserByNickname(nickName);
      requesterId = inviterUser?.id;
    }

    if (requesterId == null || requesterId == currentUser.id) return;

    await friendController.addFriend(
      requesterId: requesterId,
      receiverPhoneNum: currentUser.phoneNumber,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: buildAppProviders(
        widget.preloadedUserController,
        widget.analyticsService,
        _audioController,
      ),
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        child: MaterialApp(
          navigatorKey: _navigatorKey,
          initialRoute: widget.hasSeenLaunchVideo
              ? AppRoute.root
              : AppRoute.launchVideo,
          navigatorObservers: [appRouteObserver],
          debugShowCheckedModeBanner: false,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          builder: (context, child) => buildAppContainer(context, child!),
          routes: buildAppRoutes(),
          theme: ThemeData(iconTheme: const IconThemeData(color: Colors.white)),
        ),
      ),
    );
  }
}
