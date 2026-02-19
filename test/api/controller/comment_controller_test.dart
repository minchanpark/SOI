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

class _FakeCommentService extends CommentService {
  _FakeCommentService({required this.onCreate})
    : super(commentApi: _NoopCommentApi());

  final _CreateCommentHandler onCreate;

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
  });
}
