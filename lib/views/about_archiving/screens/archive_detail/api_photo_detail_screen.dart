import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../../../api/models/post.dart';
import '../../../../api/models/comment.dart';
import '../../../../api/models/comment_creation_result.dart';
import '../../../../api/models/user.dart' as api_user;
import '../../../../api/controller/user_controller.dart';
import '../../../../api/controller/comment_controller.dart';
import '../../../../api/controller/category_controller.dart' as api_category;
import '../../../../api/controller/friend_controller.dart';
import '../../../../api/controller/post_controller.dart';
import '../../../../api/controller/media_controller.dart';
import '../../../../api/controller/audio_controller.dart';
import '../../../../utils/position_converter.dart';
import '../../../../utils/snackbar_utils.dart';
import '../../../common_widget/api_photo/api_photo_card_widget.dart';
import '../../../common_widget/about_voice_comment/pending_api_voice_comment.dart';
import '../../../common_widget/report/report_bottom_sheet.dart';
import '../../../../api/models/friend.dart';

/// API 기반 사진 상세 화면
///
/// Firebase 버전의 PhotoDetailScreen과 동일한 디자인을 유지하면서
/// REST API와 공통 위젯을 사용합니다.
class ApiPhotoDetailScreen extends StatefulWidget {
  final List<Post> allPosts;
  final int initialIndex;
  final String categoryName;
  final int categoryId;

  const ApiPhotoDetailScreen({
    super.key,
    required this.allPosts,
    required this.initialIndex,
    required this.categoryName,
    required this.categoryId,
  });

  @override
  State<ApiPhotoDetailScreen> createState() => _ApiPhotoDetailScreenState();
}

class _ApiPhotoDetailScreenState extends State<ApiPhotoDetailScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  late List<Post> _posts;
  late final AudioController _audioController;

  final Set<int> _deletedPostIds =
      <int>{}; // 삭제된 게시물 ID 추적 --> 상위 위젯에 전달하기 위해 사용됩니다.
  bool _allowPopWithDeletionResult = false;

  // 사용자 프로필 관련
  String _userProfileImageUrl = '';
  String _userName = '';
  bool _isLoadingProfile = true;

  // 컨트롤러
  UserController? _userController;
  FriendController? _friendController;
  VoidCallback? _friendListener;

  // 상태 맵 (Firebase 버전과 동일한 구조)
  final Map<int, List<Comment>> _postComments = {};
  final Map<int, String?> _selectedEmojisByPostId = {}; // postId별 내가 선택한 이모지
  final Map<int, bool> _voiceCommentActiveStates = {};
  final Map<int, bool> _voiceCommentSavedStates = {};
  final Map<String, String> _userProfileImages = {};
  final Map<String, bool> _profileLoadingStates = {};
  final Map<String, String> _userNames = {};
  final Map<int, PendingApiCommentDraft> _pendingCommentDrafts = {};
  final Map<int, PendingApiCommentMarker> _pendingCommentMarkers = {};
  final Map<int, bool> _pendingTextComments = {};
  final Map<int, String> _resolvedAudioUrls = {};

  static const List<Offset> _autoPlacementPattern = [
    Offset(0.5, 0.5),
    Offset(0.62, 0.5),
    Offset(0.38, 0.5),
    Offset(0.5, 0.62),
    Offset(0.5, 0.38),
    Offset(0.62, 0.62),
    Offset(0.38, 0.62),
    Offset(0.62, 0.38),
    Offset(0.38, 0.38),
  ];

  final Map<int, int> _autoPlacementIndices = {};
  static const int _kMaxWaveformSamples = 30;

  String? _emojiFromId(int? emojiId) {
    switch (emojiId) {
      case 0:
        return '😀';
      case 1:
        return '😍';
      case 2:
        return '😭';
      case 3:
        return '😡';
    }
    return null;
  }

  String? _selectedEmojiFromComments({
    required List<Comment> comments,
    required String currentUserNickname,
  }) {
    for (final comment in comments.reversed) {
      if (comment.type != CommentType.emoji) continue;
      if (comment.nickname != currentUserNickname) continue;
      return _emojiFromId(comment.emojiId);
    }
    return null;
  }

  void _setSelectedEmoji(int postId, String? emoji) {
    if (!mounted) return;
    setState(() {
      if (emoji == null) {
        _selectedEmojisByPostId.remove(postId);
      } else {
        _selectedEmojisByPostId[postId] = emoji;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _posts = List<Post>.from(
      widget.allPosts,
    ); // 자식 위젯에서 부모가 건네준 allPosts 수정을 방지하기 위해서, 복사본 생성
    _pageController = PageController(initialPage: _currentIndex);
    _audioController = AudioController();
    _userController = Provider.of<UserController>(context, listen: false);
    _friendController = Provider.of<FriendController>(context, listen: false);
    _friendListener = () {
      if (!mounted) return;
      unawaited(_refreshPostsForBlockStatus());
    };
    _friendController?.addListener(_friendListener!);
    _loadUserProfileImage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // 초기 댓글 로드
      _loadCommentsForPost(_posts[_currentIndex].id);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _stopAudio();
    _audioController.dispose();
    if (_friendListener != null) {
      _friendController?.removeListener(_friendListener!);
      _friendListener = null;
    }
    // (배포버전 프리즈 방지) 전역 imageCache.clear()는 캐시가 큰 실사용 환경에서
    // dispose 타이밍에 수 초 프리즈를 만들 수 있어 제거합니다.
    super.dispose();
  }

  Future<void> _refreshPostsForBlockStatus() async {
    if (!mounted) return;
    final userController = _userController ?? context.read<UserController>();
    final currentUser = userController.currentUser;
    if (currentUser == null) return;

    final postController = context.read<PostController>();
    final friendController =
        _friendController ?? context.read<FriendController>();

    final posts = await postController.getPostsByCategory(
      categoryId: widget.categoryId,
      userId: currentUser.id,
      notificationId: null,
    );

    final blockedUsers = await friendController.getAllFriends(
      userId: currentUser.id,
      status: FriendStatus.blocked,
    );
    final blockedIds = blockedUsers.map((user) => user.userId).toSet();
    final filteredPosts = posts
        .where((post) => !blockedIds.contains(post.nickName))
        .toList(growable: false);

    if (!mounted) return;
    if (filteredPosts.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final currentPostId = _posts.isNotEmpty ? _posts[_currentIndex].id : null;
    var nextIndex = 0;
    if (currentPostId != null) {
      final foundIndex = filteredPosts.indexWhere(
        (post) => post.id == currentPostId,
      );
      nextIndex = foundIndex >= 0 ? foundIndex : 0;
    }

    setState(() {
      _posts = filteredPosts;
      _currentIndex = nextIndex;
    });

    if (_pageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_pageController.hasClients) return;
        _pageController.jumpToPage(_currentIndex);
      });
    }

    _loadUserProfileImage();
    _loadCommentsForPost(_posts[_currentIndex].id);
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AudioController>.value(
      value: _audioController,
      child: PopScope(
        canPop: _deletedPostIds.isEmpty || _allowPopWithDeletionResult,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_deletedPostIds.isEmpty) return;
          _popWithDeletionResult();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            iconTheme: const IconThemeData(color: Colors.white),
            backgroundColor: Colors.black,
            title: Text(
              widget.categoryName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              // 다운로드 버튼 (모든 게시물에서 표시)
              if (_posts.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(right: 23.w),
                  child: IconButton(
                    onPressed: _downloadPhoto,
                    icon: Icon(
                      Icons.download_rounded,
                      color: Colors.white,
                      size: 24.w,
                    ),
                  ),
                ),
            ],
          ),
          body: PageView.builder(
            controller: _pageController,
            itemCount: _posts.length,
            scrollDirection: Axis.vertical,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final post = _posts[index];
              final currentUserId = _userController?.currentUser?.userId;
              final isOwner = currentUserId == post.nickName;

              // 사용자 캐시 채우기
              if (!_userProfileImages.containsKey(post.nickName)) {
                _userProfileImages[post.nickName] = _userProfileImageUrl;
                _profileLoadingStates[post.nickName] = _isLoadingProfile;
                _userNames[post.nickName] = _userName;
              }

              // post 사진 카드 위젯 반환
              // post 사진, 카테고리 이름, 카테고리 ID 등 전달
              return ApiPhotoCardWidget(
                post: post,

                // APICategoryPhotosScreen에서 받아온 categoryName을 전달합니다.
                categoryName: widget.categoryName,

                // APICategoryPhotosScreen에서 받아온 categoryId를 전달합니다.
                categoryId: widget.categoryId,
                index: index,
                isOwner: isOwner,
                isArchive: true,
                isCategory: true,
                selectedEmoji:
                    _selectedEmojisByPostId[post.id], // postId별 선택값 표시
                onEmojiSelected: (emoji) => _setSelectedEmoji(post.id, emoji),
                postComments: _postComments,

                voiceCommentActiveStates: _voiceCommentActiveStates,
                voiceCommentSavedStates: _voiceCommentSavedStates,
                pendingTextComments: _pendingTextComments,
                pendingVoiceComments: _pendingCommentMarkers,
                onToggleAudio: _toggleAudio,
                onToggleVoiceComment: _toggleVoiceComment,
                onVoiceCommentCompleted:
                    (postId, audioPath, waveformData, duration) {
                      if (audioPath != null &&
                          waveformData != null &&
                          duration != null) {
                        _onVoiceCommentRecordingFinished(
                          postId,
                          audioPath,
                          waveformData,
                          duration,
                        );
                      }
                    },
                onTextCommentCompleted: (postId, text) async {
                  await _onTextCommentCreated(postId, text);
                },
                onVoiceCommentDeleted: (postId) {
                  setState(() {
                    _voiceCommentActiveStates[postId] = false;
                    _pendingCommentDrafts.remove(postId);
                    _pendingCommentMarkers.remove(postId);
                    _pendingTextComments.remove(postId);
                  });
                },
                onProfileImageDragged: (postId, absolutePosition) {
                  _onProfileImageDragged(postId, absolutePosition);
                },
                onSaveRequested: _onSaveRequested,
                onSaveCompleted: _onSaveCompleted,
                onDeletePressed: () => _deletePost(post),
                onCommentsReloadRequested: _loadCommentsForPost,
                onReportSubmitted: _saveReportToFirebase,
              );
            },
          ),
        ),
      ),
    );
  }

  // ================= 로직 =================

  Future<void> _saveReportToFirebase(Post post, ReportResult report) async {
    final currentUser = _userController?.currentUser;
    final detail = report.detail?.trim();
    final data = <String, dynamic>{
      'postId': post.id,
      'postNickName': post.nickName,
      'categoryId': widget.categoryId,
      'categoryName': widget.categoryName,
      'reason': report.reason,
      'detail': (detail == null || detail.isEmpty) ? null : detail,
      'reporterUserId': currentUser?.id,
      'reporterNickName': currentUser?.userId,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance.collection('post_reports').add(data);
      if (!mounted) return;
      SnackBarUtils.showSnackBar(
        context,
        '신고가 접수되었습니다. 신고 내용을 관리자가 확인 후, 판단 후에 처리하도록 하겠습니다.',
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showSnackBar(context, '신고 접수에 실패했습니다.');
    }
  }

  /// 페이지 변경 시 처리
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _stopAudio();
    _loadUserProfileImage();
    _loadCommentsForPost(_posts[index].id);
  }

  /// 현재 게시물 작성자의 프로필 이미지 로드
  Future<void> _loadUserProfileImage() async {
    final currentPost = _posts[_currentIndex];
    try {
      final userId = int.tryParse(currentPost.nickName);
      api_user.User? user;
      if (userId != null) {
        user = await _userController?.getUser(userId);
      }

      if (!mounted) return;
      setState(() {
        _userProfileImageUrl = user?.profileImageUrlKey ?? '';
        _userName = currentPost.nickName;
        _isLoadingProfile = false;
        _userProfileImages[currentPost.nickName] = _userProfileImageUrl;
        _profileLoadingStates[currentPost.nickName] = false;
        _userNames[currentPost.nickName] = _userName;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _userName = currentPost.nickName;
        _isLoadingProfile = false;
        _userProfileImages[currentPost.nickName] = '';
        _profileLoadingStates[currentPost.nickName] = false;
        _userNames[currentPost.nickName] = currentPost.nickName;
      });
    }
  }

  /// 게시물의 댓글 로드
  Future<void> _loadCommentsForPost(int postId) async {
    try {
      final commentController = Provider.of<CommentController>(
        context,
        listen: false,
      );
      final comments = await commentController.getComments(postId: postId);

      if (!mounted) return;

      final currentUserId = _userController?.currentUser?.userId;
      _handleCommentsUpdate(postId, currentUserId, comments);
    } catch (e) {
      debugPrint('❌ 댓글 로드 실패: $e');
    }
  }

  /// 댓글 목록 업데이트 처리
  void _handleCommentsUpdate(
    int postId,
    String? currentUserId,
    List<Comment> comments,
  ) {
    if (!mounted) return;

    setState(() {
      _postComments[postId] = comments;

      // 서버 댓글을 바탕으로, 내 이모지 선택값을 복원합니다(있을 때만 덮어쓰기).
      if (currentUserId != null) {
        final selected = _selectedEmojiFromComments(
          comments: comments,
          currentUserNickname: currentUserId,
        );
        if (selected != null) {
          _selectedEmojisByPostId[postId] = selected;
        }
      }

      if (comments.isNotEmpty) {
        _voiceCommentSavedStates[postId] = true;
      } else {
        _voiceCommentSavedStates[postId] = false;
      }
    });
  }

  /// 댓글 캐시에 새 댓글 추가
  ///
  /// Parameters:
  ///   - [postId]: 댓글이 추가될 게시물 ID
  ///   - [comment]: 추가할 댓글 객체
  void _addCommentToCache(int postId, Comment comment) {
    if (!mounted) return;
    setState(() {
      final updatedList = List<Comment>.from(
        _postComments[postId] ?? const <Comment>[],
      )..add(comment);
      _postComments[postId] = updatedList;
      _voiceCommentSavedStates[postId] = true;
    });
  }

  /// 프로필 이미지 드래그 시 위치 업데이트 처리
  ///
  /// Parameters:
  /// - [postId]: 프로필 이미지가 드래그된 게시물 ID
  /// - [absolutePosition]: 드래그된 절대 위치
  void _onProfileImageDragged(int postId, Offset absolutePosition) {
    final imageSize = Size(354.w, 500.h); // 프로필 이미지 크기 (고정값)
    final relativePosition = PositionConverter.toRelativePosition(
      absolutePosition,
      imageSize,
    );

    final draft = _pendingCommentDrafts[postId];
    if (draft == null) return;

    setState(() {
      final previousProgress = _pendingCommentMarkers[postId]?.progress;
      _pendingCommentMarkers[postId] = (
        relativePosition: relativePosition,
        profileImageUrlKey: draft.profileImageUrlKey,
        progress: previousProgress,
      );
    });
  }

  /// 오디오 토글 처리
  ///
  /// Parameters:
  ///   - [post]: 오디오 토글할 게시물 객체
  Future<void> _toggleAudio(Post post) async {
    if (!post.hasAudio) return;
    final audioKey = post.audioUrl;
    if (audioKey == null || audioKey.isEmpty) return;
    try {
      var resolved = audioKey;
      final uri = Uri.tryParse(audioKey);
      if (uri == null || !uri.hasScheme) {
        final mediaController = context.read<MediaController>();
        resolved = await mediaController.getPresignedUrl(audioKey) ?? '';
      }
      if (resolved.isEmpty) return;
      _resolvedAudioUrls[post.id] = resolved;
      await _audioController.togglePlayPause(resolved);
    } catch (e) {
      debugPrint('오디오 토글 실패: $e');
    }
  }

  /// 음성 댓글 토글 처리
  ///
  /// Parameters:
  ///   - [postId]: 음성 댓글 토글할 게시물 ID
  void _toggleVoiceComment(int postId) {
    setState(() {
      _voiceCommentActiveStates[postId] =
          !(_voiceCommentActiveStates[postId] ?? false);
    });
  }

  /// 텍스트 댓글 생성 처리
  ///
  /// Parameters:
  ///   - [postId]: 댓글이 생성될 게시물 ID
  /// - [text]: 생성할 텍스트 댓글 내용
  Future<void> _onTextCommentCreated(int postId, String text) async {
    try {
      final userId = _userController?.currentUser?.id;
      if (userId == null) return;

      // 임시 댓글 데이터에 추가
      final currentUserProfileImageUrl =
          _userController?.currentUser?.profileImageUrlKey;

      _pendingCommentDrafts[postId] = (
        isTextComment: true,
        text: text,
        audioPath: null,
        waveformData: null,
        duration: null,
        recorderUserId: userId,
        profileImageUrlKey: currentUserProfileImageUrl,
      );

      if (mounted) {
        setState(() {
          // 댓글이 pending 상태임을 표시
          _pendingTextComments[postId] = true;

          // 음성 댓글 위젯 비활성화
          _voiceCommentSavedStates[postId] = false;
        });
      }
    } catch (e) {
      debugPrint('텍스트 댓글 임시 저장 실패: $e');
    }
  }

  /// 음성 댓글 녹음 완료 처리
  ///
  /// Parameters:
  ///   - [postId]: 댓글이 생성될 게시물 ID
  ///   - [audioPath]: 녹음된 오디오 파일 경로
  ///   - [waveformData]: 녹음된 오디오의 파형 데이터
  ///   - [duration]: 녹음된 오디오의 길이 (밀리초)
  Future<void> _onVoiceCommentRecordingFinished(
    int postId,
    String audioPath,
    List<double> waveformData,
    int duration,
  ) async {
    try {
      final userId = _userController?.currentUser?.id;
      if (userId == null) return;

      final currentUserProfileImageUrl =
          _userController?.currentUser?.profileImageUrlKey;

      _pendingCommentDrafts[postId] = (
        isTextComment: false,
        text: null,
        audioPath: audioPath,
        waveformData: waveformData,
        duration: duration,
        recorderUserId: userId,
        profileImageUrlKey: currentUserProfileImageUrl,
      );

      if (mounted) {
        setState(() {
          _voiceCommentSavedStates[postId] = false;
          _voiceCommentActiveStates[postId] = true;
        });
      }
    } catch (e) {
      debugPrint('음성 댓글 임시 저장 준비 실패: $e');
    }
  }

  Future<void> _onSaveRequested(int postId) async {
    final draft = _pendingCommentDrafts[postId];
    if (draft == null) {
      throw StateError('임시 댓글이 없습니다. postId: $postId');
    }

    final userId = _userController?.currentUser?.id;
    if (userId == null) {
      throw StateError('로그인된 사용자를 찾을 수 없습니다.');
    }

    // 위치가 지정되지 않은 경우 자동 위치 할당 (fallback)
    final finalPosition =
        _pendingCommentMarkers[postId]?.relativePosition ??
        _generateAutoProfilePosition(postId);

    // 저장 중에도 UI 마커가 유지되도록 최종 위치를 마커에 기록
    _pendingCommentMarkers[postId] = (
      relativePosition: finalPosition,
      profileImageUrlKey: draft.profileImageUrlKey,
      progress: 0.0,
    );

    // UI 먼저 업데이트 (낙관적 업데이트)
    setState(() {
      _voiceCommentSavedStates[postId] = true;
      _pendingTextComments.remove(postId);
      _voiceCommentActiveStates[postId] = false;
    });

    // 백그라운드에서 API 호출하여 댓글 저장
    unawaited(_saveCommentToServer(postId, userId, draft, finalPosition));
  }

  /// 백그라운드에서 댓글을 서버에 저장
  Future<void> _saveCommentToServer(
    int postId,
    int userId,
    PendingApiCommentDraft pending,
    Offset relativePosition,
  ) async {
    try {
      _updatePendingProgress(postId, 0.05);
      final commentController = Provider.of<CommentController>(
        context,
        listen: false,
      );

      CommentCreationResult creationResult =
          const CommentCreationResult.failure();

      // 텍스트 댓글 저장 부분
      if (pending.isTextComment && pending.text != null) {
        // 텍스트 댓글 저장
        _updatePendingProgress(postId, 0.4);
        creationResult = await commentController.createTextComment(
          postId: postId,
          userId: userId,
          text: pending.text!,
          locationX: relativePosition.dx,
          locationY: relativePosition.dy,
        );
        _updatePendingProgress(postId, 0.85);
      }
      // 음성 댓글 저장 부분
      else if (pending.audioPath != null) {
        // 음성 댓글 저장
        final mediaController = Provider.of<MediaController>(
          context,
          listen: false,
        );

        _updatePendingProgress(postId, 0.15);
        final audioFile = File(pending.audioPath!);
        _updatePendingProgress(postId, 0.25);
        final multipartFile = await mediaController.fileToMultipart(audioFile);
        final audioKey = await mediaController.uploadCommentAudio(
          file: multipartFile,
          userId: userId,
          postId: postId,
        );

        if (audioKey == null) {
          debugPrint('오디오 업로드 실패: audioKey is null');
          _showSnackBar(
            tr('audio.upload_failed', context: context),
            backgroundColor: Colors.red,
          );
          return;
        }

        // 댓글 생성
        _updatePendingProgress(postId, 0.75);
        final waveformJson = _encodeWaveformForRequest(pending.waveformData);

        // 오디오 댓글 생성
        _updatePendingProgress(postId, 0.85);
        creationResult = await commentController.createAudioComment(
          postId: postId,
          userId: userId,
          audioFileKey: audioKey,
          waveformData: waveformJson!,
          duration: pending.duration!,
          locationX: relativePosition.dx,
          locationY: relativePosition.dy,
        );
        _updatePendingProgress(postId, 0.95);
      }

      if (creationResult.success) {
        _updatePendingProgress(postId, 1.0);
        if (creationResult.comment != null) {
          _addCommentToCache(postId, creationResult.comment!);
        } else {
          await _loadCommentsForPost(postId);
        }

        if (mounted) {
          setState(() {
            _pendingCommentDrafts.remove(postId);
            _pendingCommentMarkers.remove(postId);
          });
        }
      } else {
        _showSnackBar(
          tr('comments.save_failed', context: context),
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      debugPrint('댓글 저장 실패: $e');
      if (mounted) {
        _showSnackBar(
          tr('comments.save_error', context: context),
          backgroundColor: Colors.red,
        );
      }
    }
  }

  void _updatePendingProgress(int postId, double progress) {
    final marker = _pendingCommentMarkers[postId];
    if (marker == null) return;
    final clamped = progress.clamp(0.0, 1.0).toDouble();
    if (!mounted) return;
    setState(() {
      _pendingCommentMarkers[postId] = (
        relativePosition: marker.relativePosition,
        profileImageUrlKey: marker.profileImageUrlKey,
        progress: clamped,
      );
    });
  }

  void _onSaveCompleted(int postId) {
    setState(() {
      _voiceCommentActiveStates[postId] = false;
      _pendingTextComments.remove(postId);
    });
  }

  Offset _generateAutoProfilePosition(int postId) {
    final occupiedPositions = <Offset>[];

    final comments = _postComments[postId] ?? const <Comment>[];
    for (final comment in comments) {
      if (comment.hasLocation) {
        occupiedPositions.add(
          Offset(comment.locationX ?? 0.5, comment.locationY ?? 0.5),
        );
      }
    }

    final pending = _pendingCommentMarkers[postId];
    if (pending != null) {
      occupiedPositions.add(pending.relativePosition);
    }

    const maxAttempts = 30;
    final patternLength = _autoPlacementPattern.length;
    final startingIndex = _autoPlacementIndices[postId] ?? 0;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final rawIndex = startingIndex + attempt;
      final baseOffset = _autoPlacementPattern[rawIndex % patternLength];
      final loop = rawIndex ~/ patternLength;
      final candidate = _applyJitter(baseOffset, loop, attempt);

      if (!_isPositionTooClose(candidate, occupiedPositions)) {
        _autoPlacementIndices[postId] = rawIndex + 1;
        return candidate;
      }
    }

    _autoPlacementIndices[postId] = startingIndex + 1;
    return const Offset(0.5, 0.5);
  }

  Offset _applyJitter(Offset base, int loop, int attempt) {
    if (loop <= 0) {
      return _clampOffset(base);
    }

    final double step = (0.02 * loop).clamp(0.02, 0.08).toDouble();
    final double dxDirection = (attempt % 2 == 0) ? 1 : -1;
    final double dyDirection = ((attempt ~/ 2) % 2 == 0) ? 1 : -1;

    final offsetWithJitter = Offset(
      base.dx + (step * dxDirection),
      base.dy + (step * dyDirection),
    );

    return _clampOffset(offsetWithJitter);
  }

  // 위치를 0.05 ~ 0.95 범위로 제한
  Offset _clampOffset(Offset offset) {
    const double min = 0.05;
    const double max = 0.95;
    return Offset(
      offset.dx.clamp(min, max).toDouble(),
      offset.dy.clamp(min, max).toDouble(),
    );
  }

  // 기존 위치와 너무 가까운지 확인
  bool _isPositionTooClose(Offset candidate, List<Offset> occupied) {
    const double threshold = 0.04;
    for (final existing in occupied) {
      if ((candidate.dx - existing.dx).abs() < threshold &&
          (candidate.dy - existing.dy).abs() < threshold) {
        return true;
      }
    }
    return false;
  }

  // 게시물 삭제 처리
  Future<void> _deletePost(Post post) async {
    try {
      final postController = Provider.of<PostController>(
        context,
        listen: false,
      );

      debugPrint("사진 삭제 시도: postId=${post.id}");

      // MoreMenuButton의 '사진 삭제' 바텀시트에서 이미 확인을 받았으므로,
      // 여기서는 추가 다이얼로그 없이 바로 상태를 DELETED로 변경합니다.
      final success = await postController.setPostStatus(
        postId: post.id,
        postStatus: PostStatus.deleted,
      );

      if (!mounted) return;
      if (success) {
        _deletedPostIds.add(post.id);
        _showSnackBar(tr('archive.photo_deleted', context: context));

        // 삭제 후 처리
        _handleSuccessfulDeletion(post);

        final userId = _userController?.currentUser?.id;
        if (userId != null) {
          unawaited(
            Provider.of<api_category.CategoryController>(
              context,
              listen: false,
            ).loadCategories(userId, forceReload: true),
          );
        }
      } else {
        _showSnackBar(tr('archive.delete_error', context: context));
      }
    } catch (e) {
      _showSnackBar(
        tr(
          'archive.delete_error_with_reason',
          context: context,
          namedArgs: {'error': e.toString()},
        ),
      );
      debugPrint('사진 삭제 실패: $e');
    }
  }

  void _popWithDeletionResult() {
    if (_allowPopWithDeletionResult) return;
    setState(() => _allowPopWithDeletionResult = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop(_deletedPostIds.toList(growable: false));
    });
  }

  // 삭제 후 상태 업데이트 처리
  void _handleSuccessfulDeletion(Post post) {
    if (_posts.length <= 1) {
      if (_deletedPostIds.isEmpty) {
        Navigator.of(context).pop();
      } else {
        _popWithDeletionResult();
      }
      return;
    }
    setState(() {
      // 현재 인덱스 조정
      _posts.removeWhere((p) => p.id == post.id);
      if (_currentIndex >= _posts.length) {
        _currentIndex = _posts.length - 1;
      }
    });

    if (_pageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_pageController.hasClients) return;
        if (_currentIndex < 0 || _currentIndex >= _posts.length) return;
        _pageController.jumpToPage(_currentIndex);
      });
    }

    // profile 이미지 및 댓글 재로딩
    _loadUserProfileImage();
    _loadCommentsForPost(_posts[_currentIndex].id);
  }

  Future<void> _stopAudio() async {
    await _audioController.stopRealtimeAudio();
  }

  /// 미디어(사진/비디오) 다운로드 처리
  Future<void> _downloadPhoto() async {
    try {
      final currentPost = _posts[_currentIndex];
      final mediaKey = currentPost.postFileKey;

      if (mediaKey == null || mediaKey.isEmpty) {
        _showSnackBar('다운로드할 미디어가 없습니다.');
        return;
      }

      final isVideo = currentPost.isVideo;

      // MediaController로 presigned URL 획득
      final mediaController = context.read<MediaController>();
      String? mediaUrl = mediaKey;

      // URL이 아닌 키인 경우 presigned URL 획득
      final uri = Uri.tryParse(mediaKey);
      if (uri == null || !uri.hasScheme) {
        mediaUrl = await mediaController.getPresignedUrl(mediaKey);
      }

      if (mediaUrl == null || mediaUrl.isEmpty) {
        _showSnackBar('미디어 URL을 가져올 수 없습니다.');
        return;
      }

      // 미디어 다운로드
      final response = await http.get(Uri.parse(mediaUrl));

      if (response.statusCode != 200) {
        _showSnackBar('다운로드에 실패했습니다.');
        return;
      }

      final Uint8List bytes = response.bodyBytes;

      if (isVideo) {
        // 비디오의 경우: 임시 파일로 저장 후 갤러리에 저장
        final tempDir = await getTemporaryDirectory();
        final fileName = "SOI_${DateTime.now().millisecondsSinceEpoch}.mp4";
        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(bytes);

        await Gal.putVideo(tempFile.path);

        // 임시 파일 삭제
        try {
          await tempFile.delete();
        } catch (_) {}
      } else {
        // 이미지의 경우: 바로 저장
        await Gal.putImageBytes(bytes);
      }

      _showSnackBar('갤러리에 저장되었습니다.');
    } catch (e) {
      debugPrint('다운로드 실패: $e');
      _showSnackBar('다운로드 중 오류가 발생했습니다.');
    }
  }

  // 스낵바 틀 함수
  String? _encodeWaveformForRequest(List<double>? waveformData) {
    if (waveformData == null || waveformData.isEmpty) return null;
    final sampled = _sampleWaveformData(waveformData, _kMaxWaveformSamples);
    final rounded = sampled
        .map((value) => double.parse(value.toStringAsFixed(4)))
        .toList();
    return jsonEncode(rounded);
  }

  List<double> _sampleWaveformData(List<double> source, int maxLength) {
    if (source.length <= maxLength) return source;
    final step = source.length / maxLength;
    return List<double>.generate(
      maxLength,
      (index) => source[(index * step).floor()],
    );
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    SnackBarUtils.showSnackBar(context, message);
  }
}
