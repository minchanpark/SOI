import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/controller/comment_controller.dart';
import 'package:soi/api/models/comment.dart';
import 'package:soi/api/models/comment_creation_result.dart';
import 'package:soi/api/services/comment_service.dart';
import 'package:soi_api_client/api.dart';

class _NoopCommentApi extends CommentAPIApi {}

typedef _CreateCommentHandler =
    Future<CommentCreationResult> Function({
      required int postId,
      required int userId,
      int? emojiId,
      int? parentId,
      int? replyUserId,
      String? text,
      String? audioFileKey,
      String? fileKey,
      String? waveformData,
      int? duration,
      double? locationX,
      double? locationY,
      CommentType? type,
    });

typedef _GetCommentsHandler =
    Future<List<Comment>> Function({required int postId});
typedef _GetTagCommentsHandler =
    Future<List<Comment>> Function({required int postId});
typedef _GetParentCommentsHandler =
    Future<({List<Comment> comments, bool hasMore})> Function({
      required int postId,
      required int page,
    });
typedef _GetChildCommentsHandler =
    Future<({List<Comment> comments, bool hasMore})> Function({
      required int parentCommentId,
      required int page,
    });

class _FakeCommentService extends CommentService {
  _FakeCommentService({
    required this.onCreate,
    this.onGetByUserId,
    this.onGetComments,
    this.onGetTagComments,
    this.onGetParentComments,
    this.onGetChildComments,
  }) : super(commentApi: _NoopCommentApi());

  final _CreateCommentHandler onCreate;
  final _GetCommentsHandler? onGetComments;
  final _GetTagCommentsHandler? onGetTagComments;
  final _GetParentCommentsHandler? onGetParentComments;
  final _GetChildCommentsHandler? onGetChildComments;
  final Future<({List<Comment> comments, bool hasMore})> Function({
    required int userId,
    required int page,
  })?
  onGetByUserId;

  @override
  Future<CommentCreationResult> createComment({
    required int postId,
    required int userId,
    int? emojiId,
    int? parentId,
    int? replyUserId,
    String? text,
    String? audioFileKey,
    String? fileKey,
    String? waveformData,
    int? duration,
    double? locationX,
    double? locationY,
    CommentType? type,
  }) {
    return onCreate(
      postId: postId,
      userId: userId,
      emojiId: emojiId,
      parentId: parentId,
      replyUserId: replyUserId,
      text: text,
      audioFileKey: audioFileKey,
      fileKey: fileKey,
      waveformData: waveformData,
      duration: duration,
      locationX: locationX,
      locationY: locationY,
      type: type,
    );
  }

  @override
  Future<List<Comment>> getComments({required int postId}) {
    final handler = onGetComments;
    if (handler == null) {
      throw UnsupportedError('Should not call getComments');
    }
    return handler(postId: postId);
  }

  @override
  Future<List<Comment>> getTagComments({required int postId}) {
    final handler = onGetTagComments;
    if (handler == null) {
      throw UnsupportedError('Should not call getTagComments');
    }
    return handler(postId: postId);
  }

  @override
  /// 컨트롤러가 원댓글 조회 파라미터를 서비스로 그대로 넘기는지 검증합니다.
  Future<({List<Comment> comments, bool hasMore})> getParentComments({
    required int postId,
    int page = 0,
  }) {
    final handler = onGetParentComments;
    if (handler == null) {
      throw UnsupportedError('Should not call getParentComments');
    }
    return handler(postId: postId, page: page);
  }

  @override
  /// 컨트롤러가 대댓글 조회 파라미터를 서비스로 그대로 넘기는지 검증합니다.
  Future<({List<Comment> comments, bool hasMore})> getChildComments({
    required int parentCommentId,
    int page = 0,
  }) {
    final handler = onGetChildComments;
    if (handler == null) {
      throw UnsupportedError('Should not call getChildComments');
    }
    return handler(parentCommentId: parentCommentId, page: page);
  }

  @override
  Future<CommentCreationResult> createTextComment({
    required int postId,
    required int userId,
    required String text,
    required double locationX,
    required double locationY,
  }) async {
    throw UnsupportedError('Should route through createComment');
  }

  @override
  Future<CommentCreationResult> createAudioComment({
    required int postId,
    required int userId,
    required String audioFileKey,
    required String waveformData,
    required int duration,
    required double locationX,
    required double locationY,
  }) async {
    throw UnsupportedError('Should route through createComment');
  }

  @override
  Future<({List<Comment> comments, bool hasMore})> getCommentsByUserId({
    required int userId,
    int page = 0,
  }) {
    final handler = onGetByUserId;
    if (handler == null) {
      throw UnsupportedError('Should not call getCommentsByUserId');
    }
    return handler(userId: userId, page: page);
  }
}

void main() {
  group('CommentController convenience methods', () {
    test(
      'createTextComment routes through createComment payload path',
      () async {
        int? capturedPostId;
        int? capturedUserId;
        int? capturedEmojiId;
        int? capturedParentId;
        int? capturedReplyUserId;
        String? capturedText;
        String? capturedAudioKey;
        String? capturedFileKey;
        String? capturedWaveform;
        int? capturedDuration;
        double? capturedLocationX;
        double? capturedLocationY;
        CommentType? capturedType;

        final controller = CommentController(
          commentService: _FakeCommentService(
            onCreate:
                ({
                  required int postId,
                  required int userId,
                  int? emojiId,
                  int? parentId,
                  int? replyUserId,
                  String? text,
                  String? audioFileKey,
                  String? fileKey,
                  String? waveformData,
                  int? duration,
                  double? locationX,
                  double? locationY,
                  CommentType? type,
                }) async {
                  capturedPostId = postId;
                  capturedUserId = userId;
                  capturedEmojiId = emojiId;
                  capturedParentId = parentId;
                  capturedReplyUserId = replyUserId;
                  capturedText = text;
                  capturedAudioKey = audioFileKey;
                  capturedFileKey = fileKey;
                  capturedWaveform = waveformData;
                  capturedDuration = duration;
                  capturedLocationX = locationX;
                  capturedLocationY = locationY;
                  capturedType = type;
                  return const CommentCreationResult(success: true);
                },
          ),
        );

        final result = await controller.createTextComment(
          postId: 10,
          userId: 20,
          text: 'hello',
          locationX: 0.4,
          locationY: 0.6,
        );

        expect(result.success, isTrue);
        expect(capturedPostId, 10);
        expect(capturedUserId, 20);
        expect(capturedEmojiId, 0);
        expect(capturedParentId, 0);
        expect(capturedReplyUserId, 0);
        expect(capturedText, 'hello');
        expect(capturedAudioKey, '');
        expect(capturedFileKey, '');
        expect(capturedWaveform, '');
        expect(capturedDuration, 0);
        expect(capturedLocationX, 0.4);
        expect(capturedLocationY, 0.6);
        expect(capturedType, CommentType.text);
      },
    );

    test(
      'createAudioComment routes through createComment payload path',
      () async {
        int? capturedPostId;
        int? capturedUserId;
        int? capturedEmojiId;
        int? capturedParentId;
        int? capturedReplyUserId;
        String? capturedText;
        String? capturedAudioKey;
        String? capturedFileKey;
        String? capturedWaveform;
        int? capturedDuration;
        double? capturedLocationX;
        double? capturedLocationY;
        CommentType? capturedType;

        final controller = CommentController(
          commentService: _FakeCommentService(
            onCreate:
                ({
                  required int postId,
                  required int userId,
                  int? emojiId,
                  int? parentId,
                  int? replyUserId,
                  String? text,
                  String? audioFileKey,
                  String? fileKey,
                  String? waveformData,
                  int? duration,
                  double? locationX,
                  double? locationY,
                  CommentType? type,
                }) async {
                  capturedPostId = postId;
                  capturedUserId = userId;
                  capturedEmojiId = emojiId;
                  capturedParentId = parentId;
                  capturedReplyUserId = replyUserId;
                  capturedText = text;
                  capturedAudioKey = audioFileKey;
                  capturedFileKey = fileKey;
                  capturedWaveform = waveformData;
                  capturedDuration = duration;
                  capturedLocationX = locationX;
                  capturedLocationY = locationY;
                  capturedType = type;
                  return const CommentCreationResult(success: true);
                },
          ),
        );

        final result = await controller.createAudioComment(
          postId: 11,
          userId: 22,
          audioFileKey: 'audio/key.m4a',
          waveformData: '1,2,3',
          duration: 9,
          locationX: 0.2,
          locationY: 0.8,
        );

        expect(result.success, isTrue);
        expect(capturedPostId, 11);
        expect(capturedUserId, 22);
        expect(capturedEmojiId, 0);
        expect(capturedParentId, 0);
        expect(capturedReplyUserId, 0);
        expect(capturedText, '');
        expect(capturedAudioKey, 'audio/key.m4a');
        expect(capturedFileKey, '');
        expect(capturedWaveform, '1,2,3');
        expect(capturedDuration, 9);
        expect(capturedLocationX, 0.2);
        expect(capturedLocationY, 0.8);
        expect(capturedType, CommentType.audio);
      },
    );

    test('createComment treats parentId/replyUserId 0 as non-reply', () async {
      int? capturedParentId;
      int? capturedReplyUserId;
      String? capturedText;
      String? capturedAudioKey;
      String? capturedFileKey;
      String? capturedWaveform;
      int? capturedDuration;
      double? capturedLocationX;
      double? capturedLocationY;
      CommentType? capturedType;

      final controller = CommentController(
        commentService: _FakeCommentService(
          onCreate:
              ({
                required int postId,
                required int userId,
                int? emojiId,
                int? parentId,
                int? replyUserId,
                String? text,
                String? audioFileKey,
                String? fileKey,
                String? waveformData,
                int? duration,
                double? locationX,
                double? locationY,
                CommentType? type,
              }) async {
                capturedParentId = parentId;
                capturedReplyUserId = replyUserId;
                capturedText = text;
                capturedAudioKey = audioFileKey;
                capturedFileKey = fileKey;
                capturedWaveform = waveformData;
                capturedDuration = duration;
                capturedLocationX = locationX;
                capturedLocationY = locationY;
                capturedType = type;
                return const CommentCreationResult(success: true);
              },
        ),
      );

      final result = await controller.createComment(
        postId: 77,
        userId: 88,
        parentId: 0,
        replyUserId: 0,
        text: 'reply-check',
      );

      expect(result.success, isTrue);
      expect(capturedParentId, 0);
      expect(capturedReplyUserId, 0);
      expect(capturedText, 'reply-check');
      expect(capturedAudioKey, '');
      expect(capturedFileKey, '');
      expect(capturedWaveform, '');
      expect(capturedDuration, 0);
      expect(capturedLocationX, 0.0);
      expect(capturedLocationY, 0.0);
      expect(capturedType, CommentType.text);
    });

    test('createComment keeps audio payload for reply comment', () async {
      int? capturedParentId;
      int? capturedReplyUserId;
      String? capturedText;
      String? capturedAudioKey;
      String? capturedWaveform;
      int? capturedDuration;
      CommentType? capturedType;

      final controller = CommentController(
        commentService: _FakeCommentService(
          onCreate:
              ({
                required int postId,
                required int userId,
                int? emojiId,
                int? parentId,
                int? replyUserId,
                String? text,
                String? audioFileKey,
                String? fileKey,
                String? waveformData,
                int? duration,
                double? locationX,
                double? locationY,
                CommentType? type,
              }) async {
                capturedParentId = parentId;
                capturedReplyUserId = replyUserId;
                capturedText = text;
                capturedAudioKey = audioFileKey;
                capturedWaveform = waveformData;
                capturedDuration = duration;
                capturedType = type;
                return const CommentCreationResult(success: true);
              },
        ),
      );

      final result = await controller.createComment(
        postId: 77,
        userId: 88,
        parentId: 12,
        replyUserId: 34,
        audioKey: 'reply/audio.m4a',
        waveformData: '[0.1,0.2]',
        duration: 5,
        type: CommentType.reply,
      );

      expect(result.success, isTrue);
      expect(capturedParentId, 12);
      expect(capturedReplyUserId, 34);
      expect(capturedText, '');
      expect(capturedAudioKey, 'reply/audio.m4a');
      expect(capturedWaveform, '[0.1,0.2]');
      expect(capturedDuration, 5);
      expect(capturedType, CommentType.reply);
    });

    test('getCommentsByUserId forwards paging params to service', () async {
      int? capturedUserId;
      int? capturedPage;

      final controller = CommentController(
        commentService: _FakeCommentService(
          onCreate:
              ({
                required int postId,
                required int userId,
                int? emojiId,
                int? parentId,
                int? replyUserId,
                String? text,
                String? audioFileKey,
                String? fileKey,
                String? waveformData,
                int? duration,
                double? locationX,
                double? locationY,
                CommentType? type,
              }) async => const CommentCreationResult(success: true),
          onGetByUserId: ({required int userId, required int page}) async {
            capturedUserId = userId;
            capturedPage = page;
            return (
              comments: const [
                Comment(id: 1, nickname: 'a', type: CommentType.text),
              ],
              hasMore: true,
            );
          },
        ),
      );

      final result = await controller.getCommentsByUserId(userId: 7, page: 2);

      expect(capturedUserId, 7);
      expect(capturedPage, 2);
      expect(result.comments, hasLength(1));
      expect(result.hasMore, isTrue);
    });

    test(
      'getComments reuses cached full-thread snapshot until force reload',
      () async {
        var getCommentsCallCount = 0;

        final controller = CommentController(
          commentService: _FakeCommentService(
            onCreate:
                ({
                  required int postId,
                  required int userId,
                  int? emojiId,
                  int? parentId,
                  int? replyUserId,
                  String? text,
                  String? audioFileKey,
                  String? fileKey,
                  String? waveformData,
                  int? duration,
                  double? locationX,
                  double? locationY,
                  CommentType? type,
                }) async => const CommentCreationResult(success: true),
            onGetComments: ({required int postId}) async {
              getCommentsCallCount += 1;
              return [
                Comment(
                  id: getCommentsCallCount,
                  nickname: 'user-$getCommentsCallCount',
                  locationX: 0.2,
                  locationY: 0.8,
                  type: CommentType.text,
                ),
              ];
            },
          ),
        );

        final first = await controller.getComments(postId: 44);
        final second = await controller.getComments(postId: 44);
        final refreshed = await controller.getComments(
          postId: 44,
          forceReload: true,
        );

        expect(getCommentsCallCount, 2);
        expect(first.single.id, 1);
        expect(second.single.id, 1);
        expect(refreshed.single.id, 2);
        expect(controller.peekCommentsCache(postId: 44)?.single.id, 2);
        expect(
          controller
              .peekParentCommentsCache(postId: 44)
              ?.map((comment) => comment.id)
              .toList(),
          [2],
        );
        expect(controller.peekTagCommentsCache(postId: 44)?.single.id, 2);
      },
    );

    test(
      'tag cache derives from full cache and stays in sync with mutations',
      () async {
        var getTagCommentsCallCount = 0;

        final controller = CommentController(
          commentService: _FakeCommentService(
            onCreate:
                ({
                  required int postId,
                  required int userId,
                  int? emojiId,
                  int? parentId,
                  int? replyUserId,
                  String? text,
                  String? audioFileKey,
                  String? fileKey,
                  String? waveformData,
                  int? duration,
                  double? locationX,
                  double? locationY,
                  CommentType? type,
                }) async => const CommentCreationResult(success: true),
            onGetComments: ({required int postId}) async {
              return const [
                Comment(
                  id: 1,
                  nickname: 'tagged',
                  locationX: 0.1,
                  locationY: 0.2,
                  type: CommentType.text,
                ),
                Comment(id: 2, nickname: 'plain', type: CommentType.text),
              ];
            },
            onGetTagComments: ({required int postId}) async {
              getTagCommentsCallCount += 1;
              return const [
                Comment(
                  id: 999,
                  nickname: 'service-tag',
                  locationX: 0.3,
                  locationY: 0.7,
                  type: CommentType.text,
                ),
              ];
            },
          ),
        );

        await controller.getComments(postId: 55);
        final derivedTags = await controller.getTagComments(postId: 55);

        expect(getTagCommentsCallCount, 0);
        expect(
          controller
              .peekParentCommentsCache(postId: 55)
              ?.map((comment) => comment.id)
              .toList(),
          [1, 2],
        );
        expect(derivedTags.map((comment) => comment.id).toList(), [1]);

        controller.appendCreatedComment(
          postId: 55,
          newComment: const Comment(
            id: 3,
            nickname: 'new-tag',
            locationX: 0.4,
            locationY: 0.6,
            type: CommentType.text,
          ),
        );

        expect(
          controller
              .peekCommentsCache(postId: 55)
              ?.map((comment) => comment.id)
              .toList(),
          [1, 2, 3],
        );
        expect(
          controller
              .peekParentCommentsCache(postId: 55)
              ?.map((comment) => comment.id)
              .toList(),
          [1, 2, 3],
        );
        expect(
          controller
              .peekTagCommentsCache(postId: 55)
              ?.map((comment) => comment.id)
              .toList(),
          [1, 3],
        );

        controller.removeCommentFromCache(postId: 55, commentId: 1);

        expect(
          controller
              .peekCommentsCache(postId: 55)
              ?.map((comment) => comment.id)
              .toList(),
          [2, 3],
        );
        expect(
          controller
              .peekParentCommentsCache(postId: 55)
              ?.map((comment) => comment.id)
              .toList(),
          [2, 3],
        );
        expect(
          controller
              .peekTagCommentsCache(postId: 55)
              ?.map((comment) => comment.id)
              .toList(),
          [3],
        );
      },
    );

    test(
      'refetches tag comments after tag cache invalidation even when full cache remains',
      () async {
        var getTagCommentsCallCount = 0;

        final controller = CommentController(
          commentService: _FakeCommentService(
            onCreate:
                ({
                  required int postId,
                  required int userId,
                  int? emojiId,
                  int? parentId,
                  int? replyUserId,
                  String? text,
                  String? audioFileKey,
                  String? fileKey,
                  String? waveformData,
                  int? duration,
                  double? locationX,
                  double? locationY,
                  CommentType? type,
                }) async => const CommentCreationResult(success: true),
            onGetComments: ({required int postId}) async {
              return const [
                Comment(
                  id: 1,
                  nickname: 'stale-tag',
                  locationX: 0.1,
                  locationY: 0.2,
                  type: CommentType.text,
                ),
                Comment(id: 2, nickname: 'plain', type: CommentType.text),
              ];
            },
            onGetTagComments: ({required int postId}) async {
              getTagCommentsCallCount += 1;
              return const [
                Comment(
                  id: 9,
                  nickname: 'fresh-tag',
                  locationX: 0.8,
                  locationY: 0.4,
                  type: CommentType.text,
                ),
              ];
            },
          ),
        );

        await controller.getComments(postId: 66);
        controller.invalidatePostCaches(postId: 66, full: false, tag: true);

        expect(controller.peekCommentsCache(postId: 66), isNotNull);
        expect(controller.peekTagCommentsCache(postId: 66), isNull);

        final refreshedTags = await controller.getTagComments(postId: 66);

        expect(getTagCommentsCallCount, 1);
        expect(refreshedTags.map((comment) => comment.id).toList(), [9]);
        expect(
          controller
              .peekTagCommentsCache(postId: 66)
              ?.map((comment) => comment.id)
              .toList(),
          [9],
        );
      },
    );

    test(
      'refetches when tag cache only contains a provisional local append',
      () async {
        var getTagCommentsCallCount = 0;

        final controller = CommentController(
          commentService: _FakeCommentService(
            onCreate:
                ({
                  required int postId,
                  required int userId,
                  int? emojiId,
                  int? parentId,
                  int? replyUserId,
                  String? text,
                  String? audioFileKey,
                  String? fileKey,
                  String? waveformData,
                  int? duration,
                  double? locationX,
                  double? locationY,
                  CommentType? type,
                }) async => const CommentCreationResult(success: true),
            onGetTagComments: ({required int postId}) async {
              getTagCommentsCallCount += 1;
              return const [
                Comment(
                  id: 1,
                  nickname: 'me',
                  locationX: 0.2,
                  locationY: 0.3,
                  type: CommentType.text,
                ),
                Comment(
                  id: 2,
                  nickname: 'other-user',
                  locationX: 0.7,
                  locationY: 0.5,
                  type: CommentType.text,
                ),
              ];
            },
          ),
        );

        controller.replaceTagCommentsCache(postId: 77, comments: const []);
        controller.appendCreatedComment(
          postId: 77,
          newComment: const Comment(
            id: 1,
            nickname: 'me',
            locationX: 0.2,
            locationY: 0.3,
            type: CommentType.text,
          ),
        );

        expect(
          controller
              .peekTagCommentsCache(postId: 77)
              ?.map((comment) => comment.id)
              .toList(),
          [1],
        );

        final refreshedTags = await controller.getTagComments(postId: 77);

        expect(getTagCommentsCallCount, 1);
        expect(refreshedTags.map((comment) => comment.id).toList(), [1, 2]);
      },
    );

    test(
      'getAllParentComments clears stale full cache on force reload and refreshes preview caches',
      () async {
        var getParentCommentsCallCount = 0;

        final controller = CommentController(
          commentService: _FakeCommentService(
            onCreate:
                ({
                  required int postId,
                  required int userId,
                  int? emojiId,
                  int? parentId,
                  int? replyUserId,
                  String? text,
                  String? audioFileKey,
                  String? fileKey,
                  String? waveformData,
                  int? duration,
                  double? locationX,
                  double? locationY,
                  CommentType? type,
                }) async => const CommentCreationResult(success: true),
            onGetComments: ({required int postId}) async {
              return const [
                Comment(
                  id: 1,
                  nickname: 'stale-parent',
                  locationX: 0.1,
                  locationY: 0.2,
                  type: CommentType.text,
                ),
                Comment(
                  id: 2,
                  nickname: 'reply',
                  threadParentId: 1,
                  type: CommentType.reply,
                ),
              ];
            },
            onGetParentComments:
                ({required int postId, required int page}) async {
                  getParentCommentsCallCount += 1;
                  if (page == 0) {
                    return (
                      comments: const [
                        Comment(
                          id: 11,
                          nickname: 'fresh-parent',
                          type: CommentType.text,
                        ),
                        Comment(
                          id: 12,
                          nickname: 'fresh-tag',
                          locationX: 0.7,
                          locationY: 0.4,
                          type: CommentType.text,
                        ),
                      ],
                      hasMore: true,
                    );
                  }
                  return (
                    comments: const [
                      Comment(
                        id: 13,
                        nickname: 'page-2-parent',
                        type: CommentType.text,
                      ),
                    ],
                    hasMore: false,
                  );
                },
          ),
        );

        await controller.getComments(postId: 77);

        expect(
          controller
              .peekCommentsCache(postId: 77)
              ?.map((comment) => comment.id)
              .toList(),
          [1, 2],
        );

        final parentComments = await controller.getAllParentComments(
          postId: 77,
          forceReload: true,
        );

        expect(getParentCommentsCallCount, 2);
        expect(parentComments.map((comment) => comment.id).toList(), [
          11,
          12,
          13,
        ]);
        expect(controller.peekCommentsCache(postId: 77), isNull);
        expect(
          controller
              .peekParentCommentsCache(postId: 77)
              ?.map((comment) => comment.id)
              .toList(),
          [11, 12, 13],
        );
        expect(
          controller
              .peekTagCommentsCache(postId: 77)
              ?.map((comment) => comment.id)
              .toList(),
          [12],
        );
      },
    );

    test('getParentComments forwards paging params to service', () async {
      int? capturedPostId;
      int? capturedPage;

      final controller = CommentController(
        commentService: _FakeCommentService(
          onCreate:
              ({
                required int postId,
                required int userId,
                int? emojiId,
                int? parentId,
                int? replyUserId,
                String? text,
                String? audioFileKey,
                String? fileKey,
                String? waveformData,
                int? duration,
                double? locationX,
                double? locationY,
                CommentType? type,
              }) async => const CommentCreationResult(success: true),
          onGetParentComments:
              ({required int postId, required int page}) async {
                capturedPostId = postId;
                capturedPage = page;
                return (
                  comments: const [
                    Comment(id: 2, nickname: 'parent', type: CommentType.text),
                  ],
                  hasMore: false,
                );
              },
        ),
      );

      final result = await controller.getParentComments(postId: 9, page: 4);

      expect(capturedPostId, 9);
      expect(capturedPage, 4);
      expect(result.comments.single.id, 2);
      expect(result.hasMore, isFalse);
    });

    test('getChildComments forwards paging params to service', () async {
      int? capturedParentCommentId;
      int? capturedPage;

      final controller = CommentController(
        commentService: _FakeCommentService(
          onCreate:
              ({
                required int postId,
                required int userId,
                int? emojiId,
                int? parentId,
                int? replyUserId,
                String? text,
                String? audioFileKey,
                String? fileKey,
                String? waveformData,
                int? duration,
                double? locationX,
                double? locationY,
                CommentType? type,
              }) async => const CommentCreationResult(success: true),
          onGetChildComments:
              ({required int parentCommentId, required int page}) async {
                capturedParentCommentId = parentCommentId;
                capturedPage = page;
                return (
                  comments: const [
                    Comment(id: 3, nickname: 'child', type: CommentType.reply),
                  ],
                  hasMore: true,
                );
              },
        ),
      );

      final result = await controller.getChildComments(
        parentCommentId: 12,
        page: 1,
      );

      expect(capturedParentCommentId, 12);
      expect(capturedPage, 1);
      expect(result.comments.single.id, 3);
      expect(result.hasMore, isTrue);
    });

    test(
      'dedupes in-flight getComments requests and keeps loading stable',
      () async {
        final commentsCompleter = Completer<List<Comment>>();
        var callCount = 0;

        final controller = CommentController(
          commentService: _FakeCommentService(
            onCreate:
                ({
                  required int postId,
                  required int userId,
                  int? emojiId,
                  int? parentId,
                  int? replyUserId,
                  String? text,
                  String? audioFileKey,
                  String? fileKey,
                  String? waveformData,
                  int? duration,
                  double? locationX,
                  double? locationY,
                  CommentType? type,
                }) async => const CommentCreationResult(success: true),
            onGetComments: ({required int postId}) {
              callCount++;
              return commentsCompleter.future;
            },
          ),
        );

        final first = controller.getComments(postId: 5);
        final second = controller.getComments(postId: 5);

        expect(controller.isLoading, isTrue);

        commentsCompleter.complete([
          const Comment(id: 1, nickname: 'n', type: CommentType.text),
        ]);

        final results = await Future.wait([first, second]);

        expect(callCount, 1);
        expect(results[0], hasLength(1));
        expect(results[1].single.id, 1);
        expect(controller.isLoading, isFalse);
      },
    );

    test('getTagComments forwards requests to service', () async {
      int? capturedPostId;

      final controller = CommentController(
        commentService: _FakeCommentService(
          onCreate:
              ({
                required int postId,
                required int userId,
                int? emojiId,
                int? parentId,
                int? replyUserId,
                String? text,
                String? audioFileKey,
                String? fileKey,
                String? waveformData,
                int? duration,
                double? locationX,
                double? locationY,
                CommentType? type,
              }) async => const CommentCreationResult(success: true),
          onGetTagComments: ({required int postId}) async {
            capturedPostId = postId;
            return const [
              Comment(
                id: 9,
                nickname: 'tag',
                type: CommentType.text,
                locationX: 0.1,
                locationY: 0.2,
              ),
            ];
          },
        ),
      );

      final result = await controller.getTagComments(postId: 9);

      expect(capturedPostId, 9);
      expect(result.single.id, 9);
      expect(result.single.hasLocation, isTrue);
    });

    test(
      'dedupes in-flight getTagComments requests and keeps loading stable',
      () async {
        final tagCompleter = Completer<List<Comment>>();
        var callCount = 0;

        final controller = CommentController(
          commentService: _FakeCommentService(
            onCreate:
                ({
                  required int postId,
                  required int userId,
                  int? emojiId,
                  int? parentId,
                  int? replyUserId,
                  String? text,
                  String? audioFileKey,
                  String? fileKey,
                  String? waveformData,
                  int? duration,
                  double? locationX,
                  double? locationY,
                  CommentType? type,
                }) async => const CommentCreationResult(success: true),
            onGetTagComments: ({required int postId}) {
              callCount++;
              return tagCompleter.future;
            },
          ),
        );

        final first = controller.getTagComments(postId: 5);
        final second = controller.getTagComments(postId: 5);

        expect(controller.isLoading, isTrue);

        tagCompleter.complete(const [
          Comment(
            id: 1,
            nickname: 'tag',
            type: CommentType.text,
            locationX: 0.3,
            locationY: 0.7,
          ),
        ]);

        final results = await Future.wait([first, second]);

        expect(callCount, 1);
        expect(results[0].single.id, 1);
        expect(results[1].single.id, 1);
        expect(controller.isLoading, isFalse);
      },
    );
  });
}
