import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/models/comment.dart';
import 'package:soi/api/models/post.dart';
import 'package:soi_api_client/api.dart';

void main() {
  group('Comment model mapping', () {
    test('maps new DTO fields for reply comments', () {
      final dto = CommentRespDto(
        id: 10,
        userId: 7,
        nickname: 'alice',
        replyUserName: 'bob',
        userProfileUrl: 'https://example.com/profile.jpg',
        userProfileKey: 'profiles/alice.jpg',
        fileUrl: 'https://example.com/comment.jpg',
        fileKey: 'comments/comment.jpg',
        commentType: CommentRespDtoCommentTypeEnum.REPLY,
      );

      final comment = Comment.fromDto(dto);

      expect(comment.userId, 7);
      expect(comment.replyUserName, 'bob');
      expect(comment.userProfileUrl, 'https://example.com/profile.jpg');
      expect(comment.userProfileKey, 'profiles/alice.jpg');
      expect(comment.fileUrl, 'https://example.com/comment.jpg');
      expect(comment.fileKey, 'comments/comment.jpg');
      expect(comment.type, CommentType.reply);
      expect(comment.toJson()['commentType'], 'REPLY');
    });
  });

  group('Post model mapping', () {
    test('maps postType/gallery/aspect fields from DTO', () {
      final dto = PostRespDto(
        id: 3,
        nickname: 'alice',
        commentCount: 12,
        postType: PostRespDtoPostTypeEnum.MULTIMEDIA,
        savedAspectRatio: 1.25,
        isFromGallery: true,
      );

      final post = Post.fromDto(dto);

      expect(post.postType, PostType.multiMedia);
      expect(post.commentCount, 12);
      expect(post.savedAspectRatio, 1.25);
      expect(post.isFromGallery, isTrue);
      expect(post.toJson()['postType'], 'MULTIMEDIA');
      expect(post.toJson()['commentCount'], 12);
    });

    test('keeps nullable postType when response omits it', () {
      final dto = PostRespDto(id: 9, nickname: 'alice');

      final post = Post.fromDto(dto);

      expect(post.postType, isNull);
    });
  });
}
