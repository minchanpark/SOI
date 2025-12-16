import 'dart:async';
//import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/models/selected_friend_model.dart';
import '../../api/controller/audio_controller.dart';
import '../../api/controller/category_controller.dart' as api_category;
import '../../api/controller/media_controller.dart' as api_media;
import '../../api/controller/post_controller.dart';
import '../../api/controller/user_controller.dart';
import '../../api/services/media_service.dart';
import '../home_navigator_screen.dart';
import 'widgets/add_category_widget.dart';
import 'widgets/audio_recorder_widget.dart';
import 'widgets/caption_input_widget.dart';
import 'widgets/category_list_widget.dart';
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
  final int usageCount; // 미디어 사용 횟수

  const _UploadPayload({
    required this.userId,
    required this.nickName,
    required this.mediaFile,
    required this.mediaPath,
    required this.isVideo,
    required this.usageCount,
    this.audioFile,
    this.audioPath,
    this.caption,
    this.waveformData,
    this.audioDurationSeconds,
  });
}

class _UploadSnapshot {
  final int userId;
  final String nickName;
  final String filePath;
  final bool isVideo;
  final String captionText;
  final String? recordedAudioPath;
  final List<double>? recordedWaveformData;
  final int? recordedAudioDurationSeconds;
  final List<int> categoryIds;
  final Future<File>? compressionTask;
  final File? compressedFile;
  final String? lastCompressedPath;

  const _UploadSnapshot({
    required this.userId,
    required this.nickName,
    required this.filePath,
    required this.isVideo,
    required this.captionText,
    required this.categoryIds,
    required this.compressionTask,
    required this.compressedFile,
    required this.lastCompressedPath,
    this.recordedAudioPath,
    this.recordedWaveformData,
    this.recordedAudioDurationSeconds,
  });
}

/// 미디어 업로드 결과를 담는 클래스
///
/// 서버에 파일을 업로드한 후 받은 키(key) 값들을 저장합니다.
/// 이 키들은 나중에 게시물을 업데이트할 때 사용됩니다.
class _MediaUploadResult {
  final List<String> mediaKeys; // 사진/비디오 파일의 서버 키 목록
  final List<String> audioKeys; // 음성 파일의 서버 키 목록

  const _MediaUploadResult({required this.mediaKeys, required this.audioKeys});
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
  bool _uploadStarted = false;

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
  int? _recordedAudioDurationSeconds;
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

  // ========== 바텀시트 및 UI 상호작용 메서드들 ==========

  // 카테고리 선택/해제 핸들러
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

  // 바텀시트를 특정 크기로 애니메이션하는 메서드
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

      // 애니메이션 실행
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

  // 바텀시트를 초기 위치로 재설정하는 메서드
  Future<void> _resetBottomSheetIfNeeded() async {
    if (_isDisposing || !_draggableScrollController.isAttached) return;

    final targetSize = _hasLockedSheetExtent
        ? _kLockedSheetExtent
        : _initialChildSize;
    final currentSize = _draggableScrollController.size;

    // 애니메이션이 필요한 경우에만 실행
    if ((currentSize - targetSize).abs() > 0.001) {
      await _draggableScrollController.animateTo(
        targetSize,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  // ========== 캡션 입력 관련 메서드들 ==========

  // 마이크 아이콘 탭 핸들러
  void _handleMicTap() {
    // 오디오 녹음 위젯 표시를 위해서 상태변수값 변경
    setState(() => _showAudioRecorder = true);

    // 캡션 입력창 포커스 해제
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
                audioController: _audioController,
                autoStart: true,
                onRecordingFinished: (audioFilePath, waveformData, duration) {
                  setState(() {
                    _recordedAudioPath = audioFilePath; // 녹음된 오디오 파일 경로 저장
                    _recordedWaveformData = waveformData; // 파형 데이터 저장
                    _recordedAudioDurationSeconds =
                        duration.inSeconds; // 녹음 길이 저장
                  });
                },
                onRecordingCleared: () {
                  setState(() {
                    _showAudioRecorder = false;
                    _recordedAudioPath = null;
                    _recordedWaveformData = null;
                    _recordedAudioDurationSeconds = null;
                  });
                  _audioController.clearCurrentRecording();
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

  // ========== 임시 파일 삭제 메서드들 ==========

  /// 임시 파일을 삭제하는 메소드입니다.
  Future<void> _deleteTemporaryFile(File file, String path) async {
    if (!path.contains('/tmp/')) return;

    try {
      if (await file.exists()) {
        await file.delete();
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

  // ========== 업로드 메서드들 ==========

  /// 미디어를 업로드하고 홈 화면으로 이동하는 메서드입니다.
  ///
  /// Parameters:
  ///   - [categoryIds]: 업로드할 게시물에 연결할 카테고리 ID 목록
  Future<void> _uploadThenNavigate(List<int> categoryIds) async {
    if (_uploadStarted) return;

    _uploadStarted = true;

    try {
      final currentUser = _userController.currentUser;
      if (currentUser == null) {
        _showErrorSnackBar('로그인 후 다시 시도해주세요.');
        _uploadStarted = false;
        return;
      }

      final filePath = widget.filePath;
      if (filePath == null || filePath.isEmpty) {
        _safeSetState(() {
          _errorMessage = '업로드할 파일을 찾을 수 없습니다.';
        });
        _uploadStarted = false;
        return;
      }

      final snapshot = _UploadSnapshot(
        userId: currentUser.id,
        nickName: currentUser.userId,
        filePath: filePath,
        isVideo: widget.isVideo ?? false,
        captionText: _captionController.text.trim(),
        recordedAudioPath: _recordedAudioPath,
        recordedWaveformData: _recordedWaveformData != null
            ? List<double>.from(_recordedWaveformData!)
            : null,
        recordedAudioDurationSeconds: _recordedAudioDurationSeconds,
        categoryIds: List<int>.from(categoryIds),
        compressionTask: _compressionTask,
        compressedFile: _compressedFile,
        lastCompressedPath: _lastCompressedPath,
      );

      // home_navigation_screen으로 먼저 이동
      _navigateToHome();

      // (배포버전 체감 개선) post-frame 콜백을 1번만 걸면 "전환 직후" 같은 프레임 끝에서
      // 무거운 작업이 바로 시작되어, 새 화면의 첫 페인트가 밀릴 수 있습니다.
      // 최소 1프레임 더 양보한 뒤 업로드 파이프라인을 시작합니다.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          unawaited(_runUploadPipelineAfterNavigation(snapshot));
        });
      });
    } catch (e) {
      debugPrint('업로드 실패: $e');
      _uploadStarted = false;
    }
  }

  /// 업로드를 실행하는 메서드입니다.
  /// 업로드 로직을 화면 전환 이후에 실행하여 사용자 경험을 향상시킵니다.
  ///
  /// Parameters:
  ///  - [snapshot]: 업로드에 필요한 모든 데이터를 담은 스냅샷 객체
  Future<void> _runUploadPipelineAfterNavigation(
    _UploadSnapshot snapshot,
  ) async {
    try {
      // UI 전환 이후에 무거운 작업들을 시작 (dispose와 무관하게 동작하도록 스냅샷 사용)
      unawaited(_audioController.stopRealtimeAudio());
      _audioController.clearCurrentRecording();

      // 캐시는 전체 clear 대신 현재 사용한 이미지 정도만 evict
      _evictCurrentImageFromCache(filePath: snapshot.filePath);

      // 성능 최적화: 업로드 전에 미리 압축된 파일이 있는지 확인
      final payload = await _prepareUploadPayloadFromSnapshot(snapshot);
      if (payload == null) {
        _uploadStarted = false;
        return;
      }

      await _uploadPostInBackground(
        categoryIds: snapshot.categoryIds,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[PhotoEditor] 업로드 파이프라인 실패: $e');
    } finally {
      _uploadStarted = false;
    }
  }

  /// 백그라운드에서 게시물을 업로드하는 메서드입니다.
  ///
  /// Parameters:
  ///   - [categoryIds]: 업로드할 게시물에 연결할 카테고리 ID 목록
  ///   - [payload]: 업로드에 필요한 데이터 묶음
  Future<void> _uploadPostInBackground({
    required List<int> categoryIds,
    required _UploadPayload payload,
  }) async {
    try {
      final mediaResult = await _uploadMediaForPost(payload: payload);
      if (mediaResult == null) {
        throw Exception('미디어 업로드에 실패했습니다.');
      }

      // 게시물 생성
      final createSuccess = await _createPostWithMedia(
        categoryIds: categoryIds,
        payload: payload,
        mediaResult: mediaResult,
      );
      if (!createSuccess) {
        throw Exception('게시물 생성에 실패했습니다.');
      }

      // 카테고리 대표 사진(썸네일) 등 최신 상태가 아카이브 메인에 즉시 반영되도록 강제 갱신
      // (PhotoEditor는 화면 전환 후 dispose될 수 있으므로 context/mounted 의존 없이 컨트롤러만 사용)
      try {
        await _categoryController.loadCategories(
          payload.userId,
          forceReload: true,
        );
      } catch (e) {
        debugPrint('[PhotoEditor] 카테고리 강제 갱신 실패(무시): $e');
      }

      unawaited(_deleteTemporaryFilesInBackground(payload));
    } catch (e) {
      debugPrint('[PhotoEditor] 백그라운드 업로드 실패: $e');
    }
  }

  Future<_UploadPayload?> _prepareUploadPayloadFromSnapshot(
    _UploadSnapshot snapshot,
  ) async {
    final filePath = snapshot.filePath;

    var mediaFile = File(filePath);
    if (!await mediaFile.exists()) {
      debugPrint('[PhotoEditor] 미디어 파일을 찾을 수 없습니다: $filePath');
      return null;
    }

    if (!snapshot.isVideo) {
      try {
        if (snapshot.compressedFile != null &&
            snapshot.lastCompressedPath == filePath) {
          mediaFile = snapshot.compressedFile!;
        } else if (snapshot.compressionTask != null &&
            snapshot.lastCompressedPath == filePath) {
          mediaFile = await snapshot.compressionTask!;
        } else {
          mediaFile = await _compressImageIfNeeded(mediaFile);
        }
      } catch (e) {
        debugPrint('[PhotoEditor] 이미지 압축 실패(원본 사용): $e');
      }
    }

    File? audioFile;
    String? audioPath;
    final candidatePath = snapshot.recordedAudioPath;
    if (candidatePath != null && candidatePath.isNotEmpty) {
      final file = File(candidatePath);
      if (await file.exists()) {
        audioFile = file;
        audioPath = candidatePath;
      }
    }

    final captionText = snapshot.captionText;
    final caption = captionText.isNotEmpty ? captionText : '';
    final hasCaption = caption.isNotEmpty;

    final shouldIncludeAudio =
        !hasCaption &&
        audioFile != null &&
        snapshot.recordedWaveformData != null;
    final waveform = shouldIncludeAudio && snapshot.recordedWaveformData != null
        ? List<double>.from(snapshot.recordedWaveformData!)
        : null;

    return _UploadPayload(
      userId: snapshot.userId,
      nickName: snapshot.nickName,
      mediaFile: mediaFile,
      mediaPath: mediaFile.path,
      isVideo: snapshot.isVideo,
      audioFile: shouldIncludeAudio ? audioFile : null,
      audioPath: shouldIncludeAudio ? audioPath : null,
      caption: caption,
      waveformData: waveform,
      audioDurationSeconds: shouldIncludeAudio
          ? snapshot.recordedAudioDurationSeconds
          : null,
      usageCount: snapshot.categoryIds.isNotEmpty
          ? snapshot.categoryIds.length
          : 1,
    );
  }

  /// 미디어 파일 업로드 메서드(UI용 메소드)
  Future<_MediaUploadResult?> _uploadMediaForPost({
    required _UploadPayload payload,
  }) async {
    final files = <http.MultipartFile>[];
    final types = <MediaType>[];
    final usageTypes = <MediaUsageType>[];

    // 사진/비디오 파일을 Multipart로 변환
    final mediaMultipart = await _mediaController.fileToMultipart(
      payload.mediaFile,
    );

    // 미디어 파일 추가
    files.add(mediaMultipart);

    // 미디어 타입 및 사용 용도 설정
    types.add(payload.isVideo ? MediaType.video : MediaType.image);
    usageTypes.add(MediaUsageType.post);

    // 음성 파일이 있으면 추가
    if (payload.audioFile != null) {
      // 음성 파일을 Multipart로 변환
      final audioMultipart = await _mediaController.fileToMultipart(
        payload.audioFile!,
      );

      // 음성 파일 추가
      files.add(audioMultipart);

      // 음성 타입 설정
      types.add(MediaType.audio);

      // 음성도 게시물 용도로 설정
      usageTypes.add(MediaUsageType.post);
    }

    // 미디어 업로드 호출
    final keys = await _mediaController.uploadMedia(
      files: files,
      types: types,
      usageTypes: usageTypes,
      userId: payload.userId,
      refId: payload.userId,
      usageCount: payload.usageCount,
    );

    if (keys.isEmpty) {
      return null;
    }

    final mediaKeys = <String>[];
    final audioKeys = <String>[];
    final perTypeCount = payload.usageCount <= 0 ? 1 : payload.usageCount;
    var index = 0;

    for (var i = 0; i < perTypeCount && index < keys.length; i++) {
      mediaKeys.add(keys[index++]);
    }

    if (payload.audioFile != null) {
      for (var i = 0; i < perTypeCount && index < keys.length; i++) {
        audioKeys.add(keys[index++]);
      }
    }

    if (mediaKeys.length < perTypeCount ||
        (payload.audioFile != null && audioKeys.length < perTypeCount)) {
      debugPrint('[PhotoEditor] 반환된 미디어 키 수가 기대치와 다릅니다. keys: $keys');
      return null;
    }

    return _MediaUploadResult(mediaKeys: mediaKeys, audioKeys: audioKeys);
  }

  /// 화면 전환 메서드
  void _navigateToHome() {
    if (!mounted || _isDisposing) return;

    _audioController.stopRealtimeAudio();
    _audioController.clearCurrentRecording();

    // (배포버전 프리즈 방지) 홈을 새로 push해서 기존 라우트들을 전부 dispose시키면
    // dispose 내부의 무거운 정리 작업(특히 imageCache.clear)이 한 번에 실행되며 프리즈가 생길 수 있습니다.
    // 따라서: "기존 홈으로 popUntil 복귀 + 탭만 변경"으로 전환 비용을 최소화합니다.
    HomePageNavigationBar.requestTab(2);

    final navigator = Navigator.of(context);
    var foundHome = false;
    navigator.popUntil((route) {
      final isHome = route.settings.name == '/home_navigation_screen';
      foundHome = foundHome || isHome;
      return isHome || route.isFirst;
    });

    // 홈 라우트가 스택에 없으면(예: 딥링크 진입) 기존 방식으로만 fallback
    if (!foundHome && mounted) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomePageNavigationBar(
            key: HomePageNavigationBar.rootKey,
            currentPageIndex: 2,
          ),
          settings: const RouteSettings(name: '/home_navigation_screen'),
        ),
        (route) => false,
      );
    }

    if (_draggableScrollController.isAttached) {
      _draggableScrollController.jumpTo(0.0);
    }
  }

  /// 업로드된 키를 포함해 게시물을 최종 생성
  Future<bool> _createPostWithMedia({
    required List<int> categoryIds,
    required _UploadPayload payload,
    required _MediaUploadResult mediaResult,
  }) async {
    // 파형 데이터를 JSON 문자열로 인코딩
    final waveformJson = _encodeWaveformData(payload.waveformData);

    // (배포버전 성능) 대용량 문자열 로그는 프레임 드랍/프리즈를 유발할 수 있어 디버그에서만 출력합니다.
    if (kDebugMode) {
      debugPrint(
        "[PhotoEditor] userId: ${payload.userId}\nnickName: ${payload.nickName}\ncontent: ${payload.caption}\npostFileKey: ${mediaResult.mediaKeys}\naudioFileKey: ${mediaResult.audioKeys}\ncategoryIds: $categoryIds\nwaveformData: $waveformJson\nduration: ${payload.audioDurationSeconds}",
      );
    }

    // 게시물 생성 API 호출
    final success = await _postController.createPost(
      userId: payload.userId,
      nickName: payload.nickName,
      content: payload.caption,
      postFileKey: mediaResult.mediaKeys,
      audioFileKey: mediaResult.audioKeys,
      categoryIds: categoryIds,
      waveformData: waveformJson,
      duration: payload.audioDurationSeconds,
    );

    // (배포버전 성능) 대용량 문자열 로그는 프레임 드랍/프리즈를 유발할 수 있어 디버그에서만 출력합니다.
    if (kDebugMode) debugPrint('[PhotoEditor] 게시물 생성 결과: $success');

    return success;
  }

  /// 파형 데이터를 JSON 문자열로 인코딩
  String? _encodeWaveformData(List<double>? waveformData) {
    if (waveformData == null || waveformData.isEmpty) {
      return null;
    }
    final normalized = waveformData
        .map((value) => double.parse(value.toStringAsFixed(6)))
        .map((value) => value.toString())
        .toList();
    return normalized.join(', ');
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
    _lastCompressedPath = filePath;
    _compressionTask = _compressImageIfNeeded(File(filePath))
        .then((compressed) {
          _compressedFile = compressed;
          return compressed;
        })
        .catchError((error) {
          debugPrint('백그라운드 압축 실패: $error');
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
    _evictCurrentImageFromCache(
      filePath: widget.filePath,
      downloadUrl: widget.downloadUrl,
    );
  }

  void _evictCurrentImageFromCache({String? filePath, String? downloadUrl}) {
    if (filePath != null && filePath.isNotEmpty) {
      PaintingBinding.instance.imageCache.evict(FileImage(File(filePath)));
    }
    if (downloadUrl != null && downloadUrl.isNotEmpty) {
      PaintingBinding.instance.imageCache.evict(NetworkImage(downloadUrl));
    }
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
    _recordedAudioDurationSeconds = null;

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
