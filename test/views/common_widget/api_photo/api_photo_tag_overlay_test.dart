import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/models/comment.dart';
import 'package:soi/api/models/post.dart';
import 'package:soi/views/common_widget/about_comment_version_2/comment_media_tag_preview_widget.dart';
import 'package:soi/views/common_widget/about_comment_version_1/api_voice_comment_list_sheet.dart';
import 'package:soi/views/common_widget/about_comment_version_1/pending_api_voice_comment.dart';
import 'package:soi/views/common_widget/api_photo/api_photo_card_widget.dart';
import 'package:soi/views/common_widget/api_photo/api_photo_display_widget.dart';
import 'package:soi/views/common_widget/api_photo/tag_pointer.dart';

void main() {
  Widget buildHarness({required List<Comment> comments}) {
    final post = Post(
      id: 100,
      nickName: 'tester',
      postFileKey: 'post.jpg',
      postFileUrl: 'https://example.com/post.jpg',
      createdAt: DateTime(2024, 1, 1),
    );

    return ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, child) => MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.only(top: 120),
            child: child!,
          ),
        ),
      ),
      child: ApiPhotoCardWidget(
        post: post,
        categoryName: 'test',
        categoryId: 1,
        index: 0,
        isOwner: true,
        postComments: <int, List<Comment>>{post.id: comments},
        pendingCommentDrafts: <int, PendingApiCommentDraft>{},
        pendingVoiceComments: const <int, PendingApiCommentMarker>{},
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

      await tester.pump(const Duration(milliseconds: 120));

      final displayTop = tester
          .getTopLeft(find.byType(ApiPhotoDisplayWidget))
          .dy;
      final overlayBubbleTop = tester
          .getTopLeft(
            find.ancestor(
              of: find.byType(CommentMediaTagPreviewWidget),
              matching: find.byType(TagBubble),
            ),
          )
          .dy;

      expect(overlayBubbleTop, lessThan(displayTop));
    },
  );

  testWidgets('tapping expanded overlay collapses it', (tester) async {
    await tester.pumpWidget(buildHarness(comments: [mediaComment(y: 0.3)]));
    await tester.pump();

    await tester.tap(find.byType(TagBubble));
    await tester.pump();

    expect(find.byType(CommentMediaTagPreviewWidget), findsOneWidget);

    await tester.tap(find.byType(CommentMediaTagPreviewWidget));
    await tester.pump();

    expect(find.byType(CommentMediaTagPreviewWidget), findsNothing);
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
    },
  );
}
