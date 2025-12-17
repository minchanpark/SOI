import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../api/controller/category_controller.dart' as api_category;
import '../../api/controller/post_controller.dart';
import '../../api/controller/user_controller.dart';
import '../../api/models/post.dart' show PostStatus;
import 'manager/feed_audio_manager.dart';
import 'manager/feed_data_manager.dart';
import 'manager/voice_comment_state_manager.dart';
import 'widgets/feed_page_builder.dart';

class FeedHomeScreen extends StatefulWidget {
  const FeedHomeScreen({super.key});

  @override
  State<FeedHomeScreen> createState() => _FeedHomeScreenState();
}

class _FeedHomeScreenState extends State<FeedHomeScreen> {
  FeedDataManager? _feedDataManager;
  VoiceCommentStateManager? _voiceCommentStateManager;
  FeedAudioManager? _feedAudioManager;

  UserController? _userController;
  VoidCallback? _userControllerListener;
  String? _lastProfileImageKey;

  @override
  void initState() {
    super.initState();
    // 수정: FeedDataManager는 전역 Provider에서 가져와 캐시를 유지합니다.
    _voiceCommentStateManager = VoiceCommentStateManager();
    _feedAudioManager = FeedAudioManager();

    _voiceCommentStateManager?.setOnStateChanged(
      () => mounted ? setState(() {}) : null,
    );

    _feedDataManager?.setOnPostsLoaded((items) {
      if (!mounted) return;
      for (final item in items) {
        unawaited(
          _voiceCommentStateManager?.loadCommentsForPost(item.post.id, context),
        );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _feedDataManager = Provider.of<FeedDataManager>(context, listen: false);
      _userController = Provider.of<UserController>(context, listen: false);
      _lastProfileImageKey = _userController?.currentUser?.profileImageUrlKey;
      _userControllerListener ??= _handleUserProfileChanged;
      _userController?.addListener(_userControllerListener!);

      // PostController 구독 설정
      final postController = Provider.of<PostController>(
        context,
        listen: false,
      );
      _feedDataManager?.listenToPostController(postController, context);

      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    if (_userController == null) return;
    // 수정: 피드 진입마다 매번 강제 리로드하지 않고, 캐시가 있으면 재사용합니다.
    await _feedDataManager?.loadUserCategoriesAndPhotos(context);
  }

  @override
  void dispose() {
    if (_userControllerListener != null) {
      _userController?.removeListener(_userControllerListener!);
    }
    _feedDataManager?.dispose();
    _voiceCommentStateManager?.dispose();
    // (배포버전 프리즈 방지) 전역 imageCache.clear()는 캐시가 큰 실사용 환경에서
    // dispose 타이밍에 수 초 프리즈를 만들 수 있어 제거합니다.
    super.dispose();
  }

  // 사진 게시물 삭제 처리
  Future<void> _deletePost(int index, FeedPostItem item) async {
    try {
      final postController = Provider.of<PostController>(
        context,
        listen: false,
      );
      final categoryController = Provider.of<api_category.CategoryController>(
        context,
        listen: false,
      );
      final userId = _userController?.currentUser?.id;
      final success = await postController.setPostStatus(
        postId: item.post.id,
        postStatus: PostStatus.deleted,
      );
      if (!mounted) return;
      if (success) {
        setState(() {
          _feedDataManager?.removePhoto(index);
          _voiceCommentStateManager?.postComments.remove(item.post.id);
          _voiceCommentStateManager?.pendingVoiceComments.remove(item.post.id);
          _voiceCommentStateManager?.voiceCommentActiveStates.remove(
            item.post.id,
          );
          _voiceCommentStateManager?.voiceCommentSavedStates.remove(
            item.post.id,
          );
        });
        if (userId != null) {
          unawaited(
            categoryController.loadCategories(userId, forceReload: true),
          );
        }
        _showSnackBar('사진이 삭제되었습니다.');
      } else {
        _showSnackBar('사진 삭제에 실패했습니다.', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('사진 삭제 중 오류가 발생했습니다.', isError: true);
    }
  }

  // 페이지 변경 처리 (무한 스크롤)
  void _handlePageChanged(int index) {
    final totalPosts = _feedDataManager?.visiblePosts.length ?? 0;
    if (totalPosts == 0) {
      return;
    }
    // 수정: 현재 5개를 보여줄 때 4번째(인덱스 3)에서 다음 5개를 미리 로드합니다.
    // (일반화: 끝에서 2번째에 도달하면 다음 청크를 요청)
    if (index >= totalPosts - 2 &&
        (_feedDataManager?.hasMoreData ?? false) &&
        !(_feedDataManager?.isLoadingMore ?? false)) {
      unawaited(_feedDataManager?.loadMorePhotos(context));
    }
  }

  // 음성 재생 토글
  Future<void> _toggleAudio(FeedPostItem item) async {
    await _feedAudioManager?.toggleAudio(item.post, context);
  }

  // 음성 댓글 활성화/비활성화 토글
  void _toggleVoiceComment(int postId) {
    _voiceCommentStateManager?.toggleVoiceComment(postId);
  }

  // 음성 댓글 완료 처리
  Future<void> _onVoiceCommentCompleted(
    int postId,
    String? audioPath,
    List<double>? waveformData,
    int? duration,
  ) async {
    if (_userController == null) return;
    await _voiceCommentStateManager?.onVoiceCommentCompleted(
      postId,
      audioPath,
      waveformData,
      duration,
      _userController!,
    );
  }

  // 텍스트 댓글 완료 처리
  Future<void> _onTextCommentCompleted(int postId, String text) async {
    if (_userController == null) return;
    await _voiceCommentStateManager?.onTextCommentCompleted(
      postId,
      text,
      _userController!,
    );
  }

  // 음성 댓글 삭제 처리
  void _onVoiceCommentDeleted(int postId) {
    _voiceCommentStateManager?.onVoiceCommentDeleted(postId);
  }

  // 음성 댓글 저장 완료 처리
  void _onSaveCompleted(int postId) {
    _voiceCommentStateManager?.onSaveCompleted(postId);
  }

  // 프로필 이미지 드래그 이벤트 처리
  void _onProfileImageDragged(int postId, Offset absolutePosition) {
    _voiceCommentStateManager?.onProfileImageDragged(postId, absolutePosition);
  }

  // 모든 오디오 정지
  void _stopAllAudio() {
    _feedAudioManager?.stopAllAudio(context);
  }

  // 프로필 이미지 변경 감지 및 피드 새로고침
  void _handleUserProfileChanged() {
    final newKey = _userController?.currentUser?.profileImageUrlKey;

    // 프로필 이미지 키가 변경되지 않았으면 종료
    if (newKey == _lastProfileImageKey) {
      return;
    }

    // 프로필 이미지가 변경되었으므로, 마지막 키 업데이트
    _lastProfileImageKey = newKey;

    // 프로필 이미지가 변경되었으므로 피드 새로고침
    _refreshFeedAfterProfileUpdate();
  }

  // 피드 새로고침 및 댓글 재로딩
  void _refreshFeedAfterProfileUpdate() {
    final posts = _feedDataManager?.allPosts ?? const <FeedPostItem>[];
    if (posts.isNotEmpty) {
      _voiceCommentStateManager?.postComments.clear();
    }

    // 피드 데이터 새로고침
    unawaited(
      // 사용자 카테고리 및 사진 로드
      _feedDataManager?.loadUserCategoriesAndPhotos(context).then((_) {
        if (!mounted) return;
        final refreshedPosts = _feedDataManager?.allPosts ?? [];
        for (final item in refreshedPosts) {
          // 각 게시물에 대한 댓글 로드
          unawaited(
            _voiceCommentStateManager?.loadCommentsForPost(
              item.post.id,
              context,
            ),
          );
        }
        if (mounted) {
          setState(() {});
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, body: _buildBody());
  }

  Widget _buildBody() {
    // 추가: Provider 구독(변경 시 자동 rebuild) - 캐시를 유지하면서도 UI는 최신 상태로 갱신됩니다.
    final feedDataManager = Provider.of<FeedDataManager>(context);
    _feedDataManager ??= feedDataManager;

    if (feedDataManager.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (feedDataManager.allPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.photo_camera_outlined,
              color: Colors.white54,
              size: 80,
            ),
            SizedBox(height: 16.h),
            Text(
              '아직 사진이 없어요',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            const Text(
              '친구들과 카테고리를 만들고\n첫 번째 사진을 공유해보세요!',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      // 수정: 당겨서 새로고침은 서버에서 다시 가져오도록 강제 리프레시합니다.
      onRefresh: () => feedDataManager.loadUserCategoriesAndPhotos(
        context,
        forceRefresh: true,
      ),
      color: Colors.white,
      backgroundColor: Colors.black,
      child: FeedPageBuilder(
        posts: feedDataManager.visiblePosts,
        hasMoreData: feedDataManager.hasMoreData,
        isLoadingMore: feedDataManager.isLoadingMore,
        postComments: _voiceCommentStateManager!.postComments,
        selectedEmojisByPostId:
            _voiceCommentStateManager!.selectedEmojisByPostId,
        voiceCommentActiveStates:
            _voiceCommentStateManager!.voiceCommentActiveStates,
        voiceCommentSavedStates:
            _voiceCommentStateManager!.voiceCommentSavedStates,
        pendingTextComments: _voiceCommentStateManager!.pendingTextComments,
        pendingVoiceComments: _voiceCommentStateManager!.pendingVoiceComments,
        onToggleAudio: _toggleAudio,
        onToggleVoiceComment: _toggleVoiceComment,
        onVoiceCommentCompleted: _onVoiceCommentCompleted,
        onTextCommentCompleted: _onTextCommentCompleted,
        onVoiceCommentDeleted: _onVoiceCommentDeleted,
        onProfileImageDragged: _onProfileImageDragged,
        onSaveRequested: (postId) =>
            _voiceCommentStateManager!.saveVoiceComment(postId, context),
        onSaveCompleted: _onSaveCompleted,
        onDeletePost: _deletePost,
        onPageChanged: (index) => _handlePageChanged(index),
        onStopAllAudio: _stopAllAudio,
        currentUserNickname: _userController?.currentUser?.userId,
        onReloadComments: (postId) =>
            _voiceCommentStateManager!.loadCommentsForPost(postId, context),
        onEmojiSelected: (postId, emoji) =>
            _voiceCommentStateManager!.setSelectedEmoji(postId, emoji),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF5A5A5A),
      ),
    );
  }
}
