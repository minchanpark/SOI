import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tagging_core/tagging_core.dart';
import 'package:soi/api/controller/comment_controller.dart';
import 'package:soi/api/controller/media_controller.dart';
import 'package:soi/api/models/post.dart';
import 'package:soi/api/services/comment_service.dart';
import 'package:soi/api/services/media_service.dart';
import 'package:soi/features/tagging_soi/tagging_soi.dart';
import 'package:soi/views/common_widget/photo/photo_display_widget.dart';
import 'package:soi_api_client/api.dart';

class _NoopCommentApi extends CommentAPIApi {}

class _NoopMediaApi extends APIApi {}

/// 포토 디스플레이 테스트에서 댓글 캐시 조회만 제공하는 최소 댓글 컨트롤러입니다.
class _FakeCommentController extends CommentController {
  _FakeCommentController()
    : super(commentService: CommentService(commentApi: _NoopCommentApi()));
}

/// 포토 디스플레이 테스트에서 presigned URL 응답을 제어하는 미디어 컨트롤러입니다.
class _FakeMediaController extends MediaController {
  _FakeMediaController({
    this.urls = const <String, String?>{},
    this.delay = Duration.zero,
  }) : super(mediaService: MediaService(mediaApi: _NoopMediaApi()));

  final Map<String, String?> urls;
  final Duration delay;

  @override
  String? peekPresignedUrl(String key) => null;

  @override
  Future<String?> getPresignedUrl(String key) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return urls[key];
  }
}

/// 미디어와 캡션 아바타가 모두 보이는 이미지 post를 테스트용으로 생성합니다.
Post _buildPost({
  String? postFileUrl,
  String? postFileKey,
  String? profileImageUrl,
  String? profileImageKey,
  bool? isFromGallery,
}) {
  return Post(
    id: 1,
    nickName: 'tester',
    content: 'caption',
    postFileKey: postFileKey,
    postFileUrl: postFileUrl,
    userProfileImageKey: profileImageKey,
    userProfileImageUrl: profileImageUrl,
    createdAt: DateTime(2024, 1, 1),
    postType: PostType.multiMedia,
    isFromGallery: isFromGallery,
  );
}

/// ApiPhotoDisplayWidget을 MediaController provider와 ScreenUtil 초기화가 포함된 최소 환경으로 감쌉니다.
Widget _buildHarness({
  required MediaController mediaController,
  required Post post,
}) {
  final commentController = _FakeCommentController();
  final taggingController = SoiTaggingController(
    commentController: commentController,
    coreController: TaggingSessionController(
      queryPort: SoiTaggingQueryPort(commentController),
    ),
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CommentController>.value(value: commentController),
      ChangeNotifierProvider<MediaController>.value(value: mediaController),
    ],
    child: ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: ApiPhotoDisplayWidget(
              post: post,
              categoryId: 1,
              categoryName: 'category',
              taggingController: taggingController,
              onProfileImageDragged: (_, __) {},
              onToggleAudio: (_) {},
              pendingVoiceComments: const <TagScopeId, TagPendingMarker>{},
            ),
          ),
        ),
      ),
    ),
  );
}

CachedNetworkImage _findNetworkImage(
  WidgetTester tester, {
  required String cacheKey,
}) {
  return tester
      .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
      .singleWhere((image) => image.cacheKey == cacheKey);
}

void main() {
  testWidgets(
    'uses post and profile URLs immediately while keeping keys as cache keys',
    (tester) async {
      const postKey = 'posts/photo.jpg';
      const postUrl = 'https://example.com/posts/photo.jpg';
      const profileKey = 'profiles/me.jpg';
      const profileUrl = 'https://example.com/profiles/me.jpg';

      await tester.pumpWidget(
        _buildHarness(
          mediaController: _FakeMediaController(),
          post: _buildPost(
            postFileUrl: postUrl,
            postFileKey: postKey,
            profileImageUrl: profileUrl,
            profileImageKey: profileKey,
          ),
        ),
      );
      await tester.pump();

      expect(_findNetworkImage(tester, cacheKey: postKey).imageUrl, postUrl);
      expect(
        _findNetworkImage(tester, cacheKey: profileKey).imageUrl,
        profileUrl,
      );
    },
  );

  testWidgets(
    'resolves post and profile URLs from keys when immediate URLs are missing',
    (tester) async {
      const postKey = 'posts/photo.jpg';
      const postUrl = 'https://example.com/posts/photo.jpg';
      const profileKey = 'profiles/me.jpg';
      const profileUrl = 'https://example.com/profiles/me.jpg';

      await tester.pumpWidget(
        _buildHarness(
          mediaController: _FakeMediaController(
            urls: const <String, String?>{
              postKey: postUrl,
              profileKey: profileUrl,
            },
            delay: const Duration(milliseconds: 20),
          ),
          post: _buildPost(postFileKey: postKey, profileImageKey: profileKey),
        ),
      );
      await tester.pump();

      final initialImages = tester.widgetList<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(
        initialImages.where((image) => image.cacheKey == postKey),
        isEmpty,
      );
      expect(
        initialImages.where((image) => image.cacheKey == profileKey),
        isEmpty,
      );

      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump();

      expect(_findNetworkImage(tester, cacheKey: postKey).imageUrl, postUrl);
      expect(
        _findNetworkImage(tester, cacheKey: profileKey).imageUrl,
        profileUrl,
      );
    },
  );

  testWidgets('uses contain fit for gallery uploads and cover fit otherwise', (
    tester,
  ) async {
    const postKey = 'posts/photo.jpg';
    const postUrl = 'https://example.com/posts/photo.jpg';

    await tester.pumpWidget(
      _buildHarness(
        mediaController: _FakeMediaController(),
        post: _buildPost(
          postFileUrl: postUrl,
          postFileKey: postKey,
          isFromGallery: true,
        ),
      ),
    );
    await tester.pump();

    expect(_findNetworkImage(tester, cacheKey: postKey).fit, BoxFit.contain);

    await tester.pumpWidget(
      _buildHarness(
        mediaController: _FakeMediaController(),
        post: _buildPost(
          postFileUrl: postUrl,
          postFileKey: postKey,
          isFromGallery: false,
        ),
      ),
    );
    await tester.pump();

    expect(_findNetworkImage(tester, cacheKey: postKey).fit, BoxFit.cover);
  });
}
