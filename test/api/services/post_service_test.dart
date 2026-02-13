import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/models/post.dart';
import 'package:soi/api/services/post_service.dart';
import 'package:soi_api_client/api.dart';

class _FakePostApi extends PostAPIApi {
  _FakePostApi({this.onCreate, this.onUpdate});

  final Future<ApiResponseDtoBoolean?> Function(PostCreateReqDto)? onCreate;
  final Future<ApiResponseDtoObject?> Function(PostUpdateReqDto)? onUpdate;

  @override
  Future<ApiResponseDtoBoolean?> create1(
    PostCreateReqDto postCreateReqDto,
  ) async {
    final handler = onCreate;
    if (handler == null) {
      throw UnimplementedError('onCreate is not configured');
    }
    return handler(postCreateReqDto);
  }

  @override
  Future<ApiResponseDtoObject?> update3(
    PostUpdateReqDto postUpdateReqDto,
  ) async {
    final handler = onUpdate;
    if (handler == null) {
      throw UnimplementedError('onUpdate is not configured');
    }
    return handler(postUpdateReqDto);
  }
}

void main() {
  group('PostService postType mapping', () {
    test('infers TEXT_ONLY for create when media key list is empty', () async {
      PostCreateReqDto? capturedDto;
      final service = PostService(
        postApi: _FakePostApi(
          onCreate: (dto) async {
            capturedDto = dto;
            return ApiResponseDtoBoolean(success: true, data: true);
          },
        ),
      );

      final result = await service.createPost(
        nickName: 'tester',
        postFileKey: const [],
      );

      expect(result, isTrue);
      expect(capturedDto?.postType, PostCreateReqDtoPostTypeEnum.TEXT_ONLY);
    });

    test(
      'infers MULTIMEDIA for create when media key list is present',
      () async {
        PostCreateReqDto? capturedDto;
        final service = PostService(
          postApi: _FakePostApi(
            onCreate: (dto) async {
              capturedDto = dto;
              return ApiResponseDtoBoolean(success: true, data: true);
            },
          ),
        );

        final result = await service.createPost(
          nickName: 'tester',
          postFileKey: const ['posts/example.jpg'],
        );

        expect(result, isTrue);
        expect(capturedDto?.postType, PostCreateReqDtoPostTypeEnum.MULTIMEDIA);
      },
    );

    test(
      'maps update postType to MULTIMEDIA when postFileKey is provided',
      () async {
        PostUpdateReqDto? capturedDto;
        final service = PostService(
          postApi: _FakePostApi(
            onUpdate: (dto) async {
              capturedDto = dto;
              return ApiResponseDtoObject(success: true, data: true);
            },
          ),
        );

        final result = await service.updatePost(
          postId: 1,
          postFileKey: 'posts/example.jpg',
        );

        expect(result, isTrue);
        expect(capturedDto?.postType, PostUpdateReqDtoPostTypeEnum.MULTIMEDIA);
      },
    );

    test('allows explicit postType override for create', () async {
      PostCreateReqDto? capturedDto;
      final service = PostService(
        postApi: _FakePostApi(
          onCreate: (dto) async {
            capturedDto = dto;
            return ApiResponseDtoBoolean(success: true, data: true);
          },
        ),
      );

      final result = await service.createPost(
        nickName: 'tester',
        postFileKey: const ['posts/example.jpg'],
        postType: PostType.textOnly,
      );

      expect(result, isTrue);
      expect(capturedDto?.postType, PostCreateReqDtoPostTypeEnum.TEXT_ONLY);
    });
  });
}
