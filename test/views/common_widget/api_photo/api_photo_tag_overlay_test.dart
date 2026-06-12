import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tagging_core/tagging_core.dart';
import 'package:tagging_flutter/tagging_flutter.dart';
import 'package:soi/api/controller/comment_controller.dart';
import 'package:soi/api/controller/media_controller.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/api/models/comment.dart';
import 'package:soi/api/models/post.dart';
import 'package:soi/api/models/user.dart';
import 'package:soi/api/services/comment_service.dart';
import 'package:soi/api/services/media_service.dart';
import 'package:soi/api/services/user_service.dart';
import 'package:soi/features/tagging_soi/tagging_soi.dart';
import 'package:soi/views/common_widget/comment/comment_media_tag_preview_widget.dart';
import 'package:soi/views/common_widget/comment/comment_list_bottom_sheet.dart';
import 'package:soi/views/common_widget/photo/photo_card_widget.dart';
import 'package:soi/views/common_widget/photo/photo_display_widget.dart';
import 'package:soi_api_client/api.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _InMemoryAssetLoader extends AssetLoader {
  const _InMemoryAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    return {
      'common': {
        'login_required': '로그인이 필요합니다.',
        'user_info_unavailable': '사용자 정보를 불러올 수 없습니다.',
      },
      'comments': {
        'title': '댓글',
        'add_comment': '댓글을 입력하세요',
        'empty': '댓글이 없습니다.',
        'reply_action': '답장 달기',
      },
    };
  }
}

class _NoopAuthApi extends AuthControllerApi {}

class _NoopCommentApi extends CommentAPIApi {}

class _NoopUserApi extends UserAPIApi {}

class _NoopMediaApi extends APIApi {}

/// 오버레이가 현재 사용자 selector를 통과하는지 확인하기 위한 테스트용 사용자 컨트롤러입니다.
class _FakeUserController extends UserController {
  _FakeUserController({User? user})
    : super(
        userService: UserService(
          authApi: _NoopAuthApi(),
          userApi: _NoopUserApi(),
          onAuthTokenIssued: (_) {},
          onAuthTokenCleared: () {},
        ),
      ) {
    setCurrentUser(
      user ??
          const User(
            id: 1,
            userId: 'tester',
            name: '테스터',
            phoneNumber: '01000000000',
          ),
    );
  }
}

/// 태그 오버레이에서 key 기반 프로필 URL 해석을 제어하는 테스트용 미디어 컨트롤러입니다.
class _FakeMediaController extends MediaController {
  _FakeMediaController()
    : super(mediaService: MediaService(mediaApi: _NoopMediaApi()));

  final Map<String, String?> urls = const <String, String?>{};

  @override
  String? peekPresignedUrl(String key) => urls[key];

  @override
  Future<String?> getPresignedUrl(String key) async => urls[key];

  @override
  Future<List<String>> getPresignedUrls(List<String> keys) async {
    return keys.map((key) => urls[key] ?? '').toList(growable: false);
  }
}

/// 오버레이 경로에서는 저장 로직이 호출되면 안 되므로 즉시 실패시키는 mutation port입니다.
class _NoopTaggingMutationPort implements TagMutationPort {
  const _NoopTaggingMutationPort();

  @override
  Future<TagMutationResult> save({
    required TagSaveRequest request,
    void Function(double progress)? onProgress,
  }) {
    throw UnimplementedError('save should not run in overlay tests');
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDownAll(() {
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
  });

  /// ApiPhotoCardWidget이 오버레이 태그만 검증할 수 있도록 필요한 provider를 모두 감싼 하네스입니다.
  Widget buildHarness({
    required List<Comment> comments,
    UserController? userController,
    MediaController? mediaController,
  }) {
    final post = Post(
      id: 100,
      nickName: 'tester',
      postFileKey: 'post.jpg',
      postFileUrl: 'https://example.com/post.jpg',
      createdAt: DateTime(2024, 1, 1),
    );
    final effectiveUserController = userController ?? _FakeUserController();
    final effectiveMediaController = mediaController ?? _FakeMediaController();
    final effectiveCommentController = CommentController(
      commentService: CommentService(commentApi: _NoopCommentApi()),
    );
    effectiveCommentController.replaceCommentsCache(
      postId: post.id,
      comments: comments,
    );
    effectiveCommentController.replaceTagCommentsCache(
      postId: post.id,
      comments: comments,
    );
    final taggingController = SoiTaggingController(
      commentController: effectiveCommentController,
      coreController: TaggingSessionController(
        queryPort: SoiTaggingQueryPort(effectiveCommentController),
      ),
    );

    return ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, child) => EasyLocalization(
        supportedLocales: const [Locale('ko')],
        path: 'assets/translations',
        fallbackLocale: const Locale('ko'),
        assetLoader: const _InMemoryAssetLoader(),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<MediaController>.value(
              value: effectiveMediaController,
            ),
            ChangeNotifierProvider<UserController>.value(
              value: effectiveUserController,
            ),
            ChangeNotifierProvider<CommentController>.value(
              value: effectiveCommentController,
            ),
          ],
          child: Builder(
            builder: (easyCtx) => MaterialApp(
              localizationsDelegates: easyCtx.localizationDelegates,
              supportedLocales: easyCtx.supportedLocales,
              locale: easyCtx.locale,
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.only(top: 120),
                  child: child!,
                ),
              ),
            ),
          ),
        ),
      ),
      child: ApiPhotoCardWidget(
        post: post,
        categoryName: 'test',
        categoryId: 1,
        index: 0,
        isOwner: true,
        displayOnly: true,
        pendingCommentDrafts: const <TagScopeId, TagDraft>{},
        pendingVoiceComments: const <TagScopeId, TagPendingMarker>{},
        taggingController: taggingController,
        saveDelegate: const _NoopTaggingMutationPort(),
        onToggleAudio: (_) {},
        onTextCommentCompleted: (_, __) {},
        onAudioCommentCompleted: (_, __, ___, ____) async {},
        onMediaCommentCompleted: (_, __, ___) async {},
        onProfileImageDragged: (_, __) {},
        onCommentSaveProgress: (_, __) {},
        onCommentSaveSuccess: (_, __) {},
        onCommentSaveFailure: (_, __) {},
        onDeletePressed: () {},
      ),
    );
  }

  Comment mediaComment({required double y}) {
    return Comment(
      id: 200,
      userId: 10,
      nickname: 'commenter',
      userProfileUrl: 'https://example.com/profile.jpg',
      fileUrl: 'https://example.com/comment.jpg',
      locationX: 0.5,
      locationY: y,
      type: CommentType.photo,
    );
  }

  testWidgets(
    'creates root overlay immediately and expands beyond media bounds',
    (tester) async {
      await tester.pumpWidget(buildHarness(comments: [mediaComment(y: 0.02)]));
      await tester.pump();

      expect(find.byType(TagBubble), findsOneWidget);
      expect(find.byType(CommentMediaTagPreviewWidget), findsNothing);

      await tester.tap(find.byType(TagBubble));
      await tester.pump();

      expect(find.byType(CommentMediaTagPreviewWidget), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ApiPhotoDisplayWidget),
          matching: find.byType(CommentMediaTagPreviewWidget),
        ),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'uses the current user profile image for matching comment avatars',
    (tester) async {
      const currentProfileKey = 'profiles/current.jpg';
      const currentProfileUrl = 'https://example.com/profiles/current.jpg';

      final currentUserController = _FakeUserController(
        user: const User(
          id: 1,
          userId: 'tester',
          name: '테스터',
          profileImageKey: currentProfileKey,
          profileImageUrl: currentProfileUrl,
          phoneNumber: '01000000000',
        ),
      );

      final matchingComment = Comment(
        id: 300,
        userId: 1,
        nickname: 'tester',
        userProfileUrl: 'https://example.com/profiles/fallback.jpg',
        userProfileKey: 'profiles/fallback.jpg',
        locationX: 0.5,
        locationY: 0.2,
        type: CommentType.photo,
      );

      await tester.pumpWidget(
        buildHarness(
          comments: [matchingComment],
          userController: currentUserController,
        ),
      );
      await tester.pump();

      final avatarImage = tester
          .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .singleWhere((image) => image.cacheKey == currentProfileKey);

      expect(avatarImage.imageUrl, currentProfileUrl);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('tapping expanded overlay collapses it', (tester) async {
    await tester.pumpWidget(buildHarness(comments: [mediaComment(y: 0.3)]));
    await tester.pump();

    await tester.tap(find.byType(TagBubble));
    await tester.pump();

    expect(find.byType(CommentMediaTagPreviewWidget), findsOneWidget);

    final previewCenter = tester.getCenter(
      find.byType(CommentMediaTagPreviewWidget),
      warnIfMissed: false,
    );
    await tester.tapAt(previewCenter);
    await tester.pump();

    expect(find.byType(CommentMediaTagPreviewWidget), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('outside tap dismisses expanded overlay', (tester) async {
    await tester.pumpWidget(buildHarness(comments: [mediaComment(y: 0.25)]));
    await tester.pump();

    await tester.tap(find.byType(TagBubble));
    await tester.pump();

    expect(find.byType(CommentMediaTagPreviewWidget), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await tester.pump();

    expect(find.byType(CommentMediaTagPreviewWidget), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'media-preview-unavailable tag opens comment sheet instead of overlay',
    (tester) async {
      final unavailableComment = Comment(
        id: 201,
        userId: 11,
        nickname: 'commenter',
        userProfileUrl: 'https://example.com/profile.jpg',
        locationX: 0.5,
        locationY: 0.3,
        type: CommentType.photo,
      );

      await tester.pumpWidget(buildHarness(comments: [unavailableComment]));
      await tester.pump();

      await tester.tap(find.byType(TagBubble));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(CommentMediaTagPreviewWidget), findsNothing);
      expect(find.byType(ApiVoiceCommentListSheet), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
