import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../api/controller/audio_controller.dart';
import '../../api/controller/category_controller.dart' as api_category;
import '../../api/controller/media_controller.dart' as api_media;
import '../../api/controller/post_controller.dart';
import '../../api/controller/user_controller.dart';
import '../../api/services/media_service.dart';
import '../../api_firebase/models/selected_friend_model.dart';
import '../home_navigator_screen.dart';
import 'widgets/add_category_widget.dart';
import 'widgets/audio_recorder_widget.dart';
import 'widgets/caption_input_widget.dart';
import 'widgets/category_list_widget.dart';
import 'widgets/loading_popup_widget.dart';
import 'widgets/photo_display_widget.dart';

class PhotoEditorScreen extends StatefulWidget {
  final String? downloadUrl;
  final String? filePath;

  // 미디어가 비디오인지 여부를 체크하는 플래그
  final bool? isVideo;
  final ImageProvider? initialImage;

  // 카메라에서 직접 촬영된 미디어인지 여부 (true: 촬영됨, false: 갤러리에서 선택됨)
  final bool isFromCamera;

  const PhotoEditorScreen({
    super.key,
    this.downloadUrl,
    this.filePath,
    this.isVideo,
    this.initialImage,
    this.isFromCamera = true, // 기본값은 촬영된 것으로 설정
  });
  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

/// 업로드에 필요한 데이터를 담는 클래스
///
/// 서버에 게시물을 업로드하기 위해 필요한 모든 정보를 하나로 모아둔 클래스입니다.
/// 사용자 정보, 미디어 파일, 캡션, 음성 데이터 등을 포함합니다.
class _UploadPayload {
  final int userId; // 사용자 ID
  final String nickName; // 사용자 닉네임
  final File mediaFile; // 업로드할 미디어 파일 (사진 또는 비디오)
  final String mediaPath; // 미디어 파일 경로
  final bool isVideo; // 비디오 여부 (false면 사진)
  final File? audioFile; // 음성 파일 (선택사항, 사진에만 첨부 가능)
  final String? audioPath; // 음성 파일 경로
  final String? caption; // 캡션 텍스트
  final List<double>? waveformData; // 음성 파형 데이터
  final int? audioDurationSeconds; // 음성 재생 시간 (초)

  const _UploadPayload({
    required this.userId,
    required this.nickName,
    required this.mediaFile,
    required this.mediaPath,
    required this.isVideo,
    this.audioFile,
    this.audioPath,
    this.caption,
    this.waveformData,
    this.audioDurationSeconds,
  });
}

/// 미디어 업로드 결과를 담는 클래스
///
/// 서버에 파일을 업로드한 후 받은 키(key) 값들을 저장합니다.
/// 이 키들은 나중에 게시물을 업데이트할 때 사용됩니다.
class _MediaUploadResult {
  final String mediaKey; // 사진/비디오 파일의 서버 키
  final String? audioKey; // 음성 파일의 서버 키 (있는 경우)

  const _MediaUploadResult({required this.mediaKey, this.audioKey});
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _showImmediatePreview = false;
  String? _errorMessage;
  bool _useLocalImage = false;
  ImageProvider? _initialImageProvider;
  bool _showAddCategoryUI = false;
  final List<int> _selectedCategoryIds = [];
  bool _categoriesLoaded = false;
  bool _shouldAutoOpenCategorySheet = true;
  bool _isDisposing = false;

  // ========== 바텀시트 크기 상수 ==========
  static const double _kInitialSheetExtent = 0.0;
  static const double _kLockedSheetExtent = 0.19; // 잠금된 바텀시트 높이
  static const double _kExpandedSheetExtent = 0.31; // 확장된 바텀시트 높이
  static const double _kMaxSheetExtent = 0.8; // 최대 바텀시트 높이

  // ========== 이미지 압축 상수 ==========
  static const int _kMaxImageSizeBytes = 1024 * 1024; // 1MB
  static const int _kInitialCompressionQuality = 85; // 초기 압축 품질
  static const int _kMinCompressionQuality = 40; // 최소 압축 품질
  static const int _kQualityDecrement = 10; // 품질 감소 단위
  static const int _kInitialImageDimension = 2200; // 초기 이미지 크기
  static const int _kMinImageDimension = 960; // 최소 이미지 크기
  static const double _kDimensionScaleFactor = 0.85; // 크기 감소 비율
  static const int _kFallbackCompressionQuality = 35; // 최종 강제 압축 품질
  static const int _kFallbackImageDimension = 1024; // 최종 강제 압축 크기

  // 최소 크기는 처음에는 0에서 시작하여 애니메이션으로 잠금 위치까지 이동
  double _minChildSize = _kInitialSheetExtent;

  // 초기값은 0에서 시작
  double _initialChildSize = _kInitialSheetExtent;

  // 잠금 상태 플래그
  // 이 플래그로 바텀시트가 잠금 상태인지 여부를 추적
  bool _hasLockedSheetExtent = false;
  List<double>? _recordedWaveformData;
  String? _recordedAudioPath;
  bool _isCaptionEmpty = true;
  bool _showAudioRecorder = false;

  // ========== 성능 최적화: 압축 캐싱 ==========
  /// 백그라운드에서 실행 중인 이미지 압축 작업
  /// 사용자가 캡션을 입력하는 동안 미리 압축을 완료합니다
  Future<File>? _compressionTask;

  /// 압축이 완료된 파일 (재사용을 위해 캐싱)
  File? _compressedFile;

  /// 마지막으로 압축한 파일의 경로 (변경 감지용)
  String? _lastCompressedPath;

  double get keyboardHeight => MediaQuery.of(context).viewInsets.bottom;
  bool get isKeyboardVisible => keyboardHeight > 0;
  bool get shouldHideBottomSheet => isKeyboardVisible && !_showAddCategoryUI;

  final _draggableScrollController = DraggableScrollableController();
  final _categoryNameController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  late AudioController _audioController;
  late api_category.CategoryController _categoryController;
  late UserController _userController;
  late PostController _postController;
  late api_media.MediaController _mediaController;

  final FocusNode _captionFocusNode = FocusNode();
  final FocusNode _categoryFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _primeImmediatePreview();
    _initializeScreen();
    _captionController.addListener(_handleCaptionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _captionFocusNode.unfocus();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeControllers();
    _loadCategoriesIfNeeded();
    _startPreCompressionIfNeeded(); // 성능 최적화: 미리 압축 시작
  }

  @override
  void didUpdateWidget(PhotoEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _handleWidgetUpdate(oldWidget);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _handleAppStateChange(state);
  }

  // ========== 초기화 메서드들 ==========
  void _initializeScreen() {
    if (!_showImmediatePreview) _loadImage();
  }

  void _primeImmediatePreview() {
    if (widget.initialImage != null) {
      _initialImageProvider = widget.initialImage;
      _showImmediatePreview = true;
      _useLocalImage = true;
      _isLoading = false;
      return;
    }

    final localPath = widget.filePath;
    if (localPath == null || localPath.isEmpty) return;

    final file = File(localPath);
    if (!file.existsSync()) return;

    _useLocalImage = true;
    _showImmediatePreview = true;
    _isLoading = false;
  }

  void _initializeControllers() {
    _audioController = Provider.of<AudioController>(context, listen: false);
    _categoryController = Provider.of<api_category.CategoryController>(
      context,
      listen: false,
    );
    _userController = Provider.of<UserController>(context, listen: false);
    _postController = Provider.of<PostController>(context, listen: false);
    _mediaController = Provider.of<api_media.MediaController>(
      context,
      listen: false,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _audioController.initialize();
    });
  }

  void _handleCaptionChanged() {
    final isEmpty = _captionController.text.trim().isEmpty;
    if (isEmpty == _isCaptionEmpty) return;

    if (!mounted) {
      _isCaptionEmpty = isEmpty;
      return;
    }
    setState(() => _isCaptionEmpty = isEmpty);
  }

  void _loadCategoriesIfNeeded() {
    if (!_categoriesLoaded) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadUserCategories(),
      );
    }
  }

  void _handleWidgetUpdate(PhotoEditorScreen oldWidget) {
    if (oldWidget.filePath != widget.filePath ||
        oldWidget.downloadUrl != widget.downloadUrl ||
        oldWidget.initialImage != widget.initialImage) {
      _categoriesLoaded = false;
      if (widget.initialImage != null) {
        _initialImageProvider = widget.initialImage;
        _showImmediatePreview = true;
        _useLocalImage = true;
        _isLoading = false;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadUserCategories(forceReload: true);
      });
    }
  }

  void _handleAppStateChange(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _categoriesLoaded = false;
      _loadUserCategories(forceReload: true);
    }
  }

  // ========== 이미지 및 카테고리 로딩 메서드들 ==========
  Future<void> _loadImage() async {
    _errorMessage = null;

    // _primeImmediatePreview에서 이미 처리된 경우
    if (_showImmediatePreview) {
      _isLoading = false;
      if (mounted) setState(() {});
      return;
    }

    final localPath = widget.filePath;
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      try {
        final exists = await file.exists();
        if (!mounted) return;

        if (exists) {
          setState(() {
            _useLocalImage = true;
            _showImmediatePreview = true;
            _isLoading = false;
          });
          return;
        }

        setState(() {
          _errorMessage = '이미지 파일을 찾을 수 없습니다.';
          _isLoading = false;
        });
        return;
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _errorMessage = "이미지 로딩 중 오류 발생: $e";
          _isLoading = false;
        });
        return;
      }
    }

    // downloadUrl이 있거나 둘 다 없는 경우
    _isLoading = false;
    if (mounted) setState(() {});
  }

  Future<void> _loadUserCategories({bool forceReload = false}) async {
    if (!forceReload && _categoriesLoaded) return;

    final currentUser = _userController.currentUser;
    if (currentUser == null) {
      if (mounted) {
        setState(() {
          _errorMessage = "로그인이 필요합니다.";
          _isLoading = false;
        });
      }
      return;
    }

    // 바텀시트를 먼저 올림 (로딩 시작 전)
    // 바텀 시트를 먼저 올리고 아래에서 로딩을 시작한다.
    if (_shouldAutoOpenCategorySheet) {
      _shouldAutoOpenCategorySheet = false;
      _animateSheetTo(_kLockedSheetExtent, lockExtent: true);
    }

    try {
      // 카테고리를 로드하는 동안, shimmer를 표시해서 사용자에게 로딩 중임을 알린다.
      await _categoryController.loadCategories(
        currentUser.id,
        forceReload: forceReload,
      );
      _categoriesLoaded = true;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "카테고리 로드 중 오류 발생: $e";
        });
      }
    }
  }

  void _handleCategorySelection(int categoryId) {
    final wasEmpty = _selectedCategoryIds.isEmpty;

    // 현재 바텀시트 위치 확인
    final currentExtent = _draggableScrollController.isAttached
        ? _draggableScrollController.size
        : _kLockedSheetExtent;

    setState(() {
      if (_selectedCategoryIds.contains(categoryId)) {
        _selectedCategoryIds.remove(categoryId);
      } else {
        _selectedCategoryIds.add(categoryId);
      }
    });

    // 카테고리 선택 상태에 따라 바텀시트 높이 조정
    if (_selectedCategoryIds.isEmpty) {
      _animateSheetTo(_kLockedSheetExtent);
    } else if (wasEmpty) {
      // 바텀시트가 이미 확장된 상태(0.19보다 크게 열린 상태)라면 위치 유지
      if (currentExtent > _kLockedSheetExtent + 0.05) {
        // 바텀시트를 움직이지 않음 (사용자가 올린 위치 유지)
        return;
      }
      _animateSheetTo(_kExpandedSheetExtent);
    }
  }

  void _animateSheetTo(
    double size, {
    bool lockExtent = false,
    int retryCount = 0,
  }) {
    if (!mounted || _isDisposing) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _isDisposing) return;

      // Controller가 attach될 때까지 재시도 (최대 50번)
      if (!_draggableScrollController.isAttached) {
        if (retryCount < 50) {
          _animateSheetTo(
            size,
            lockExtent: lockExtent,
            retryCount: retryCount + 1,
          );
        } else {
          debugPrint('DraggableScrollableController attach 실패 (최대 재시도 횟수 초과)');
        }
        return;
      }

      await _draggableScrollController.animateTo(
        size,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );

      // 애니메이션 완료 후 lockExtent 처리
      if (lockExtent && !_hasLockedSheetExtent && mounted) {
        setState(() {
          _minChildSize = size;
          _initialChildSize = size;
          _hasLockedSheetExtent = true;
        });
      }
    });
  }

  Future<void> _resetBottomSheetIfNeeded() async {
    if (_isDisposing || !_draggableScrollController.isAttached) return;

    final targetSize = _hasLockedSheetExtent
        ? _kLockedSheetExtent
        : _initialChildSize;
    final currentSize = _draggableScrollController.size;

    if ((currentSize - targetSize).abs() > 0.001) {
      await _draggableScrollController.animateTo(
        targetSize,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handleMicTap() {
    setState(() => _showAudioRecorder = true);
    _captionFocusNode.unfocus();
  }

  /// 캡션 입력 바 위젯을 반환하는 함수입니다.
  Widget _buildCaptionInputBar() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: _showAudioRecorder
          ? Padding(
              key: const ValueKey('audio_recorder'),
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: AudioRecorderWidget(
                autoStart: true,

                onRecordingFinished: (audioFilePath, waveformData, duration) {
                  setState(() {
                    _recordedAudioPath = audioFilePath;
                    _recordedWaveformData = waveformData;
                  });
                },
                onRecordingCleared: () {
                  setState(() {
                    _showAudioRecorder = false;
                    _recordedAudioPath = null;
                    _recordedWaveformData = null;
                  });
                },
                initialRecordingPath: _recordedAudioPath,
                initialWaveformData: _recordedWaveformData,
              ),
            )
          : FocusScope(
              key: const ValueKey('caption_input'),
              child: Focus(
                onFocusChange: (isFocused) {
                  if (_categoryFocusNode.hasFocus) {
                    FocusScope.of(context).requestFocus(_categoryFocusNode);
                  }
                },
                child: CaptionInputWidget(
                  controller: _captionController,
                  isCaptionEmpty: _isCaptionEmpty,
                  onMicTap: _handleMicTap,
                  isKeyboardVisible: !_categoryFocusNode.hasFocus,
                  keyboardHeight: keyboardHeight,
                  focusNode: _captionFocusNode,
                ),
              ),
            ),
    );
  }

  /// 새 카테고리를 생성하는 메소드입니다.
  Future<void> _createNewCategory(
    List<SelectedFriendModel> selectedFriends,
  ) async {
    if (_categoryNameController.text.trim().isEmpty) {
      _showErrorSnackBar('카테고리 이름을 입력해주세요');
      return;
    }

    try {
      // 현재 사용자 정보 가져오기
      final user = _userController.currentUser;
      if (user == null) {
        _showErrorSnackBar('로그인이 필요합니다. 다시 로그인해주세요.');
        return;
      }

      // 카테고리에 초대된 사용자 ID 목록 생성
      final receiverIds = <int>[user.id];
      for (final friend in selectedFriends) {
        final parsedId = int.tryParse(friend.uid);
        if (parsedId != null && !receiverIds.contains(parsedId)) {
          receiverIds.add(parsedId);
        }
      }

      // 카테고리 생성 API 호출
      final categoryId = await _categoryController.createCategory(
        requesterId: user.id,
        name: _categoryNameController.text.trim(),
        receiverIds: receiverIds,
        isPublic: selectedFriends.isNotEmpty,
      );

      if (categoryId == null) {
        _showErrorSnackBar('카테고리 생성에 실패했습니다. 다시 시도해주세요.');
        return;
      }

      _categoriesLoaded = false;
      await _categoryController.loadCategories(user.id, forceReload: true);

      _safeSetState(() {
        _showAddCategoryUI = false;
        _categoryNameController.clear();
      });
    } catch (e) {
      _showErrorSnackBar('카테고리 생성 중 오류가 발생했습니다');
    }
  }

  // ========== 업로드 및 화면 전환 관련 메서드들 ==========

  /// 임시 파일을 삭제하는 메소드입니다.
  Future<void> _deleteTemporaryFile(File file, String path) async {
    if (!path.contains('/tmp/')) return;

    try {
      if (await file.exists()) {
        await file.delete();
        debugPrint('임시 파일 삭제: $path');
      }
    } catch (e) {
      debugPrint('임시 파일 삭제 실패: $e');
    }
  }

  /// 백그라운드에서 임시 파일들을 삭제합니다 (성능 최적화)
  ///
  /// 사용자는 파일 삭제를 기다릴 필요가 없으므로 백그라운드에서 실행합니다
  Future<void> _deleteTemporaryFilesInBackground(_UploadPayload payload) async {
    await _deleteTemporaryFile(payload.mediaFile, payload.mediaPath);
    if (payload.audioFile != null && payload.audioPath != null) {
      await _deleteTemporaryFile(payload.audioFile!, payload.audioPath!);
    }
  }

  // 비디오 출처 확인 헬퍼 메서드
  bool get isVideoFromCamera => widget.isVideo == true && widget.isFromCamera;
  bool get isVideoFromGallery => widget.isVideo == true && !widget.isFromCamera;

  /// 미디어를 업로드하고 홈 화면으로 이동하는 메서드입니다.
  Future<void> _uploadThenNavigate(List<int> categoryIds) async {
    if (!mounted) return;

    // 업로드할 데이터 준비
    final payload = await _prepareUploadPayload();
    if (payload == null) return;
    if (!mounted) return;

    try {
      // 성능 최적화: 병렬 처리 가능한 작업들을 동시 실행
      await Future.wait([
        _audioController.stopRealtimeAudio(),
        Future.microtask(() => _clearImageCache()),
      ]);
      _audioController.clearCurrentRecording();
      // 성능 최적화: 불필요한 500ms 대기 제거

      // 1. 먼저 post 생성 (모든 카테고리를 한 번에 전달)
      final postId = await _createDraftPost(
        categoryIds: categoryIds,
        payload: payload,
      );
      debugPrint("생성된 게시물 ID: $postId");
      if (postId == null) {
        throw Exception('게시물 생성에 실패했습니다.');
      }

      // 2-3. 미디어 업로드 (사진/비디오)
      final mediaResult = await _uploadMediaForPost(
        postId: postId,

        // payload 자체를 전달하여서 필요한 모든 정보를 사용할 수 있도록 함
        payload: payload,
      );
      debugPrint("미디어 업로드 결과: ${mediaResult == null ? '실패' : '성공'}");
      if (mediaResult == null) {
        throw Exception('미디어 업로드에 실패했습니다.');
      }

      // 4. 최종적으로 post 업데이트
      await _finalizePostUpload(
        postId: postId,
        payload: payload,
        mediaResult: mediaResult,
      );

      // 성능 최적화: 파일 삭제를 백그라운드에서 실행 (사용자가 기다릴 필요 없음)
      unawaited(_deleteTemporaryFilesInBackground(payload));

      _clearImageCache();
      if (!mounted) return;
      LoadingPopupWidget.hide(context);
      if (!mounted) return;
      _navigateToHome();
    } catch (e) {
      debugPrint('업로드 실패: $e');
      _clearImageCache();
      _handleUploadError(e);
    }
  }

  /// 업로드 에러 처리 및 사용자에게 알림
  void _handleUploadError(dynamic error) {
    final message = error.toString().contains('413')
        ? '파일 용량이 너무 커서 업로드에 실패했습니다. 촬영 이미지를 다시 선택하거나 압축 후 시도해주세요.'
        : '업로드 중 오류가 발생했습니다. 다시 시도해주세요.';

    _showErrorSnackBar(message);

    if (!mounted) return;
    LoadingPopupWidget.hide(context);
    if (!mounted) return;
    _navigateToHome();
  }

  /// 업로드할 데이터를 준비하는 메서드
  ///
  /// 다음 작업을 수행합니다:
  /// - 사용자 로그인 확인
  /// - 미디어 파일 존재 여부 확인
  /// - 이미지인 경우 압축 처리
  /// - 음성 파일 확인 및 준비
  /// - 캡션, 파형 데이터 등 부가 정보 준비
  Future<_UploadPayload?> _prepareUploadPayload() async {
    // 로그인 확인
    final currentUser = _userController.currentUser;
    if (currentUser == null) {
      _showErrorSnackBar('로그인 후 다시 시도해주세요.');
      return null;
    }

    // 파일 경로 확인
    final filePath = widget.filePath;
    if (filePath == null || filePath.isEmpty) {
      _safeSetState(() {
        _errorMessage = '업로드할 파일을 찾을 수 없습니다.';
      });
      return null;
    }

    // 파일 존재 확인
    var mediaFile = File(filePath);
    if (!await mediaFile.exists()) {
      _safeSetState(() {
        _errorMessage = '미디어 파일을 찾을 수 없습니다.';
      });
      return null;
    }

    // 비디오인지 여부 확인
    final isVideo = widget.isVideo ?? false;

    // 이미지인 경우 압축 처리 (성능 최적화: 캐시 사용)
    if (!isVideo) {
      try {
        // 이미 압축이 완료된 파일이 있으면 바로 사용
        if (_compressedFile != null && _lastCompressedPath == filePath) {
          mediaFile = _compressedFile!;
          debugPrint('✅ 캐시된 압축 파일 사용');
        }
        // 압축 작업이 진행 중이면 완료될 때까지 대기
        else if (_compressionTask != null && _lastCompressedPath == filePath) {
          debugPrint('⏳ 백그라운드 압축 완료 대기 중...');
          mediaFile = await _compressionTask!;
          debugPrint('✅ 백그라운드 압축 완료, 사용');
        }
        // 캐시나 진행 중인 작업이 없으면 즉시 압축 (폴백)
        else {
          debugPrint('⚠️ 캐시 없음, 즉시 압축 시작');
          mediaFile = await _compressImageIfNeeded(mediaFile);
        }
      } catch (e) {
        debugPrint('이미지 압축 실패: $e');
      }
    }

    // 음성 파일 확인
    File? audioFile;
    String? audioPath;

    // 음성 파일 경로 후보 결정
    final candidatePath =
        _recordedAudioPath ?? _audioController.currentRecordingPath;

    // 음성 파일 존재 여부 확인
    if (candidatePath != null && candidatePath.isNotEmpty) {
      final file = File(candidatePath);
      if (await file.exists()) {
        audioFile = file;
        audioPath = candidatePath;
      }
    }

    // 캡션 텍스트 준비
    final captionText = _captionController.text.trim();
    final caption = captionText.isNotEmpty ? captionText : null;

    // 음성 파형 데이터 준비
    final waveform = (!isVideo && _recordedWaveformData != null)
        ? List<double>.from(_recordedWaveformData!)
        : null;

    // 음성 재생 시간 준비
    final duration = (!isVideo && _audioController.recordingDuration > 0)
        ? _audioController.recordingDuration
        : null;

    // 모든 준비가 완료된 업로드 페이로드 반환
    return _UploadPayload(
      userId: currentUser.id,
      nickName: currentUser.userId,
      mediaFile: mediaFile,
      mediaPath: mediaFile.path,
      isVideo: isVideo,
      audioFile: audioFile,
      audioPath: audioPath,
      caption: caption,
      waveformData: waveform,
      audioDurationSeconds: duration,
    );
  }

  // ========== 성능 최적화: 사전 압축 ==========

  /// 백그라운드에서 이미지 압축을 미리 시작합니다
  ///
  /// 사용자가 캡션을 입력하는 동안 압축이 완료되므로
  /// 업로드 버튼을 눌렀을 때 즉시 업로드할 수 있습니다
  void _startPreCompressionIfNeeded() {
    // 비디오는 압축하지 않음
    if (widget.isVideo == true) return;

    // 파일 경로가 없으면 압축할 수 없음
    final filePath = widget.filePath;
    if (filePath == null || filePath.isEmpty) return;

    // 이미 같은 파일을 압축 중이면 중복 실행하지 않음
    if (_lastCompressedPath == filePath && _compressionTask != null) return;

    // 백그라운드에서 압축 시작
    debugPrint('🚀 백그라운드 압축 시작: $filePath');
    _lastCompressedPath = filePath;
    _compressionTask = _compressImageIfNeeded(File(filePath))
        .then((compressed) {
          _compressedFile = compressed;
          debugPrint('✅ 백그라운드 압축 완료: ${compressed.path}');
          return compressed;
        })
        .catchError((error) {
          debugPrint('⚠️ 백그라운드 압축 실패: $error');
          // 압축 실패 시 원본 파일 사용
          _compressedFile = File(filePath);
          return File(filePath);
        });
  }

  /// 이미지를 압축하여 파일 크기 줄이기
  /// 1MB 이하로 압축을 시도하며, 품질과 크기를 단계적으로 조정
  Future<File> _compressImageIfNeeded(File file) async {
    var currentSize = await file.length();

    // 이미 1MB 이하면 압축하지 않음
    if (currentSize <= _kMaxImageSizeBytes) {
      return file;
    }

    // 단계적으로 압축 시도
    final compressedFile = await _tryProgressiveCompression(file);
    if (compressedFile != null) {
      currentSize = await compressedFile.length();

      // 압축 성공 시 반환
      if (currentSize <= _kMaxImageSizeBytes) {
        return compressedFile;
      }
    }

    // 단계적 압축으로도 부족하면 강제 압축
    final fallbackFile = await _tryFallbackCompression(file);
    return fallbackFile ?? compressedFile ?? file;
  }

  /// 품질과 크기를 점진적으로 낮추면서 압축 시도
  Future<File?> _tryProgressiveCompression(File file) async {
    final tempDir = await getTemporaryDirectory();
    File? bestCompressed;
    var quality = _kInitialCompressionQuality;
    var dimension = _kInitialImageDimension;

    // 최소 품질에 도달할 때까지 반복
    while (quality >= _kMinCompressionQuality) {
      final compressed = await _compressWithSettings(
        file,
        tempDir,
        quality: quality,
        dimension: dimension,
        suffix: quality.toString(),
      );

      if (compressed == null) break;

      bestCompressed = compressed;
      final size = await compressed.length();

      // 목표 크기 달성하면 중단
      if (size <= _kMaxImageSizeBytes) break;

      // 품질과 크기 감소
      quality -= _kQualityDecrement;
      dimension = math.max(
        (dimension * _kDimensionScaleFactor).round(),
        _kMinImageDimension,
      );
    }

    return bestCompressed;
  }

  /// 최종 강제 압축 (최소 품질, 최소 크기)
  Future<File?> _tryFallbackCompression(File file) async {
    final tempDir = await getTemporaryDirectory();
    return await _compressWithSettings(
      file,
      tempDir,
      quality: _kFallbackCompressionQuality,
      dimension: _kFallbackImageDimension,
      suffix: 'force',
    );
  }

  /// 주어진 설정으로 이미지 압축
  Future<File?> _compressWithSettings(
    File file,
    Directory tempDir, {
    required int quality,
    required int dimension,
    required String suffix,
  }) async {
    final targetPath = p.join(
      tempDir.path,
      'soi_upload_${DateTime.now().millisecondsSinceEpoch}_$suffix.jpg',
    );

    final compressedXFile = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: quality,
      minWidth: dimension,
      minHeight: dimension,
      format: CompressFormat.jpeg,
    );

    return compressedXFile != null ? File(compressedXFile.path) : null;
  }

  Future<int?> _createDraftPost({
    required List<int> categoryIds,
    required _UploadPayload payload,
  }) {
    debugPrint("payload.caption: ${payload.caption}");
    debugPrint("categoryIds: $categoryIds");
    debugPrint("payload.waveformData: ${payload.waveformData}");
    debugPrint("payload.audioDurationSeconds: ${payload.audioDurationSeconds}");
    debugPrint("payload.isVideo: ${payload.isVideo}");
    debugPrint("payload.nickName: ${payload.nickName}");
    debugPrint("payload.userId: ${payload.userId}");

    return _postController.createPostAndReturnId(
      id: payload.userId,
      nickName: payload.nickName,
      content: "",
      categoryIds: categoryIds,
      postFileKey: "",
      audioFileKey: "",
      waveformData: "",
      duration: 0,
    );
  }

  /// 미디어 파일 업로드 메서드(UI용 메소드)
  Future<_MediaUploadResult?> _uploadMediaForPost({
    required int postId,
    required _UploadPayload payload,
  }) async {
    // 미디어 파일을 Multipart로 변환

    final mediaMultipart = await _mediaController.fileToMultipart(
      payload.mediaFile,
    );

    String? mediaKey;
    // ======== 미디어 타입에 따라 업로드 처리 =========

    // 비디오 업로드
    debugPrint("업로드할 미디어 타입: ${payload.isVideo ? '비디오' : '이미지'}");
    if (payload.isVideo) {
      final keys = await _mediaController.uploadMedia(
        files: [mediaMultipart],
        types: [MediaType.video],
        usageTypes: [MediaUsageType.post],
        userId: _userController.currentUser!.id,
        refId: postId,
      );
      debugPrint("비디오 업로드 완료, 키: ${keys.isNotEmpty ? keys.first : '없음'}");
      if (keys.isNotEmpty) {
        mediaKey = keys.first;
      }
    }
    // 이미지 업로드
    else {
      mediaKey = await _mediaController.uploadPostImage(
        file: mediaMultipart,
        userId: _userController.currentUser!.id,
        refId: postId,
      );
      debugPrint("오디오 업로드 완료, 키: $mediaKey");
    }

    if (mediaKey == null) return null;

    String? audioKey;

    // 오디오 업로드
    debugPrint("업로드할 미디어 타입: ${payload.isVideo ? '비디오' : '이미지'}");
    if (payload.audioFile != null) {
      final audioMultipart = await _mediaController.fileToMultipart(
        payload.audioFile!,
      );
      debugPrint("audioMultipart 준비 완료: ${audioMultipart.filename}");

      // 오디오 파일 업로드 후에 키 받기
      audioKey = await _mediaController.uploadPostAudio(
        file: audioMultipart,
        userId: _userController.currentUser!.id,
        refId: postId,
      );
      debugPrint("오디오 업로드 완료, 키: $audioKey");
    }

    return _MediaUploadResult(mediaKey: mediaKey, audioKey: audioKey);
  }

  /// 게시물 업로드 최종화: 내용 및 미디어 키 업데이트
  Future<void> _finalizePostUpload({
    required int postId,
    required _UploadPayload payload,
    required _MediaUploadResult mediaResult,
  }) async {
    final waveformJson = (!payload.isVideo && payload.waveformData != null)
        ? jsonEncode(payload.waveformData)
        : null;

    // 게시물 업데이트
    final success = await _postController.updatePost(
      postId: postId,
      content: payload.caption,
      postFileKey: mediaResult.mediaKey,
      audioFileKey: mediaResult.audioKey,
      waveformData: waveformJson,
      duration: payload.audioDurationSeconds,
    );

    if (!success) {
      throw Exception('게시물 업데이트에 실패했습니다.');
    }
  }

  // 화면 전환 메서드
  void _navigateToHome() {
    if (!mounted || _isDisposing) return;

    _audioController.stopRealtimeAudio();
    _audioController.clearCurrentRecording();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => HomePageNavigationBar(currentPageIndex: 2),
        settings: RouteSettings(name: '/home_navigation_screen'),
      ),
      (route) => false,
    );

    if (_draggableScrollController.isAttached) {
      _draggableScrollController.jumpTo(0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SOI',
              style: TextStyle(
                color: Color(0xfff9f9f9),
                fontSize: 20.sp,
                fontFamily: GoogleFonts.inter().fontFamily,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 30.h),
          ],
        ),
        toolbarHeight: 70.h,
        backgroundColor: Colors.black,
      ),
      body: _isLoading && !_showImmediatePreview
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white),
              ),
            )
          : Stack(
              children: [
                // 사진 영역 (스크롤 가능)
                Positioned.fill(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PhotoDisplayWidget(
                          filePath: widget.filePath,
                          useLocalImage: _useLocalImage,
                          width: 354.w,
                          height: 500.h,
                          isVideo: widget.isVideo ?? false,
                          initialImage: _initialImageProvider,
                          onCancel: _resetBottomSheetIfNeeded,
                          isFromCamera: widget.isFromCamera,
                        ),
                      ],
                    ),
                  ),
                ),
                // 텍스트 필드 영역 (고정, 키보드에 따라 올라감)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: isKeyboardVisible
                      ? 10.h
                      : MediaQuery.of(context).size.height *
                            _kLockedSheetExtent,

                  child: SizedBox(child: _buildCaptionInputBar()),
                ),
              ],
            ),
      bottomSheet: (shouldHideBottomSheet)
          ? null
          : NotificationListener<DraggableScrollableNotification>(
              onNotification: (notification) {
                // 카테고리가 선택된 상태에서는 바텀시트가 너무 내려가지 않도록 방지
                if (_selectedCategoryIds.isNotEmpty) {
                  // 바텀시트가 locked 위치 아래로 내려가려고 하면 방지
                  if (notification.extent < _kLockedSheetExtent - 0.02) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted &&
                          !_isDisposing &&
                          _draggableScrollController.isAttached) {
                        _draggableScrollController.jumpTo(_kLockedSheetExtent);
                      }
                    });
                  }
                  return true;
                }

                // 카테고리 선택 없을 때는 기존 로직
                if (!_hasLockedSheetExtent && notification.extent < 0.01) {
                  if (mounted && !_isDisposing && !_hasLockedSheetExtent) {
                    _animateSheetTo(_kLockedSheetExtent, lockExtent: true);
                  }
                }
                return true;
              },
              child: DraggableScrollableSheet(
                controller: _draggableScrollController,
                initialChildSize: _initialChildSize,
                minChildSize: _minChildSize,
                maxChildSize: _kMaxSheetExtent,
                expand: false,
                builder: (context, scrollController) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final maxHeight = constraints.maxHeight;
                      final handleHeight = _showAddCategoryUI ? 12.h : 25.h;
                      final spacing = maxHeight > handleHeight ? 4.h : 0.0;
                      final contentHeight = math.max(
                        0.0,
                        maxHeight - handleHeight - spacing,
                      );

                      return Container(
                        decoration: BoxDecoration(
                          color: Color(0xff171717),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              SizedBox(
                                height: handleHeight,
                                child: _showAddCategoryUI
                                    ? SizedBox()
                                    : Center(
                                        child: Container(
                                          height: 3.h,
                                          width: 56.w,
                                          margin: EdgeInsets.symmetric(
                                            vertical: 11.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Color(0xffcdcdcd),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                              SizedBox(height: spacing),
                              SizedBox(
                                height: contentHeight,
                                child: AnimatedSwitcher(
                                  duration: Duration(milliseconds: 300),
                                  child: _showAddCategoryUI
                                      ? ClipRect(
                                          child: LayoutBuilder(
                                            builder: (context, addConstraints) {
                                              return ConstrainedBox(
                                                constraints: BoxConstraints(
                                                  maxHeight:
                                                      addConstraints.maxHeight,
                                                  maxWidth:
                                                      addConstraints.maxWidth,
                                                ),
                                                child: AddCategoryWidget(
                                                  textController:
                                                      _categoryNameController,
                                                  scrollController:
                                                      scrollController,
                                                  focusNode: _categoryFocusNode,
                                                  onBackPressed: () {
                                                    setState(() {
                                                      _showAddCategoryUI =
                                                          false;
                                                      _categoryNameController
                                                          .clear();
                                                    });
                                                    // 바텀시트를 잠금된 상태로 복원
                                                    _animateSheetTo(
                                                      _kLockedSheetExtent,
                                                    );
                                                  },
                                                  onSavePressed:
                                                      (selectedFriends) =>
                                                          _createNewCategory(
                                                            selectedFriends,
                                                          ),
                                                ),
                                              );
                                            },
                                          ),
                                        )
                                      : CategoryListWidget(
                                          scrollController: scrollController,
                                          selectedCategoryIds:
                                              _selectedCategoryIds,
                                          onCategorySelected:
                                              _handleCategorySelection,
                                          onConfirmSelection: () {
                                            if (_selectedCategoryIds
                                                .isNotEmpty) {
                                              // 선택된 모든 카테고리에 업로드
                                              _uploadThenNavigate(
                                                _selectedCategoryIds,
                                              );
                                            }
                                          },
                                          addCategoryPressed: () {
                                            setState(
                                              () => _showAddCategoryUI = true,
                                            );
                                            _animateSheetTo(0.65);
                                          },
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }

  // ========== 헬퍼 메서드 ==========

  /// 사용자에게 에러 메시지를 SnackBar로 표시
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// mounted 상태를 체크한 후 안전하게 setState 실행
  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  // ========== 리소스 정리 메서드 ==========
  void _clearImageCache() {
    if (widget.filePath != null) {
      PaintingBinding.instance.imageCache.evict(
        FileImage(File(widget.filePath!)),
      );
    }
    if (widget.downloadUrl != null) {
      PaintingBinding.instance.imageCache.evict(
        NetworkImage(widget.downloadUrl!),
      );
    }
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  @override
  void dispose() {
    _isDisposing = true;

    // 성능 최적화: 진행 중인 압축 작업 정리
    _compressionTask = null;
    _compressedFile = null;
    _lastCompressedPath = null;

    _audioController.stopRealtimeAudio();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _audioController.clearCurrentRecording();
    });
    _recordedWaveformData = null;
    _recordedAudioPath = null;

    _clearImageCache();

    _categoryNameController.dispose();
    _captionController.removeListener(_handleCaptionChanged);
    _captionController.dispose();
    _captionFocusNode.dispose();
    _categoryFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (_draggableScrollController.isAttached) {
      _draggableScrollController.jumpTo(0.0);
    }
    _draggableScrollController.dispose();
    super.dispose();
  }
}
