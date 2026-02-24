import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/controller/post_controller.dart';
import 'package:soi/api/models/post.dart';
import 'package:soi/api/services/post_service.dart';
import 'package:soi_api_client/api.dart';

class _NoopPostApi extends PostAPIApi {}

typedef _CreatePostHandler =
    Future<bool> Function({
      int? userId,
      required String nickName,
      String? content,
      List<String> postFileKey,
      List<String> audioFileKey,
      List<int> categoryIds,
      String? waveformData,
      int? duration,
      double? savedAspectRatio,
      bool? isFromGallery,
      PostType? postType,
    });

class _FakePostService extends PostService {
  _FakePostService({this.onCreate}) : super(postApi: _NoopPostApi());

  final _CreatePostHandler? onCreate;

  @override
  Future<bool> createPost({
    int? userId,
    required String nickName,
    String? content,
    List<String> postFileKey = const [],
    List<String> audioFileKey = const [],
    List<int> categoryIds = const [],
    String? waveformData,
    int? duration,
    double? savedAspectRatio,
    bool? isFromGallery,
    PostType? postType,
  }) async {
    final handler = onCreate;
    if (handler == null) {
      throw UnimplementedError('onCreate is not configured');
    }
    return handler(
      userId: userId,
      nickName: nickName,
      content: content,
      postFileKey: postFileKey,
      audioFileKey: audioFileKey,
      categoryIds: categoryIds,
      waveformData: waveformData,
      duration: duration,
      savedAspectRatio: savedAspectRatio,
      isFromGallery: isFromGallery,
      postType: postType,
    );
  }
}

void main() {
  group('PostController createPost forwarding', () {
    test(
      'forwards text-only payload fields to service without mutation',
      () async {
        int? capturedUserId;
        String? capturedNickName;
        String? capturedContent;
        List<String>? capturedPostFileKey;
        List<String>? capturedAudioFileKey;
        List<int>? capturedCategoryIds;
        PostType? capturedPostType;

        final controller = PostController(
          postService: _FakePostService(
            onCreate:
                ({
                  int? userId,
                  required String nickName,
                  String? content,
                  List<String> postFileKey = const [],
                  List<String> audioFileKey = const [],
                  List<int> categoryIds = const [],
                  String? waveformData,
                  int? duration,
                  double? savedAspectRatio,
                  bool? isFromGallery,
                  PostType? postType,
                }) async {
                  capturedUserId = userId;
                  capturedNickName = nickName;
                  capturedContent = content;
                  capturedPostFileKey = postFileKey;
                  capturedAudioFileKey = audioFileKey;
                  capturedCategoryIds = categoryIds;
                  capturedPostType = postType;
                  return true;
                },
          ),
        );

        final result = await controller.createPost(
          userId: 100,
          nickName: 'tester',
          content: 'hello text only',
          postFileKey: const [],
          audioFileKey: const [],
          categoryIds: const [1, 2],
          postType: PostType.textOnly,
        );

        expect(result, isTrue);
        expect(capturedUserId, 100);
        expect(capturedNickName, 'tester');
        expect(capturedContent, 'hello text only');
        expect(capturedPostFileKey, isEmpty);
        expect(capturedAudioFileKey, isEmpty);
        expect(capturedCategoryIds, const [1, 2]);
        expect(capturedPostType, PostType.textOnly);
      },
    );
  });
}
