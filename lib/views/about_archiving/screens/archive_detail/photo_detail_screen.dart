import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../../api_firebase/controllers/audio_controller.dart';
import '../../../../api_firebase/controllers/auth_controller.dart';
import '../../../../api_firebase/controllers/comment_record_controller.dart';
import '../../../../api_firebase/controllers/media_controller.dart';
import '../../../../api_firebase/models/comment_record_model.dart';
import '../../../../api_firebase/models/photo_data_model.dart';
import '../../../../utils/position_converter.dart';
import '../../../about_share/share_screen.dart';
import '../../../common_widget/abput_photo/photo_card_widget_common.dart';
import '../../../about_feed/manager/voice_comment_state_manager.dart';

/// 카테고리 내에서 사진 하나를 개별적으로 보여주는 화면
/// 사용자는 사진에 대한 댓글을 달고, 음성 댓글을 남기고, 사진을 공유할 수 있습니다.
class PhotoDetailScreen extends StatefulWidget {
  final List<MediaDataModel> photos;
  final int initialIndex;
  final String categoryName;
  final String categoryId;

  const PhotoDetailScreen({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    required this.categoryName,
    required this.categoryId,
  });

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  // 사용자 프로필 관련
  String _userProfileImageUrl = '';
  String _userName = '';
  bool _isLoadingProfile = true;
  int _profileImageRefreshKey = 0;

  // 컨트롤러
  AuthController? _authController;

  // 상태 맵 (Feed 구조와 동일)
  final Map<String, List<CommentRecordModel>> _photoComments = {};
  final Map<String, bool> _voiceCommentActiveStates = {};
  final Map<String, bool> _voiceCommentSavedStates = {};
  final Map<String, String> _userProfileImages = {};
  final Map<String, bool> _profileLoadingStates = {};
  final Map<String, String> _userNames = {};
  final Map<String, CommentRecordModel> _pendingVoiceComments = {};
  final Map<String, bool> _pendingTextComments = {}; // 텍스트 댓글 pending 상태
  final Map<String, List<String>> _savedCommentIds = {};
  final Map<String, Offset> _commentPositions = {};
  final Map<String, StreamSubscription<List<CommentRecordModel>>>
  _commentStreams = {};

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

  final Map<String, int> _autoPlacementIndices = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _authController = Provider.of<AuthController>(context, listen: false);
    _authController?.addListener(_onAuthControllerChanged);
    _loadUserProfileImage();
    _subscribeToVoiceCommentsForCurrentPhoto();
    _loadCommentsForPhoto(widget.photos[_currentIndex].id);
  }

  @override
  void dispose() {
    for (final sub in _commentStreams.values) {
      sub.cancel();
    }
    _commentStreams.clear();
    _authController?.removeListener(_onAuthControllerChanged);
    _pageController.dispose();

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
                final currentPhoto = widget.photos[_currentIndex];
                Duration audioDuration = currentPhoto.duration;
                if (currentPhoto.audioUrl.isNotEmpty) {
                  final audioController = _getAudioController;
                  if (audioController.currentPlayingAudioUrl ==
                      currentPhoto.audioUrl) {
                    audioDuration = audioController.currentDuration;
                  }
                }
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShareScreen(
                      imageUrl: currentPhoto.imageUrl,
                      waveformData: currentPhoto.waveformData,
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
        itemCount: widget.photos.length,
        scrollDirection: Axis.vertical,
        onPageChanged: _onPageChanged,

        itemBuilder: (context, index) {
          final photo = widget.photos[index];
          final authController = _getAuthController;
          final currentUserId = authController.getUserId;
          final isOwner = currentUserId == photo.userID;

          // 사용자 캐시 채우기
          if (!_userProfileImages.containsKey(photo.userID)) {
            _userProfileImages[photo.userID] = _userProfileImageUrl;
            _profileLoadingStates[photo.userID] = _isLoadingProfile;
            _userNames[photo.userID] = _userName;
          }

          final pendingVoiceCommentMap = _pendingVoiceComments
              .map<String, PendingVoiceComment>((photoId, comment) {
                final relativeOffset = _extractRelativeOffset(
                  comment.relativePosition,
                );
                return MapEntry(
                  photoId,
                  PendingVoiceComment(
                    audioPath: comment.audioUrl.isNotEmpty
                        ? comment.audioUrl
                        : null,
                    waveformData: comment.waveformData,
                    duration: comment.duration,
                    text: comment.text,
                    isTextComment: comment.type == CommentType.text,
                    relativePosition: relativeOffset,
                    recorderUserId: comment.recorderUser,
                    profileImageUrl: comment.profileImageUrl,
                  ),
                );
              });

          return PhotoCardWidgetCommon(
            photo: photo,
            categoryName: widget.categoryName,
            categoryId: widget.categoryId,
            index: index,
            isOwner: isOwner,
            isArchive: true,
            isCategory: true,
            photoComments: _photoComments,
            userProfileImages: _userProfileImages,
            profileLoadingStates: _profileLoadingStates,
            userNames: _userNames,
            voiceCommentActiveStates: _voiceCommentActiveStates,
            voiceCommentSavedStates: _voiceCommentSavedStates,
            pendingTextComments: _pendingTextComments,
            pendingVoiceComments: pendingVoiceCommentMap,
            onToggleAudio: _toggleAudio,
            onToggleVoiceComment: _toggleVoiceComment,
            onVoiceCommentCompleted:
                (photoId, audioPath, waveformData, duration) {
                  if (audioPath != null &&
                      waveformData != null &&
                      duration != null) {
                    _onVoiceCommentRecordingFinished(
                      photoId,
                      audioPath,
                      waveformData,
                      duration,
                    );
                  }
                },
            onTextCommentCompleted: (photoId, text) async {
              // 텍스트 댓글을 pending 상태로 저장
              await _onTextCommentCreated(photoId, text);
            },
            onVoiceCommentDeleted: (photoId) {
              setState(() {
                _voiceCommentActiveStates[photoId] = false;
                _pendingVoiceComments.remove(photoId);
              });
            },
            onProfileImageDragged: (photoId, absolutePosition) {
              // pending이 있으면 새 댓글용 프로필 배치이므로 기존 댓글 ID 불필요
              final hasPending = _pendingVoiceComments[photoId] != null;
              String? latestCommentId;

              // pending이 없을 때만 기존 댓글 위치 업데이트 대상(commentId)을 찾음
              // **pending이 있으면 새 댓글용이므로 기존 댓글을 건드리지 않음**
              if (!hasPending) {
                final list = _photoComments[photoId];
                if (list != null) {
                  final userComments = list
                      .where((comment) => comment.recorderUser == currentUserId)
                      .toList();
                  if (userComments.isNotEmpty) {
                    latestCommentId = userComments.last.id;
                  }
                }
              }

              // latestCommentId:
              // - pending 있음 → null (새 댓글용 프로필 배치)
              // - pending 없음 → 마지막 댓글 ID (기존 댓글 위치 수정)
              //   - pending이 없는 경우는 거의 없음. 대부분 새 댓글 작성 중이기 때문.
              //   - 하지만, 만약을 대비해 처리 로직을 분리함.
              _onProfileImageDragged(
                photoId,
                absolutePosition,
                commentId: latestCommentId,
              );
            },

            // 저장 요청: Optimistic UI 패턴으로 즉시 UI에 프로필 표시 후
            // 백그라운드에서 Firestore 저장 수행
            onSaveRequested: _onSaveRequested,

            // 저장 완료 후 상태 정리 (active 모드 해제, pending 제거)
            onSaveCompleted: _onSaveCompleted,

            // 사진 삭제 (소프트 삭제)
            // 영구 삭제가 아님 --> 소프트 삭제 처리 후 필요 시 복구 가능
            onDeletePressed: () => _deletePhoto(photo),
          );
        },
      ),
    );
  }

  /// 페이지 변경 시 현재 사진 인덱스를 업데이트하고, 오디오 정지 및 새 사진의 데이터 로드 수행.
  /// 프로필 이미지 새로고침, 음성 댓글 구독, 댓글 로드를 포함한 작업 처리.
  void _onPageChanged(int index) {
    final newPhotoId = widget.photos[index].id;
    setState(() {
      _currentIndex = index;
      _profileImageRefreshKey++;
    });
    _stopAudio();
    _loadUserProfileImage();
    _subscribeToVoiceCommentsForCurrentPhoto();
    _loadCommentsForPhoto(newPhotoId);
  }

  // 사진에 대한 댓글 로드
  // 해당 사진에 태그 되어있는 모든 댓글을 불러와 상태에 반영
  Future<void> _loadCommentsForPhoto(String photoId) async {
    try {
      final controller = CommentRecordController();
      await controller.loadCommentRecordsByPhotoId(photoId);
      final comments = controller.getCommentsByPhotoId(photoId);
      final currentUserId = _authController?.currentUser?.uid;
      if (currentUserId != null) {
        _handleCommentsUpdate(photoId, currentUserId, comments);
      }
    } catch (e) {
      debugPrint('❌ 댓글 직접 로드 실패: $e');
    }
  }

  // AuthController 변경 시 처리
  // 프로필 이미지 새로고침 및 음성 댓글 구독 갱신
  void _onAuthControllerChanged() {
    if (!mounted) return;
    setState(() => _profileImageRefreshKey++);

    // 프로필 이미지 새로고침
    _loadUserProfileImage();

    // 음성 댓글 구독 갱신
    _subscribeToVoiceCommentsForCurrentPhoto();
  }

  Future<void> _loadUserProfileImage() async {
    final currentPhoto = widget.photos[_currentIndex];
    try {
      final auth = _getAuthController;
      final profileImageUrl = await auth.getUserProfileImageUrlById(
        currentPhoto.userID,
      );
      final userInfo = await auth.getUserInfo(currentPhoto.userID);
      if (!mounted) return;
      setState(() {
        _userProfileImageUrl = profileImageUrl;
        _userName = userInfo?.id ?? currentPhoto.userID;
        _isLoadingProfile = false;
        _userProfileImages[currentPhoto.userID] = profileImageUrl;
        _profileLoadingStates[currentPhoto.userID] = false;
        _userNames[currentPhoto.userID] = _userName;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _userName = currentPhoto.userID;
        _isLoadingProfile = false;
        _userProfileImages[currentPhoto.userID] = '';
        _profileLoadingStates[currentPhoto.userID] = false;
        _userNames[currentPhoto.userID] = currentPhoto.userID;
      });
    }
  }

  // 현재 사진에 대한 음성 댓글 실시간 구독 설정
  // 댓글이 추가/수정/삭제될 때마다 상태를 업데이트
  void _subscribeToVoiceCommentsForCurrentPhoto() {
    final photoId = widget.photos[_currentIndex].id;
    try {
      _commentStreams[photoId]?.cancel();
      final currentUserId = _authController?.currentUser?.uid;

      if (currentUserId == null) return;

      // 실시간 스트림 구독 설정
      // 댓글이 변경될 때마다 _handleCommentsUpdate 호출
      _commentStreams[photoId] = CommentRecordController()
          .getCommentRecordsStream(photoId)
          .listen(
            (comments) =>
                _handleCommentsUpdate(photoId, currentUserId, comments),
          );
    } catch (e) {
      debugPrint('실시간 댓글 구독 실패($photoId): $e');
    }
  }

  // 댓글 목록이 변경될 때 상태 업데이트 처리
  // 특정 사진에 대한 댓글이 추가/수정/삭제될 때마다 호출됩니다.
  void _handleCommentsUpdate(
    String photoId,
    String currentUserId,
    List<CommentRecordModel> comments,
  ) {
    if (!mounted) return;

    final userComments = comments
        .where((comment) => comment.recorderUser == currentUserId)
        .toList();

    setState(() {
      _photoComments[photoId] = comments;

      if (userComments.isNotEmpty) {
        _voiceCommentSavedStates[photoId] = true;

        final updatedIds = userComments.map((c) => c.id).toList();
        _savedCommentIds[photoId] = updatedIds;

        for (final comment in userComments) {
          final relative = _extractRelativeOffset(comment.relativePosition);
          if (relative != null) {
            _commentPositions[comment.id] = relative;
          }
        }
      } else {
        _voiceCommentSavedStates[photoId] = false;
        final previousIds = _savedCommentIds[photoId] ?? const <String>[];
        _savedCommentIds.remove(photoId);

        _autoPlacementIndices.remove(photoId);
        for (final commentId in previousIds) {
          _commentPositions.remove(commentId);
        }
      }
    });
  }

  // 프로필 이미지 드래그 시 위치 업데이트 처리
  // pending이 있으면 새 댓글용 프로필 배치
  // pending이 없으면 기존 댓글 위치 수정
  void _onProfileImageDragged(
    String photoId,
    Offset absolutePosition, {
    String? commentId,
  }) {
    final imageSize = Size(354.w, 500.h);
    final relativePosition = PositionConverter.toRelativePosition(
      absolutePosition,
      imageSize,
    );

    final pending = _pendingVoiceComments[photoId];

    // pending이 null이 아닌 경우, 기존 댓글 위치를 업데이트함.
    if (pending != null) {
      _pendingVoiceComments[photoId] = pending.copyWith(
        relativePosition: relativePosition,
      );
      return;
    }

    // pending이 null인 경우, 기존 댓글 위치 업데이트
    // pending이 null이란 것은 새로운 태그가 생성되었음을 의미하기 때문.
    if (commentId != null && commentId.isNotEmpty) {
      _updateProfilePositionInFirestore(photoId, commentId, relativePosition);
    }
  }

  Future<void> _updateProfilePositionInFirestore(
    String photoId,
    String commentId,
    Offset relativePosition,
  ) async {
    try {
      if (commentId.isEmpty) return;
      await CommentRecordController().updateRelativeProfilePosition(
        commentId: commentId,
        photoId: photoId,
        relativePosition: relativePosition,
      );
      if (mounted) {
        setState(() {
          _commentPositions[commentId] = relativePosition;
        });
      } else {
        _commentPositions[commentId] = relativePosition;
      }
    } catch (e) {
      debugPrint('프로필 위치 업데이트 실패: $e');
    }
  }

  void _toggleAudio(MediaDataModel photo) async {
    if (photo.audioUrl.isEmpty) return;
    try {
      await _getAudioController.toggleAudio(photo.audioUrl);
    } catch (e) {
      debugPrint('오디오 토글 실패: $e');
    }
  }

  void _toggleVoiceComment(String photoId) {
    setState(() {
      _voiceCommentActiveStates[photoId] =
          !(_voiceCommentActiveStates[photoId] ?? false);
    });
  }

  Future<void> _onTextCommentCreated(String photoId, String text) async {
    try {
      final userId = _authController?.currentUser?.uid;
      if (userId == null) return;

      // 텍스트 댓글을 pending 상태로 저장
      final autoPosition = _generateAutoProfilePosition(photoId);
      final currentUserProfileImageUrl = await _authController!
          .getUserProfileImageUrlWithCache(userId);

      _pendingVoiceComments[photoId] = CommentRecordModel(
        id: 'pending_text',
        text: text,
        type: CommentType.text,

        // 텍스트 댓글은 오디오 없음
        audioUrl: '',

        // 텍스트 댓글은 파형 데이터 없음
        waveformData: [],

        // 텍스트 댓글은 duration 없음
        duration: 0,
        recorderUser: userId,
        photoId: photoId,
        profileImageUrl: currentUserProfileImageUrl,
        createdAt: DateTime.now(),
        relativePosition: autoPosition,
      );

      // pending 상태 업데이트
      if (mounted) {
        setState(() {
          _pendingTextComments[photoId] = true;
          _voiceCommentSavedStates[photoId] = false;
        });
      }
    } catch (e) {
      debugPrint('텍스트 댓글 임시 저장 실패: $e');
    }
  }

  Future<void> _onVoiceCommentRecordingFinished(
    String photoId,
    String audioPath,
    List<double> waveformData,
    int duration,
  ) async {
    // Feed와 동일하게: 녹음 완료 시 즉시 저장하지 않고, 사용자가 파형을 눌러 저장하도록 대기.
    try {
      final userId = _authController?.currentUser?.uid;
      if (userId == null) return;

      // 현재 로그인한 사용자의 프로필 이미지 URL 가져오기
      final currentUserProfileImageUrl = await _authController!
          .getUserProfileImageUrlWithCache(userId);

      final autoPosition = _generateAutoProfilePosition(photoId);

      _pendingVoiceComments[photoId] = CommentRecordModel(
        id: 'pending',
        audioUrl: audioPath,
        recorderUser: userId,
        photoId: photoId,
        waveformData: waveformData,
        duration: duration,

        // 현재 사용자 프로필 이미지 사용
        profileImageUrl: currentUserProfileImageUrl,
        createdAt: DateTime.now(),
        relativePosition: autoPosition,
      );

      if (mounted) {
        setState(() {
          _voiceCommentSavedStates[photoId] = false;
          _voiceCommentActiveStates[photoId] = true; // 위젯 유지
        });
      }
    } catch (e) {
      debugPrint('음성 댓글 임시 저장 준비 실패: $e');
    }
  }

  Future<void> _onSaveRequested(String photoId) async {
    final pending = _pendingVoiceComments[photoId];
    if (pending == null) {
      throw StateError('임시 댓글이 없습니다. photoId: $photoId');
    }

    final userId = _authController?.currentUser?.uid;
    if (userId == null) {
      throw StateError('로그인된 사용자를 찾을 수 없습니다.');
    }

    // 즉시 UI에 반영할 임시 댓글 생성
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final relativePosition =
        pending.relativePosition ?? _generateAutoProfilePosition(photoId);

    final tempComment = CommentRecordModel(
      id: tempId,
      audioUrl: pending.audioUrl,
      photoId: photoId,
      recorderUser: userId,
      waveformData: pending.waveformData,
      duration: pending.duration,
      profileImageUrl: pending.profileImageUrl,
      createdAt: DateTime.now(),
      relativePosition: relativePosition,
      text: pending.text,
      type: pending.type,
    );

    // 임시 댓글을 현재 댓글 목록에 추가하여 UI에 즉시 반영
    final existingComments = List<CommentRecordModel>.from(
      _photoComments[photoId] ?? [],
    );
    existingComments.add(tempComment);

    setState(() {
      _photoComments[photoId] = existingComments;
      _commentPositions[tempId] = relativePosition;
      _voiceCommentSavedStates[photoId] = true;
      _savedCommentIds[photoId] = [
        ...(_savedCommentIds[photoId] ?? []),
        tempId,
      ];
      _pendingVoiceComments.remove(photoId);
      _pendingTextComments.remove(photoId);
      _voiceCommentActiveStates[photoId] = false;
    });

    // 백그라운드에서 Firestore 저장
    _saveCommentInBackground(
      photoId: photoId,
      tempId: tempId,
      pending: pending,
      userId: userId,
      relativePosition: relativePosition,
    );
  }

  // 백그라운드에서 댓글을 Firestore에 저장하고, 성공 시 임시 ID를 실제 ID로 교체
  Future<void> _saveCommentInBackground({
    required String photoId,
    required String tempId,
    required CommentRecordModel pending,
    required String userId,
    required Offset relativePosition,
  }) async {
    try {
      final currentUserProfileImageUrl = await _authController!
          .getUserProfileImageUrlWithCache(userId);

      final controller = CommentRecordController();

      // Firestore에 저장
      final savedComment = pending.type == CommentType.text
          ? await controller.createTextComment(
              text: pending.text ?? '',
              photoId: photoId,
              recorderUser: userId,
              profileImageUrl: currentUserProfileImageUrl,
              relativePosition: relativePosition,
            )
          : await controller.createCommentRecord(
              audioFilePath: pending.audioUrl,
              photoId: photoId,
              recorderUser: userId,
              waveformData: pending.waveformData,
              duration: pending.duration,
              profileImageUrl: currentUserProfileImageUrl,
              relativePosition: relativePosition,
            );

      if (savedComment == null) {
        // 저장 실패 시 롤백
        _rollbackOptimisticComment(photoId, tempId);
        if (mounted) {
          controller.showErrorToUser(context);
        }
        return;
      }

      // 저장 성공: 임시 ID를 실제 ID로 교체
      if (mounted) {
        setState(() {
          // 임시 댓글을 실제 댓글로 교체
          final comments = _photoComments[photoId] ?? [];
          final index = comments.indexWhere((c) => c.id == tempId);
          if (index != -1) {
            comments[index] = savedComment;
            _photoComments[photoId] = comments;
          }

          // 위치 정보 업데이트
          _commentPositions.remove(tempId);
          _commentPositions[savedComment.id] =
              savedComment.relativePosition ?? relativePosition;

          // savedCommentIds 업데이트
          final ids = _savedCommentIds[photoId] ?? [];
          final idIndex = ids.indexOf(tempId);
          if (idIndex != -1) {
            ids[idIndex] = savedComment.id;
            _savedCommentIds[photoId] = ids;
          }
        });
      }

      // 실시간 스트림과 동기화를 위해 댓글 다시 로드
      unawaited(_loadCommentsForPhoto(photoId));
    } catch (e) {
      debugPrint('댓글 백그라운드 저장 실패: $e');
      _rollbackOptimisticComment(photoId, tempId);
    }
  }

  /// Optimistic UI 롤백: 저장 실패 시 임시 댓글 제거
  void _rollbackOptimisticComment(String photoId, String tempId) {
    if (!mounted) return;

    setState(() {
      // 임시 댓글 제거
      final comments = _photoComments[photoId] ?? [];
      comments.removeWhere((c) => c.id == tempId);
      _photoComments[photoId] = comments;

      // 위치 정보 제거
      _commentPositions.remove(tempId);

      // savedCommentIds에서 제거
      final ids = _savedCommentIds[photoId] ?? [];
      ids.remove(tempId);
      if (ids.isEmpty) {
        _savedCommentIds.remove(photoId);
        _voiceCommentSavedStates[photoId] = false;
      } else {
        _savedCommentIds[photoId] = ids;
      }
    });

    // 사용자에게 에러 알림
    _showSnackBar('댓글 저장에 실패했습니다. 다시 시도해주세요.', backgroundColor: Colors.red);
  }

  void _onSaveCompleted(String photoId) {
    // 저장 후 액티브 종료 및 pending 정리
    setState(() {
      _voiceCommentActiveStates[photoId] = false;
      _pendingVoiceComments.remove(photoId);

      // 텍스트 댓글 pending 상태 제거
      _pendingTextComments.remove(photoId);
    });
  }

  Offset? _extractRelativeOffset(dynamic relativePosition) {
    if (relativePosition == null) {
      return null;
    }
    if (relativePosition is Offset) {
      return relativePosition;
    }
    if (relativePosition is Map<String, dynamic>) {
      return PositionConverter.mapToRelativePosition(relativePosition);
    }
    return null;
  }

  Offset _generateAutoProfilePosition(String photoId) {
    final occupiedPositions = <Offset>[];

    final comments = _photoComments[photoId] ?? const <CommentRecordModel>[];
    for (final comment in comments) {
      final position = _extractRelativeOffset(comment.relativePosition);
      if (position != null) {
        occupiedPositions.add(position);
      }
    }

    final savedCommentIds = _savedCommentIds[photoId] ?? const <String>[];
    for (final commentId in savedCommentIds) {
      final cachedPosition = _commentPositions[commentId];
      if (cachedPosition != null) {
        occupiedPositions.add(cachedPosition);
      }
    }

    final pending = _pendingVoiceComments[photoId];
    final pendingPosition = pending?.relativePosition;
    if (pendingPosition != null) {
      occupiedPositions.add(pendingPosition);
    }

    const maxAttempts = 30;
    final patternLength = _autoPlacementPattern.length;
    final startingIndex = _autoPlacementIndices[photoId] ?? 0;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final rawIndex = startingIndex + attempt;
      final baseOffset = _autoPlacementPattern[rawIndex % patternLength];
      final loop = rawIndex ~/ patternLength;
      final candidate = _applyJitter(baseOffset, loop, attempt);

      if (!_isPositionTooClose(candidate, occupiedPositions)) {
        _autoPlacementIndices[photoId] = rawIndex + 1;
        return candidate;
      }
    }

    _autoPlacementIndices[photoId] = startingIndex + 1;
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

  Future<void> _deletePhoto(MediaDataModel photo) async {
    try {
      final auth = _getAuthController;
      final currentUserId = auth.getUserId;
      if (currentUserId == null) {
        _showSnackBar('사용자 인증이 필요합니다.');
        return;
      }
      final success = await PhotoController().deletePhoto(
        categoryId: widget.categoryId,
        photoId: photo.id,
        userId: currentUserId,

        // 소프트 삭제로 변경
        permanentDelete: false,
      );
      if (!mounted) return;
      if (success) {
        _showSnackBar('사진이 삭제되었습니다.');
        _handleSuccessfulDeletion(photo);
      } else {
        _showSnackBar('삭제 중 오류가 발생했습니다.');
      }
    } catch (e) {
      _showSnackBar('삭제 중 오류가 발생했습니다: $e');
    }
  }

  void _handleSuccessfulDeletion(MediaDataModel photo) {
    if (widget.photos.length <= 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      widget.photos.removeWhere((p) => p.id == photo.id);
      if (_currentIndex >= widget.photos.length) {
        _currentIndex = widget.photos.length - 1;
      }
    });
    _loadUserProfileImage();
    _subscribeToVoiceCommentsForCurrentPhoto();
  }

  Future<void> _stopAudio() async {
    await _getAudioController.stopRealtimeAudio();
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

  // Getters
  AuthController get _getAuthController =>
      Provider.of<AuthController>(context, listen: false);
  AudioController get _getAudioController =>
      Provider.of<AudioController>(context, listen: false);
}
