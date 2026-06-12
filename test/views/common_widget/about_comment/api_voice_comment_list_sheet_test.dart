import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soi/api/controller/audio_controller.dart';
import 'package:soi/api/controller/comment_controller.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/api/models/comment.dart';
import 'package:soi/api/models/comment_creation_result.dart';
import 'package:soi/api/models/user.dart';
import 'package:soi/api/services/comment_service.dart';
import 'package:soi/api/services/user_service.dart';
import 'package:soi/views/common_widget/comment/comment_list_bottom_sheet.dart';
import 'package:soi_api_client/api.dart';

/// 댓글 시트 테스트에 필요한 번역 키만 메모리에서 제공합니다.
class _InMemoryAssetLoader extends AssetLoader {
  const _InMemoryAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    return {
      'common': {
        'login_required': '로그인이 필요합니다.',
        'user_info_unavailable': '사용자 정보를 불러올 수 없습니다.',
        'cancel': '취소',
        'report': '신고',
        'block': '차단',
        'report_submit_success': '신고가 접수되었습니다.',
      },
      'comments': {
        'title': '댓글',
        'reply_action': '답장 달기',
        'replying': '답글 작성 중',
        'replying_to': '{name}에게 답글 남기는 중',
        'add_reply': '답글 입력',
        'reply_to': '{name}에게 답글 입력',
        'view_more_replies': '+ 답글 {count}개 더 보기',
        'hide_replies': '답글 숨기기',
        'add_comment': '댓글을 입력하세요',
        'empty': '댓글이 없습니다.',
        'save_failed': '댓글 저장에 실패했습니다.',
        'delete': '댓글 삭제',
        'delete_unavailable': '삭제할 수 없는 댓글입니다.',
        'delete_success': '댓글이 삭제되었습니다.',
        'delete_failed': '댓글 삭제에 실패했습니다.',
        'delete_error': '댓글 삭제 중 오류가 발생했습니다.',
      },
    };
  }
}

class _NoopAuthApi extends AuthControllerApi {}

class _NoopUserApi extends UserAPIApi {}

class _NoopCommentApi extends CommentAPIApi {}

/// 댓글 시트가 현재 로그인 사용자를 읽을 수 있도록 고정 사용자 상태를 제공합니다.
class _FakeUserController extends UserController {
  _FakeUserController({required User currentUser})
    : super(
        userService: UserService(
          authApi: _NoopAuthApi(),
          userApi: _NoopUserApi(),
          onAuthTokenIssued: (_) {},
          onAuthTokenCleared: () {},
        ),
      ) {
    setCurrentUser(currentUser);
  }
}

/// 댓글 시트가 보내는 저장 payload를 캡처하고, 저장 성공 응답을 흉내 냅니다.
class _CapturingCommentController extends CommentController {
  _CapturingCommentController({required this.createdComment})
    : super(commentService: CommentService(commentApi: _NoopCommentApi()));

  final Comment createdComment;
  int? capturedPostId;
  int? capturedUserId;
  int? capturedParentId;
  int? capturedReplyUserId;
  String? capturedText;
  CommentType? capturedType;
  int? deletedCommentId;
  List<Comment>? replacedCacheComments;

  @override
  /// 시트가 저장 요청에 사용하는 답글 payload를 캡처하고 성공 응답을 돌려줍니다.
  Future<CommentCreationResult> createComment({
    required int postId,
    required int userId,
    int? emojiId,
    int? parentId,
    int? replyUserId,
    String? text,
    String? audioKey,
    String? fileKey,
    String? waveformData,
    int? duration,
    double? locationX,
    double? locationY,
    CommentType? type,
  }) async {
    capturedPostId = postId;
    capturedUserId = userId;
    capturedParentId = parentId;
    capturedReplyUserId = replyUserId;
    capturedText = text;
    capturedType = type;
    return CommentCreationResult(success: true, comment: createdComment);
  }

  @override
  Future<bool> deleteComment(int commentId) async {
    deletedCommentId = commentId;
    return true;
  }

  @override
  void replaceCommentsCache({
    required int postId,
    required List<Comment> comments,
  }) {
    replacedCacheComments = List<Comment>.from(comments);
  }
}

/// 댓글 시트 위젯 테스트에 필요한 로컬라이제이션과 Provider 트리를 구성합니다.
Widget _buildHarness({
  required Widget child,
  required UserController userController,
  required CommentController commentController,
}) {
  return EasyLocalization(
    supportedLocales: const [Locale('ko')],
    path: 'assets/translations',
    fallbackLocale: const Locale('ko'),
    assetLoader: const _InMemoryAssetLoader(),
    child: Builder(
      builder: (easyCtx) => ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (_, __) => MultiProvider(
          providers: [
            ChangeNotifierProvider<UserController>.value(value: userController),
            ChangeNotifierProvider<CommentController>.value(
              value: commentController,
            ),
            ChangeNotifierProvider<AudioController>(
              create: (_) => AudioController(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: easyCtx.localizationDelegates,
            supportedLocales: easyCtx.supportedLocales,
            locale: easyCtx.locale,
            home: Scaffold(backgroundColor: Colors.black, body: child),
          ),
        ),
      ),
    ),
  );
}

/// 댓글 시트가 실제 화면 크기와 비슷한 레이아웃으로 렌더링되도록 테스트 surface를 맞춥니다.
Future<void> _setPhoneSurface(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(393, 852);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets(
    'replying to a reply saves under the root parent comment thread',
    (tester) async {
      await _setPhoneSurface(tester);

      final currentUser = User(
        id: 999,
        userId: 'me',
        name: '테스트 유저',
        phoneNumber: '01099999999',
      );
      final parentComment = Comment(
        id: 100,
        userId: 40,
        nickname: 'me',
        text: '원댓글',
        replyCommentCount: 1,
        createdAt: DateTime(2026, 3, 1),
        type: CommentType.text,
      );
      final replyComment = Comment(
        id: 200,
        threadParentId: 100,
        userId: 50,
        nickname: 'me',
        replyUserName: 'me',
        text: '첫 번째 대댓글',
        createdAt: DateTime(2026, 3, 2),
        type: CommentType.reply,
      );
      final commentController = _CapturingCommentController(
        createdComment: Comment(
          id: 300,
          userId: currentUser.id,
          nickname: currentUser.userId,
          text: '대댓글의 답글',
          createdAt: DateTime(2026, 3, 3),
          type: CommentType.reply,
        ),
      );

      List<Comment>? updatedComments;

      await tester.pumpWidget(
        _buildHarness(
          userController: _FakeUserController(currentUser: currentUser),
          commentController: commentController,
          child: ApiVoiceCommentListSheet(
            postId: 77,
            initialComments: [parentComment, replyComment],
            selectedCommentId: 'comment_${replyComment.id}',
            onCommentsUpdated: (comments) => updatedComments = comments,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('첫 번째 대댓글'), findsOneWidget);

      await tester.tap(find.text('답장 달기').at(1));
      await tester.pumpAndSettle();

      expect(find.text('me에게 답글 남기는 중'), findsOneWidget);

      await tester.tap(find.text('답글 입력'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '대댓글의 답글');
      await tester.pumpAndSettle();

      expect(find.text('대댓글의 답글'), findsOneWidget);

      await tester.tap(find.byType(IconButton).last);
      await tester.pumpAndSettle();

      expect(commentController.capturedPostId, 77);
      expect(commentController.capturedUserId, currentUser.id);
      expect(commentController.capturedParentId, parentComment.id);
      expect(commentController.capturedReplyUserId, replyComment.userId);
      expect(commentController.capturedText, '대댓글의 답글');
      expect(commentController.capturedType, CommentType.reply);

      expect(updatedComments, isNotNull);
      expect(updatedComments!.map((comment) => comment.id), [100, 200, 300]);
      expect(updatedComments![2].text, '대댓글의 답글');
      expect(updatedComments![2].threadParentId, parentComment.id);
      expect(updatedComments![2].id, 300);
      expect(find.text('대댓글의 답글'), findsOneWidget);
    },
  );

  testWidgets('hydrates full thread after opening with partial comments', (
    tester,
  ) async {
    await _setPhoneSurface(tester);

    final currentUser = User(
      id: 999,
      userId: 'me',
      name: '테스트 유저',
      phoneNumber: '01099999999',
    );
    final parentComment = Comment(
      id: 100,
      userId: 40,
      nickname: 'writer',
      text: '원댓글',
      replyCommentCount: 1,
      createdAt: DateTime(2026, 3, 1),
      type: CommentType.text,
      locationX: 0.2,
      locationY: 0.3,
    );
    final replyComment = Comment(
      id: 200,
      threadParentId: 100,
      userId: 50,
      nickname: 'reply',
      replyUserName: 'writer',
      text: '대댓글',
      createdAt: DateTime(2026, 3, 2),
      type: CommentType.reply,
    );
    final commentController = _CapturingCommentController(
      createdComment: replyComment,
    );

    List<Comment>? updatedComments;

    await tester.pumpWidget(
      _buildHarness(
        userController: _FakeUserController(currentUser: currentUser),
        commentController: commentController,
        child: ApiVoiceCommentListSheet(
          postId: 77,
          initialComments: [parentComment],
          selectedCommentId: 'reply_${replyComment.id}',
          loadFullComments: (_) async {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return [parentComment, replyComment];
          },
          onCommentsUpdated: (comments) => updatedComments = comments,
        ),
      ),
    );

    await tester.pump();
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('원댓글'), findsOneWidget);
    expect(find.text('대댓글'), findsNothing);

    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('대댓글'), findsOneWidget);
    expect(updatedComments?.map((comment) => comment.id), [100, 200]);
  });

  testWidgets(
    'long press expands inline action drawer and only one stays open',
    (tester) async {
      await _setPhoneSurface(tester);

      final currentUser = User(
        id: 999,
        userId: 'me',
        name: '테스트 유저',
        phoneNumber: '01099999999',
      );
      final myComment = Comment(
        id: 100,
        userId: currentUser.id,
        nickname: currentUser.userId,
        text: '내 댓글',
        createdAt: DateTime(2026, 3, 1),
        type: CommentType.text,
      );
      final otherComment = Comment(
        id: 200,
        userId: 123,
        nickname: 'other',
        text: '남의 댓글',
        createdAt: DateTime(2026, 3, 2),
        type: CommentType.text,
      );

      await tester.pumpWidget(
        _buildHarness(
          userController: _FakeUserController(currentUser: currentUser),
          commentController: _CapturingCommentController(
            createdComment: myComment,
          ),
          child: ApiVoiceCommentListSheet(
            postId: 77,
            initialComments: [myComment, otherComment],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('내 댓글'));
      await tester.pumpAndSettle();

      expect(find.text('댓글 삭제'), findsOneWidget);
      expect(find.text('신고'), findsNothing);
      expect(find.text('차단'), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsNothing);

      await tester.longPress(find.text('남의 댓글'));
      await tester.pumpAndSettle();

      expect(find.text('댓글 삭제'), findsNothing);
      expect(find.text('신고'), findsOneWidget);
      expect(find.text('차단'), findsOneWidget);
    },
  );

  testWidgets('tapping outside closes expanded inline action drawer', (
    tester,
  ) async {
    await _setPhoneSurface(tester);

    final currentUser = User(
      id: 999,
      userId: 'me',
      name: '테스트 유저',
      phoneNumber: '01099999999',
    );
    final comment = Comment(
      id: 100,
      userId: currentUser.id,
      nickname: currentUser.userId,
      text: '내 댓글',
      createdAt: DateTime(2026, 3, 1),
      type: CommentType.text,
    );

    await tester.pumpWidget(
      _buildHarness(
        userController: _FakeUserController(currentUser: currentUser),
        commentController: _CapturingCommentController(createdComment: comment),
        child: ApiVoiceCommentListSheet(postId: 77, initialComments: [comment]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('내 댓글'));
    await tester.pumpAndSettle();
    expect(find.text('댓글 삭제'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('댓글 삭제'), findsNothing);
  });

  testWidgets('deleting my comment removes it from sheet and syncs cache', (
    tester,
  ) async {
    await _setPhoneSurface(tester);

    final currentUser = User(
      id: 999,
      userId: 'me',
      name: '테스트 유저',
      phoneNumber: '01099999999',
    );
    final myComment = Comment(
      id: 100,
      userId: currentUser.id,
      nickname: currentUser.userId,
      text: '삭제할 댓글',
      createdAt: DateTime(2026, 3, 1),
      type: CommentType.text,
    );
    final otherComment = Comment(
      id: 200,
      userId: 123,
      nickname: 'other',
      text: '남는 댓글',
      createdAt: DateTime(2026, 3, 2),
      type: CommentType.text,
    );
    final commentController = _CapturingCommentController(
      createdComment: myComment,
    );
    List<Comment>? updatedComments;

    await tester.pumpWidget(
      _buildHarness(
        userController: _FakeUserController(currentUser: currentUser),
        commentController: commentController,
        child: ApiVoiceCommentListSheet(
          postId: 77,
          initialComments: [myComment, otherComment],
          onCommentsUpdated: (comments) => updatedComments = comments,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('삭제할 댓글'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('댓글 삭제'));
    await tester.pumpAndSettle();

    expect(commentController.deletedCommentId, 100);
    expect(find.text('삭제할 댓글'), findsNothing);
    expect(find.text('남는 댓글'), findsOneWidget);
    expect(updatedComments?.map((comment) => comment.id), [200]);
    expect(
      commentController.replacedCacheComments?.map((comment) => comment.id),
      [200],
    );
  });
}
