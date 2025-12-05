import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../api/models/post.dart';
import '../../../../api/models/comment.dart';
import '../../../../api/models/user.dart' as api_user;
import '../../../../api/controller/user_controller.dart';
import '../../../../api/controller/comment_controller.dart';
import '../../../../api/controller/post_controller.dart';
import '../../../../api/controller/media_controller.dart';
import '../../../../api_firebase/controllers/audio_controller.dart';
import '../../../../utils/position_converter.dart';
import '../../../about_share/share_screen.dart';
import '../../../common_widget/api_photo/api_photo_card_widget.dart';

/// API 기반 사진 상세 화면
///
/// Firebase 버전의 PhotoDetailScreen과 동일한 디자인을 유지하면서
/// REST API와 공통 위젯을 사용합니다.
class ApiPhotoDetailScreen extends StatefulWidget {
  final List<Post> posts;
  final int initialIndex;
  final String categoryName;
  final int categoryId;

  const ApiPhotoDetailScreen({
    super.key,
    required this.posts,
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
  final Map<int, PendingApiVoiceComment> _pendingVoiceComments = {};
  final Map<int, bool> _pendingTextComments = {};

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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _userController = Provider.of<UserController>(context, listen: false);
    _loadUserProfileImage();
    _loadCommentsForPost(widget.posts[_currentIndex].id);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _stopAudio();
    PaintingBinding.instance.imageCache.clear();
    super.dispose();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                final currentPost = widget.posts[_currentIndex];
                Duration audioDuration = Duration(
                  seconds: currentPost.durationInSeconds,
                );

                if (currentPost.hasAudio) {
                  final audioController = Provider.of<AudioController>(
                    context,
                    listen: false,
                  );
                  if (audioController.currentPlayingAudioUrl ==
                      currentPost.audioUrl) {
                    audioDuration = audioController.currentDuration;
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShareScreen(
                      imageUrl: currentPost.imageUrl ?? '',
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
        itemCount: widget.posts.length,
        scrollDirection: Axis.vertical,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final post = widget.posts[index];
          final currentUserId = _userController?.currentUser?.userId;
          final isOwner = currentUserId == post.userId;

          // 사용자 캐시 채우기
          if (!_userProfileImages.containsKey(post.userId)) {
            _userProfileImages[post.userId] = _userProfileImageUrl;
            _profileLoadingStates[post.userId] = _isLoadingProfile;
            _userNames[post.userId] = _userName;
          }

          return ApiPhotoCardWidget(
            post: post,
            categoryName: widget.categoryName,
            categoryId: widget.categoryId,
            index: index,
            isOwner: isOwner,
            isArchive: true,
            isCategory: true,
            postComments: _postComments,
            userProfileImages: _userProfileImages,
            profileLoadingStates: _profileLoadingStates,
            userNames: _userNames,
            voiceCommentActiveStates: _voiceCommentActiveStates,
            voiceCommentSavedStates: _voiceCommentSavedStates,
            pendingTextComments: _pendingTextComments,
            pendingVoiceComments: _pendingVoiceComments,
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
                _pendingVoiceComments.remove(postId);
              });
            },
            onProfileImageDragged: (postId, absolutePosition) {
              _onProfileImageDragged(postId, absolutePosition);
            },
            onSaveRequested: _onSaveRequested,
            onSaveCompleted: _onSaveCompleted,
            onDeletePressed: () => _deletePost(post),
          );
        },
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
    _loadCommentsForPost(widget.posts[index].id);
  }

  /// 현재 게시물 작성자의 프로필 이미지 로드
  Future<void> _loadUserProfileImage() async {
    final currentPost = widget.posts[_currentIndex];
    try {
      final userId = int.tryParse(currentPost.userId);
      api_user.User? user;
      if (userId != null) {
        user = await _userController?.getUser(userId);
      }

      if (!mounted) return;
      setState(() {
        _userProfileImageUrl = user?.profileImageUrlKey ?? '';
        _userName = user?.userId ?? currentPost.userId;
        _isLoadingProfile = false;
        _userProfileImages[currentPost.userId] = _userProfileImageUrl;
        _profileLoadingStates[currentPost.userId] = false;
        _userNames[currentPost.userId] = _userName;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _userName = currentPost.userId;
        _isLoadingProfile = false;
        _userProfileImages[currentPost.userId] = '';
        _profileLoadingStates[currentPost.userId] = false;
        _userNames[currentPost.userId] = currentPost.userId;
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

  /// 프로필 이미지 드래그 시 위치 업데이트 처리
  void _onProfileImageDragged(int postId, Offset absolutePosition) {
    final imageSize = Size(354.w, 500.h);
    final relativePosition = PositionConverter.toRelativePosition(
      absolutePosition,
      imageSize,
    );

    final pending = _pendingVoiceComments[postId];

    if (pending != null) {
      _pendingVoiceComments[postId] = pending.copyWith(
        relativePosition: relativePosition,
      );
      return;
    }
  }

  void _toggleAudio(Post post) async {
    if (!post.hasAudio) return;
    try {
      final audioController = Provider.of<AudioController>(
        context,
        listen: false,
      );
      await audioController.toggleAudio(post.audioUrl!);
    } catch (e) {
      debugPrint('오디오 토글 실패: $e');
    }
  }

  void _toggleVoiceComment(int postId) {
    setState(() {
      _voiceCommentActiveStates[postId] =
          !(_voiceCommentActiveStates[postId] ?? false);
    });
  }

  Future<void> _onTextCommentCreated(int postId, String text) async {
    try {
      final userId = _userController?.currentUser?.id;
      if (userId == null) return;

      final currentUserProfileImageUrl =
          _userController?.currentUser?.profileImageUrlKey;

      _pendingVoiceComments[postId] = PendingApiVoiceComment(
        text: text,
        isTextComment: true,
        audioPath: null,
        waveformData: null,
        duration: null,
        recorderUserId: userId,
        profileImageUrl: currentUserProfileImageUrl,
        relativePosition: null, // 사용자가 드래그로 위치 지정
      );

      if (mounted) {
        setState(() {
          _pendingTextComments[postId] = true;
          _voiceCommentSavedStates[postId] = false;
        });
      }
    } catch (e) {
      debugPrint('텍스트 댓글 임시 저장 실패: $e');
    }
  }

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

      _pendingVoiceComments[postId] = PendingApiVoiceComment(
        audioPath: audioPath,
        waveformData: waveformData,
        duration: duration,
        recorderUserId: userId,
        profileImageUrl: currentUserProfileImageUrl,
        relativePosition: null, // 사용자가 드래그로 위치 지정
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
    final pending = _pendingVoiceComments[postId];
    if (pending == null) {
      throw StateError('임시 댓글이 없습니다. postId: $postId');
    }

    final userId = _userController?.currentUser?.id;
    if (userId == null) {
      throw StateError('로그인된 사용자를 찾을 수 없습니다.');
    }

    // 위치가 지정되지 않은 경우 자동 위치 할당 (fallback)
    final finalPosition =
        pending.relativePosition ?? _generateAutoProfilePosition(postId);

    // 백그라운드 저장을 위해 pending 데이터 복사
    final pendingCopy = PendingApiVoiceComment(
      audioPath: pending.audioPath,
      waveformData: pending.waveformData,
      duration: pending.duration,
      text: pending.text,
      isTextComment: pending.isTextComment,
      relativePosition: finalPosition,
      recorderUserId: pending.recorderUserId,
      profileImageUrl: pending.profileImageUrl,
    );

    // UI 먼저 업데이트 (낙관적 업데이트)
    setState(() {
      _voiceCommentSavedStates[postId] = true;
      _pendingVoiceComments.remove(postId);
      _pendingTextComments.remove(postId);
      _voiceCommentActiveStates[postId] = false;
    });

    // 백그라운드에서 API 호출하여 댓글 저장
    unawaited(_saveCommentToServer(postId, userId, pendingCopy));
  }

  /// 백그라운드에서 댓글을 서버에 저장
  Future<void> _saveCommentToServer(
    int postId,
    int userId,
    PendingApiVoiceComment pending,
  ) async {
    try {
      final commentController = Provider.of<CommentController>(
        context,
        listen: false,
      );

      bool success = false;

      // 텍스트 댓글 저장 부분
      if (pending.isTextComment && pending.text != null) {
        // 텍스트 댓글 저장
        success = await commentController.createTextComment(
          postId: postId,
          userId: userId,
          text: pending.text!,
          locationX: pending.relativePosition?.dx,
          locationY: pending.relativePosition?.dy,
        );
      }
      // 음성 댓글 저장 부분
      else if (pending.audioPath != null) {
        // 음성 댓글 저장
        final mediaController = Provider.of<MediaController>(
          context,
          listen: false,
        );

        final audioFile = File(pending.audioPath!);
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
        String? waveformJson;
        if (pending.waveformData != null) {
          // 소수점 4자리로 반올림하여 문자열 길이 줄이기 (서버 제한 대응)
          final roundedWaveform = pending.waveformData!
              .map((v) => double.parse(v.toStringAsFixed(4)))
              .toList();
          waveformJson = jsonEncode(roundedWaveform);
        }

        // 오디오 댓글 생성
        success = await commentController.createAudioComment(
          postId: postId,
          userId: userId,
          audioKey: audioKey,
          waveformData: waveformJson,
          duration: pending.duration,
          locationX: pending.relativePosition?.dx,
          locationY: pending.relativePosition?.dy,
        );
      }

      if (success) {
        // 댓글 목록 새로고침
        await _loadCommentsForPost(postId);
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

  void _onSaveCompleted(int postId) {
    setState(() {
      _voiceCommentActiveStates[postId] = false;
      _pendingVoiceComments.remove(postId);
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

    final pending = _pendingVoiceComments[postId];
    if (pending?.relativePosition != null) {
      occupiedPositions.add(pending!.relativePosition!);
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

  Offset _clampOffset(Offset offset) {
    const double min = 0.05;
    const double max = 0.95;
    return Offset(
      offset.dx.clamp(min, max).toDouble(),
      offset.dy.clamp(min, max).toDouble(),
    );
  }

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
      final success = await postController.deletePost(post.id);

      if (!mounted) return;
      if (success) {
        _showSnackBar('사진이 삭제되었습니다.');
        _handleSuccessfulDeletion(post);
      } else {
        _showSnackBar('삭제 중 오류가 발생했습니다.');
      }
    } catch (e) {
      _showSnackBar('삭제 중 오류가 발생했습니다: $e');
    }
  }

  void _handleSuccessfulDeletion(Post post) {
    if (widget.posts.length <= 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      widget.posts.removeWhere((p) => p.id == post.id);
      if (_currentIndex >= widget.posts.length) {
        _currentIndex = widget.posts.length - 1;
      }
    });
    _loadUserProfileImage();
    _loadCommentsForPost(widget.posts[_currentIndex].id);
  }

  Future<void> _stopAudio() async {
    final audioController = Provider.of<AudioController>(
      context,
      listen: false,
    );
    await audioController.stopRealtimeAudio();
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
