import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../api/controller/post_controller.dart';
import '../../api/controller/user_controller.dart';
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

  @override
  void initState() {
    super.initState();
    _feedDataManager = FeedDataManager();
    _voiceCommentStateManager = VoiceCommentStateManager();
    _feedAudioManager = FeedAudioManager();

    _feedDataManager?.setOnStateChanged(() => mounted ? setState(() {}) : null);
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
      _userController = Provider.of<UserController>(context, listen: false);
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    if (_userController == null) return;
    await _feedDataManager?.loadUserCategoriesAndPhotos(context);
  }

  @override
  void dispose() {
    _feedDataManager?.dispose();
    _voiceCommentStateManager?.dispose();
    PaintingBinding.instance.imageCache.clear();
    super.dispose();
  }

  Future<void> _deletePost(int index, FeedPostItem item) async {
    try {
      final postController = Provider.of<PostController>(
        context,
        listen: false,
      );
      final success = await postController.deletePost(item.post.id);
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
        _showSnackBar('사진이 삭제되었습니다.');
      } else {
        _showSnackBar('사진 삭제에 실패했습니다.', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('사진 삭제 중 오류가 발생했습니다.', isError: true);
    }
  }

  void _handlePageChanged(int index) {
    final totalPosts = _feedDataManager?.allPosts.length ?? 0;
    if (totalPosts == 0) {
      return;
    }
    if (index >= totalPosts - 5 &&
        (_feedDataManager?.hasMoreData ?? false) &&
        !(_feedDataManager?.isLoadingMore ?? false)) {
      unawaited(_feedDataManager?.loadMorePhotos(context));
    }
  }

  Future<void> _toggleAudio(FeedPostItem item) async {
    await _feedAudioManager?.toggleAudio(item.post, context);
  }

  void _toggleVoiceComment(int postId) {
    _voiceCommentStateManager?.toggleVoiceComment(postId);
  }

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

  Future<void> _onTextCommentCompleted(int postId, String text) async {
    if (_userController == null) return;
    await _voiceCommentStateManager?.onTextCommentCompleted(
      postId,
      text,
      _userController!,
    );
  }

  void _onVoiceCommentDeleted(int postId) {
    _voiceCommentStateManager?.onVoiceCommentDeleted(postId);
  }

  void _onSaveCompleted(int postId) {
    _voiceCommentStateManager?.onSaveCompleted(postId);
  }

  void _onProfileImageDragged(int postId, Offset absolutePosition) {
    _voiceCommentStateManager?.onProfileImageDragged(postId, absolutePosition);
  }

  void _stopAllAudio() {
    _feedAudioManager?.stopAllAudio(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, body: _buildBody());
  }

  Widget _buildBody() {
    if (_feedDataManager?.isLoading ?? true) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_feedDataManager?.allPosts.isEmpty ?? true) {
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
      onRefresh: () => _feedDataManager!.loadUserCategoriesAndPhotos(context),
      color: Colors.white,
      backgroundColor: Colors.black,
      child: FeedPageBuilder(
        posts: _feedDataManager!.allPosts,
        hasMoreData: _feedDataManager!.hasMoreData,
        isLoadingMore: _feedDataManager!.isLoadingMore,
        postComments: _voiceCommentStateManager!.postComments,
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
        onPageChanged: _handlePageChanged,
        onStopAllAudio: _stopAllAudio,
        currentUserNickname: _userController?.currentUser?.userId,
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
