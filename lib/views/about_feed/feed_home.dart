import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../api_firebase/controllers/auth_controller.dart';
import '../../api_firebase/controllers/media_controller.dart';
import '../../api_firebase/controllers/audio_controller.dart';
import '../../api_firebase/controllers/comment_audio_controller.dart';
import '../../api_firebase/models/photo_data_model.dart';
import '../common_widget/abput_photo/photo_card_widget_common.dart';
import 'manager/feed_data_manager.dart';
import 'manager/voice_comment_state_manager.dart';
import 'manager/profile_cache_manager.dart';
import 'manager/feed_audio_manager.dart';

class FeedHomeScreen extends StatefulWidget {
  const FeedHomeScreen({super.key});

  @override
  State<FeedHomeScreen> createState() => _FeedHomeScreenState();
}

class _FeedHomeScreenState extends State<FeedHomeScreen> {
  // 매니저 인스턴스들 - nullable로 변경하여 초기화 에러 방지
  FeedDataManager? _feedDataManager;
  VoiceCommentStateManager? _voiceCommentStateManager;
  ProfileCacheManager? _profileCacheManager;
  FeedAudioManager? _feedAudioManager;

  // 컨트롤러 참조
  AuthController? _authController;
  CommentAudioController? _commentAudioController;

  @override
  void initState() {
    super.initState();

    // 매니저 초기화
    _feedDataManager = FeedDataManager();
    _voiceCommentStateManager = VoiceCommentStateManager();
    _profileCacheManager = ProfileCacheManager();
    _feedAudioManager = FeedAudioManager();

    // 상태 변경 콜백 설정
    _feedDataManager?.setOnStateChanged(() {
      if (mounted) setState(() {});
    });
    _voiceCommentStateManager?.setOnStateChanged(() {
      if (mounted) setState(() {});
    });
    _profileCacheManager?.setOnStateChanged(() {
      if (mounted) setState(() {});
    });

    // 사진 로드 완료 시 프로필/댓글 구독 콜백 설정
    _feedDataManager?.setOnPhotosLoaded((newPhotos) {
      final currentUserId = _authController?.getUserId ?? '';
      for (Map<String, dynamic> photoData in newPhotos) {
        final MediaDataModel photo = photoData['photo'] as MediaDataModel;
        _profileCacheManager?.loadUserProfileForPhoto(photo.userID, context);
        _voiceCommentStateManager?.subscribeToVoiceCommentsForPhoto(
          photo.id,
          currentUserId,
        );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authController = Provider.of<AuthController>(context, listen: false);
      _authController!.addListener(_onAuthControllerChanged);

      // CommentAudioController 초기화
      _commentAudioController = Provider.of<CommentAudioController>(
        context,
        listen: false,
      );

      // 초기 데이터 로드
      _loadInitialData();
    });
  }

  /// 초기 데이터 로드 및 프로필/댓글 구독
  Future<void> _loadInitialData() async {
    final currentUserId = _authController?.getUserId ?? '';
    if (currentUserId.isNotEmpty) {
      await _loadCurrentUserProfile(_authController!, currentUserId);
    }

    await _feedDataManager?.loadUserCategoriesAndPhotos(context);
  }

  /// 현재 사용자 프로필 로드
  Future<void> _loadCurrentUserProfile(
    AuthController authController,
    String currentUserId,
  ) async {
    if (_profileCacheManager?.userProfileImages.containsKey(currentUserId) !=
        true) {
      try {
        final currentUserProfileImage = await authController
            .getUserProfileImageUrlWithCache(currentUserId);
        _profileCacheManager?.userProfileImages[currentUserId] =
            currentUserProfileImage;
        _profileCacheManager?.setOnStateChanged(() {
          if (mounted) setState(() {});
        });
      } catch (e) {
        debugPrint('[ERROR] 현재 사용자 프로필 이미지 로드 실패: $e');
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authController ??= Provider.of<AuthController>(context, listen: false);
    _commentAudioController ??= Provider.of<CommentAudioController>(
      context,
      listen: false,
    );
  }

  @override
  void dispose() {
    _authController?.removeListener(_onAuthControllerChanged);

    // CommentAudioController 정리
    _commentAudioController?.stopAllComments();

    // 매니저들 정리
    _feedDataManager?.dispose();
    _voiceCommentStateManager?.dispose();
    _profileCacheManager?.dispose();

    PaintingBinding.instance.imageCache.clear();

    super.dispose();
  }

  /// AuthController 변경 감지 시 프로필 이미지 캐시 업데이트
  void _onAuthControllerChanged() async {
    final currentUser = _authController?.currentUser;
    if (_authController != null && currentUser != null && mounted) {
      // ProfileCacheManager를 통해 현재 사용자 프로필 로드
      await _profileCacheManager?.loadCurrentUserProfile(
        _authController!,
        currentUser.uid,
      );
    }
  }

  /// 특정 사용자의 프로필 이미지 캐시 강제 리프레시
  Future<void> refreshUserProfileImage(String userId) async {
    final authController = Provider.of<AuthController>(context, listen: false);
    try {
      if (_profileCacheManager?.loadingStates != null) {
        _profileCacheManager!.loadingStates[userId] = true;
      }
      _profileCacheManager?.setOnStateChanged(() {
        if (mounted) setState(() {});
      });
      final profileImageUrl = await authController
          .getUserProfileImageUrlWithCache(userId);
      if (_profileCacheManager?.userProfileImages != null) {
        _profileCacheManager!.userProfileImages[userId] = profileImageUrl;
      }
      if (_profileCacheManager?.loadingStates != null) {
        _profileCacheManager!.loadingStates[userId] = false;
      }
      _profileCacheManager?.setOnStateChanged(() {
        if (mounted) setState(() {});
      });
    } catch (e) {
      if (_profileCacheManager?.loadingStates != null) {
        _profileCacheManager!.loadingStates[userId] = false;
      }
      _profileCacheManager?.setOnStateChanged(() {
        if (mounted) setState(() {});
      });
    }
  }

  /// 더 많은 사진 로드 (무한 스크롤링) - delegate
  Future<void> _loadMorePhotos() async {
    await _feedDataManager?.loadMorePhotos(context);

    // 새로 로드된 사진들의 프로필 정보 및 음성 댓글 구독
    final allPhotos = _feedDataManager?.allPhotos;
    for (Map<String, dynamic> photoData in allPhotos!) {
      final MediaDataModel photo = photoData['photo'] as MediaDataModel;
      _loadUserProfileForPhoto(photo.userID);
      _voiceCommentStateManager?.subscribeToVoiceCommentsForPhoto(
        photo.id,
        _authController?.getUserId ?? '',
      );
    }
  }

  /// 특정 사용자의 프로필 정보를 로드하는 메서드
  Future<void> _loadUserProfileForPhoto(String userId) async {
    // ProfileCacheManager를 통해 로드
    await _profileCacheManager?.loadUserProfileForPhoto(userId, context);
  }

  /// 오디오 재생/일시정지 토글
  Future<void> _toggleAudio(MediaDataModel photo) async {
    await _feedAudioManager?.toggleAudio(photo, context);
  }

  /// 음성 댓글 토글 - delegate to manager
  void _toggleVoiceComment(String photoId) {
    debugPrint('🟠 [FeedHome] 음성 댓글 토글 시작: photoId=$photoId');
    _voiceCommentStateManager?.toggleVoiceComment(photoId);
    // 명시적으로 setState 호출하여 UI 업데이트 보장
    if (mounted) {
      setState(() {
        debugPrint('🟠 [FeedHome] setState 호출 완료');
      });
    }
  }

  /// 음성 댓글 녹음 완료 콜백 (임시 저장) - delegate to manager
  Future<void> _onVoiceCommentCompleted(
    String photoId,
    String? audioPath,
    List<double>? waveformData,
    int? duration,
  ) async {
    final currentUserId = _authController?.getUserId;
    final profileImageUrl = (currentUserId != null && currentUserId.isNotEmpty)
        ? _profileCacheManager?.userProfileImages[currentUserId]
        : null;

    await _voiceCommentStateManager?.onVoiceCommentCompleted(
      photoId,
      audioPath,
      waveformData,
      duration,
      recorderUserId: currentUserId,
      profileImageUrl: profileImageUrl,
    );
  }

  /// 텍스트 댓글 완료 콜백 (임시 저장) - delegate to manager
  Future<void> _onTextCommentCompleted(String photoId, String text) async {
    debugPrint('🟢 [FeedHome] 텍스트 댓글 완료: photoId=$photoId, text=$text');
    final currentUserId = _authController?.getUserId;
    final profileImageUrl = (currentUserId != null && currentUserId.isNotEmpty)
        ? _profileCacheManager?.userProfileImages[currentUserId]
        : null;

    await _voiceCommentStateManager?.onTextCommentCompleted(
      photoId,
      text,
      recorderUserId: currentUserId,
      profileImageUrl: profileImageUrl,
    );
    debugPrint('🟢 [FeedHome] StateManager.onTextCommentCompleted 완료');
  }

  /// 실제 음성 댓글 저장 (파형 클릭 시 호출) - delegate to manager
  Future<void> _saveVoiceComment(String photoId) async {
    await _voiceCommentStateManager?.saveVoiceComment(photoId, context);
  }

  /// 음성 댓글 삭제 콜백 - delegate to manager
  void _onVoiceCommentDeleted(String photoId) {
    _voiceCommentStateManager?.onVoiceCommentDeleted(photoId);
  }

  /// 음성 댓글 저장 완료 후 위젯 초기화 (추가 댓글을 위한) - delegate to manager
  void _onSaveCompleted(String photoId) {
    _voiceCommentStateManager?.onSaveCompleted(photoId);
  }

  /// 프로필 이미지 드래그 처리 - delegate to manager
  void _onProfileImageDragged(String photoId, Offset absolutePosition) {
    _voiceCommentStateManager?.onProfileImageDragged(photoId, absolutePosition);
  }

  void _stopAllAudio() {
    // 1. 게시물 오디오 중지
    final audioController = Provider.of<AudioController>(
      context,
      listen: false,
    );
    audioController.stopAudio();

    // 2. 음성 댓글 오디오 중지
    final commentAudioController = Provider.of<CommentAudioController>(
      context,
      listen: false,
    );
    commentAudioController.stopAllComments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, body: _buildBody());
  }

  Widget _buildBody() {
    if (_feedDataManager!.isLoading) {
      return Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_feedDataManager!.allPhotos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_camera_outlined, color: Colors.white54, size: 80),
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
            Text(
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
      child: Stack(
        children: [
          PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: _feedDataManager!.allPhotos.length, // 로딩 인디케이터 공간 제거
            onPageChanged: (index) {
              // 스마트 미리 로딩: 5개 남았을 때 백그라운드에서 다음 10개 로드
              final totalPhotos = _feedDataManager!.allPhotos.length;

              // 조건: 5개 이하 남았고, 더 로드할 데이터가 있고, 현재 로딩 중이 아닐 때
              if (index >= totalPhotos - 5 &&
                  _feedDataManager!.hasMoreData &&
                  !_feedDataManager!.isLoadingMore) {
                // 백그라운드에서 조용히 로드 (사용자가 눈치채지 못하게)
                _loadMorePhotos();
                debugPrint('🔄 백그라운드 미리 로딩 시작 - 인덱스: $index, 전체: $totalPhotos');
              }

              // 페이지 변경 시 모든 오디오 중지
              _stopAllAudio();
            },
            itemBuilder: (context, index) {
              // 안전한 범위 검사 (이제 로딩 인디케이터 없음)
              if (index >= _feedDataManager!.allPhotos.length) {
                return const SizedBox.shrink(); // 빈 위젯 반환
              }

              final photoData = _feedDataManager!.allPhotos[index];
              final MediaDataModel photo = photoData['photo'] as MediaDataModel;
              final String categoryName = photoData['categoryName'] as String;
              final String categoryId = photoData['categoryId'] as String;
              final currentUserId = _authController?.getUserId;
              final isOwner =
                  currentUserId != null && currentUserId == photo.userID;

              return PhotoCardWidgetCommon(
                photo: photo,
                categoryName: categoryName,
                categoryId: categoryId,
                index: index,
                isOwner: isOwner,
                photoComments: _voiceCommentStateManager!.photoComments,
                userProfileImages: _profileCacheManager!.userProfileImages,
                profileLoadingStates: _profileCacheManager!.loadingStates,
                userNames: _profileCacheManager!.userNames,
                voiceCommentActiveStates:
                    _voiceCommentStateManager!.voiceCommentActiveStates,
                voiceCommentSavedStates:
                    _voiceCommentStateManager!.voiceCommentSavedStates,
                pendingTextComments: _voiceCommentStateManager!
                    .pendingTextComments, // Pending 텍스트 댓글 상태 전달
                pendingVoiceComments:
                    _voiceCommentStateManager!.pendingVoiceComments,
                onToggleAudio: _toggleAudio,
                onToggleVoiceComment: _toggleVoiceComment,
                onVoiceCommentCompleted: _onVoiceCommentCompleted,
                onTextCommentCompleted: _onTextCommentCompleted, // 텍스트 댓글 콜백 추가
                onVoiceCommentDeleted: _onVoiceCommentDeleted,
                onProfileImageDragged: _onProfileImageDragged,
                onSaveRequested: _saveVoiceComment,
                onSaveCompleted: _onSaveCompleted,
                onDeletePressed: () async {
                  try {
                    final photoController = Provider.of<PhotoController>(
                      context,
                      listen: false,
                    );
                    final authController = Provider.of<AuthController>(
                      context,
                      listen: false,
                    );
                    final userId = authController.getUserId;
                    if (userId == null) return;

                    final success = await photoController.deletePhoto(
                      categoryId: categoryId,
                      photoId: photo.id,
                      userId: userId,
                    );
                    if (success && mounted) {
                      // 로컬 상태에서 즉시 제거
                      setState(() {
                        _feedDataManager!.removePhoto(index);
                      });

                      // 백그라운드에서 전체 피드 새로고침으로 데이터 동기화 보장
                      _feedDataManager!.loadUserCategoriesAndPhotos(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('사진이 삭제되었습니다.'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    } else if (!success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('사진 삭제에 실패했습니다.'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    throw Exception('사진 삭제 중 오류 발생: $e');
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
