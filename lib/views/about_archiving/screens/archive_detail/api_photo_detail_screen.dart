import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../api/models/post.dart';
import '../../../../api/models/comment.dart';
import '../../../../api/models/comment_creation_result.dart';
import '../../../../api/models/user.dart' as api_user;
import '../../../../api/controller/user_controller.dart';
import '../../../../api/controller/comment_controller.dart';
import '../../../../api/controller/post_controller.dart';
import '../../../../api/controller/media_controller.dart';
import '../../../../api/controller/audio_controller.dart';
import '../../../../utils/position_converter.dart';
import '../../../about_share/share_screen.dart';
import '../../../common_widget/api_photo/api_photo_card_widget.dart';
import '../../../common_widget/api_photo/pending_api_voice_comment.dart';

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
  late final AudioController _audioController;

  // 사용자 프로필 관련
  String _userProfileImageUrl = '';
  String _userName = '';
  bool _isLoadingProfile = true;

  // 컨트롤러
  UserController? _userController;

  // 상태 맵 (Firebase 버전과 동일한 구조)
  final Map<int, List<Comment>> _postComments = {};
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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _audioController = AudioController();
    _userController = Provider.of<UserController>(context, listen: false);
    _loadUserProfileImage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // 초기 댓글 로드
      _loadCommentsForPost(widget.allPosts[_currentIndex].id);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _stopAudio();
    _audioController.dispose();
    PaintingBinding.instance.imageCache.clear();
    super.dispose();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AudioController>.value(
      value: _audioController,
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
            Padding(
              padding: EdgeInsets.only(right: 23.w),
              child: IconButton(
                onPressed: () async {
                  // 현재 게시물 정보 가져오기
                  final currentPost = widget.allPosts[_currentIndex];

                  // 오디오 재생 시간 계산
                  Duration audioDuration = Duration(
                    seconds: currentPost.durationInSeconds,
                  );

                  // 현재 게시물이 오디오를 포함하는 경우 재생 시간 업데이트
                  if (currentPost.hasAudio) {
                    final resolvedUrl =
                        _resolvedAudioUrls[currentPost.id] ??
                        currentPost.audioUrl;
                    if (resolvedUrl != null &&
                        _audioController.currentAudioUrl == resolvedUrl) {
                      audioDuration = _audioController.totalDuration;
                    }
                  }

                  // waveformData 파싱
                  List<double>? waveformData;
                  if (currentPost.waveformData != null &&
                      currentPost.waveformData!.isNotEmpty) {
                    try {
                      final decoded = jsonDecode(currentPost.waveformData!);
                      if (decoded is List) {
                        waveformData = decoded
                            .map((e) => (e as num).toDouble())
                            .toList();
                      }
                    } catch (_) {}
                  }

                  if (!mounted) return;
                  // 공유 화면으로 이동
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShareScreen(
                        imageUrl: currentPost.userProfileImageKey ?? '',
                        waveformData: waveformData,
                        audioDuration: audioDuration,
                        categoryName: widget.categoryName,
                      ),
                    ),
                  );
                },
                icon: Image.asset(
                  'assets/share_icon.png',
                  width: 20.w,
                  height: 20.h,
                ),
              ),
            ),
          ],
        ),
        body: PageView.builder(
          controller: _pageController,
          itemCount: widget.allPosts.length,
          scrollDirection: Axis.vertical,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) {
            final post = widget.allPosts[index];
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
            );
          },
        ),
      ),
    );
  }

  // ================= 로직 =================

  /// 페이지 변경 시 처리
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _stopAudio();
    _loadUserProfileImage();
    _loadCommentsForPost(widget.allPosts[index].id);
  }

  /// 현재 게시물 작성자의 프로필 이미지 로드
  Future<void> _loadUserProfileImage() async {
    final currentPost = widget.allPosts[_currentIndex];
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
  void _onProfileImageDragged(int postId, Offset absolutePosition) {
    final imageSize = Size(354.w, 500.h);
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
          _showSnackBar('음성 업로드에 실패했습니다.', backgroundColor: Colors.red);
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
        _showSnackBar('댓글 저장에 실패했습니다.', backgroundColor: Colors.red);
      }
    } catch (e) {
      debugPrint('댓글 저장 실패: $e');
      if (mounted) {
        _showSnackBar('댓글 저장 중 오류가 발생했습니다.', backgroundColor: Colors.red);
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
    // 삭제 확인 다이얼로그 표시
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        title: Text(
          '삭제 확인',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          '이 사진을 삭제하시겠습니까?',
          style: TextStyle(
            color: Colors.grey[300],
            fontSize: 14.sp,
            fontFamily: 'Pretendard',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              '취소',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14.sp,
                fontFamily: 'Pretendard',
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '삭제',
              style: TextStyle(
                color: Colors.red,
                fontSize: 14.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final postController = Provider.of<PostController>(
        context,
        listen: false,
      );
      // 삭제를 요청하고 결과 대기
      final success = await postController.deletePost(post.id);

      if (!mounted) return;
      if (success) {
        _showSnackBar('사진이 삭제되었습니다.');

        // 삭제 후 처리
        _handleSuccessfulDeletion(post);
      } else {
        _showSnackBar('삭제 중 오류가 발생했습니다.');
      }
    } catch (e) {
      _showSnackBar('삭제 중 오류가 발생했습니다: $e');
    }
  }

  // 삭제 후 상태 업데이트 처리
  void _handleSuccessfulDeletion(Post post) {
    if (widget.allPosts.length <= 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      // 현재 인덱스 조정
      widget.allPosts.removeWhere((p) => p.id == post.id);
      if (_currentIndex >= widget.allPosts.length) {
        _currentIndex = widget.allPosts.length - 1;
      }
    });

    // profile 이미지 및 댓글 재로딩
    _loadUserProfileImage();
    _loadCommentsForPost(widget.allPosts[_currentIndex].id);
  }

  Future<void> _stopAudio() async {
    await _audioController.stopRealtimeAudio();
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          height: 30.h,
          alignment: Alignment.center,
          child: Text(
            message,
            style: TextStyle(fontFamily: 'Pretendard', fontSize: 14.sp),
          ),
        ),
        backgroundColor: backgroundColor ?? const Color(0xFF5A5A5A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
      ),
    );
  }
}
