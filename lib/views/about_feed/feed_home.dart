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
  // FeedDataManager는 전역 Provider에서 가져와 캐시를 유지합니다.
  // FeedDataManager를 Provider로 만들어서, 여러 화면에서 동일한 인스턴스를 사용하도록 합니다.
  FeedDataManager? _feedDataManager;

  // 오디오 및 음성 댓글 매니저
  VoiceCommentStateManager? _voiceCommentStateManager;

  // 오디오 매니저
  FeedAudioManager? _feedAudioManager;

  // 사용자 컨트롤러 및 프로필 이미지 키 추적
  UserController? _userController;
  VoidCallback? _userControllerListener;
  String? _lastProfileImageKey;

  @override
  void initState() {
    super.initState();

    _voiceCommentStateManager = VoiceCommentStateManager();

    // 오디오 매니저 초기화
    _feedAudioManager = FeedAudioManager();

    _voiceCommentStateManager?.setOnStateChanged(
      () => mounted ? setState(() {}) : null,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // FeedDataManager 인스턴스 가져오기
      _feedDataManager = Provider.of<FeedDataManager>(context, listen: false);

      // _feedDataManager instance를 가지고 온 후에,
      // 각 게시물에 대한 댓글을 로드하는 콜백 설정
      _feedDataManager?.setOnPostsLoaded((items) {
        if (!mounted) return;
        for (final item in items) {
          unawaited(
            // 각 게시물에 대한 댓글 로드
            _voiceCommentStateManager?.loadCommentsForPost(
              item.post.id,
              context,
            ),
          );
        }
      });

      _userController = Provider.of<UserController>(context, listen: false);
      _lastProfileImageKey = _userController?.currentUser?.profileImageUrlKey;
      _userControllerListener ??= _handleUserProfileChanged;
      _userController?.addListener(_userControllerListener!);

      // PostController 구독 설정
      final postController = Provider.of<PostController>(
        context,
        listen: false,
      );

      // FeedDataManager에 PostController 구독 시작
      _feedDataManager?.listenToPostController(postController, context);

      _loadInitialData();
    });
  }

  /// 초기 데이터 로드
  Future<void> _loadInitialData() async {
    if (_userController == null) return;
    // 피드 진입마다 매번 강제 리로드하지 않고, 캐시가 있으면 재사용합니다.
    await _feedDataManager?.loadUserCategoriesAndPhotos(context);
  }

  @override
  void dispose() {
    if (_userControllerListener != null) {
      _userController?.removeListener(_userControllerListener!);
    }
    // FeedDataManager는 전역 Provider가 소유하므로 여기서 dispose 하면 캐시가 날아가거나
    // "disposed object" 에러가 날 수 있습니다. 화면이 사라질 때는 리스너만 해제합니다.
    _feedDataManager?.detachFromPostController();

    _voiceCommentStateManager?.dispose();

    super.dispose();
  }

  /// 사진 게시물 삭제 처리
  ///
  /// Parameters:
  /// - [index]: 삭제할 게시물의 인덱스
  /// - [item]: 삭제할 게시물 아이템
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
          _feedDataManager?.removePhoto(
            index,
          ); // UI에서 즉시 제거 --> 서버에 접근하는 것이 아니라, UI단에서 제거하는 것.
          _voiceCommentStateManager?.postComments.remove(
            item.post.id,
          ); // 댓글도 제거
          _voiceCommentStateManager?.pendingVoiceComments.remove(
            item.post.id,
          ); // 대기 중인 댓글도 제거
          _voiceCommentStateManager?.voiceCommentActiveStates.remove(
            item.post.id,
          ); // 댓글 활성 상태도 제거
          _voiceCommentStateManager?.voiceCommentSavedStates.remove(
            item.post.id,
          ); // 댓글 저장 상태도 제거
        });
        if (userId != null) {
          // 카테고리도 강제 새로고침 --> 댓글 수정을 반영하기 위함
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

  /// 페이지 변경 처리 (무한 스크롤)
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
      // 다음으로 가지고 올 게시물을 추가로 로드 --> 네트워크 요청이 아니라 UI 노출만 증가시킴
      unawaited(_feedDataManager?.loadMorePhotos(context));
    }
  }

  /// 음성 재생 토글
  Future<void> _toggleAudio(FeedPostItem item) async {
    await _feedAudioManager?.toggleAudio(item.post, context);
  }

  /// 음성 댓글 활성화/비활성화 토글
  void _toggleVoiceComment(int postId) {
    _voiceCommentStateManager?.toggleVoiceComment(postId);
  }

  /// 음성 댓글을 완료 처리하는 메소드
  ///
  /// Parameters:
  /// - [postId]: 댓글이 달린 게시물 ID
  /// - [audioPath]: 녹음된 오디오 파일 경로
  /// - [waveformData]: 오디오 파형 데이터
  /// - [duration]: 오디오 길이(초)
  Future<void> _onVoiceCommentCompleted(
    int postId,
    String? audioPath,
    List<double>? waveformData,
    int? duration,
  ) async {
    if (_userController == null) return;
    // 음성 댓글이 완료되었음을 상태 매니저에 알림
    await _voiceCommentStateManager?.onVoiceCommentCompleted(
      postId,
      audioPath,
      waveformData,
      duration,
      _userController!,
    );
  }

  /// 텍스트 댓글 완료 처리
  ///
  /// Parameters:
  /// - [postId]: 댓글이 달린 게시물 ID
  /// - [text]: 작성된 텍스트 댓글 내용
  Future<void> _onTextCommentCompleted(int postId, String text) async {
    if (_userController == null) return;
    await _voiceCommentStateManager?.onTextCommentCompleted(
      postId,
      text,
      _userController!,
    );
  }

  /// 음성 댓글 삭제 처리
  /// 서버에 접근하지 않고, 캐시를 지워서 UI에서 제거합니다.
  void _onVoiceCommentDeleted(int postId) {
    _voiceCommentStateManager?.onVoiceCommentDeleted(postId);
  }

  /// 음성 댓글 저장 완료 처리
  /// 서버에 접근하지 않고, 상태만 업데이트합니다.
  ///
  /// Parameters:
  /// - [postId]: 댓글이 달린 게시물 ID
  void _onSaveCompleted(int postId) {
    _voiceCommentStateManager?.onSaveCompleted(postId);
  }

  /// 프로필 이미지 드래그 이벤트 처리
  ///
  /// Parameters:
  /// - [postId]: 댓글이 달린 게시물 ID
  /// - [absolutePosition]: 드래그된 프로필 이미지의 절대 위치
  void _onProfileImageDragged(int postId, Offset absolutePosition) {
    _voiceCommentStateManager?.onProfileImageDragged(postId, absolutePosition);
  }

  /// 모든 오디오 정지
  void _stopAllAudio() {
    _feedAudioManager?.stopAllAudio(context);
  }

  /// 프로필 이미지 변경 감지 및 피드 새로고침
  void _handleUserProfileChanged() {
    // 현재 프로필 이미지 키 가져오기
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

  /// 피드 새로고침 및 댓글 재로딩
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
        // 피드가 새로고침된 후, 각 게시물에 대한 댓글 재로딩
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
    // Provider 구독(변경 시 자동 rebuild) - 캐시를 유지하면서도 UI는 최신 상태로 갱신됩니다.
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
      // 당겨서 새로고침은 서버에서 다시 가져오도록 강제 리프레시합니다.
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
