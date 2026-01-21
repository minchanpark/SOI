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
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
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

/// 업로드 성능 추적 클래스
class _UploadPerfTrace {
  final String label;
  final Stopwatch _stopwatch = Stopwatch()..start();

  _UploadPerfTrace(this.label);

  void mark(String step) {
    if (!kDebugMode) return;
    debugPrint('[Perf][$label] +${_stopwatch.elapsedMilliseconds}ms $step');
  }
}

/// 파형 데이터를 인코딩하는 함수s
///
/// Parameters:
/// - [waveformData]: 파형 데이터 리스트
///
/// Returns:
/// - 인코딩된 파형 데이터 문자열
String _encodeWaveformDataWorker(List<double> waveformData) {
  if (waveformData.isEmpty) return '';

  final buffer =
      StringBuffer(); // StringBuffer 사용 --> StringBuffer란, 문자열을 효율적으로 생성하기 위한 클래스

  // 파형 데이터를 쉼표로 구분된 문자열로 변환
  for (var i = 0; i < waveformData.length; i++) {
    if (i > 0) buffer.write(', ');
    buffer.write(double.parse(waveformData[i].toStringAsFixed(6)).toString());
  }
  return buffer.toString(); // 최종 문자열 반환
}

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
///
/// _UploadSnapshot 클래스와 달리, 이 클래스는 실제 업로드 시점에 사용됩니다.
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

/// 업로드에 필요한 모든 데이터를 스냅샷으로 담는 클래스
/// 이 클래스를 만든 이유는, 업로드가 화면 전환 이후에 비동기적으로 실행되기 때문에,
/// 업로드에 필요한 모든 데이터를 미리 캡처해서 보존하기 위함입니다.
///
/// _UploadPayload 클래스와 달리, 이 클래스는 화면 전환 전에 필요한 모든 정보를 담고 있습니다.
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
  String? _errorMessageKey;
  Map<String, String>? _errorMessageArgs;
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
  static const int _kMaxVideoSizeBytes =
      20 * 1024 * 1024; // [VideoCompress] 20MB

  // 최소 크기는 처음에는 0에서 시작하여 애니메이션으로 잠금 위치까지 이동
  double _minChildSize = _kInitialSheetExtent;

  // 초기값은 0에서 시작
  //double _initialChildSize = _kInitialSheetExtent;
  double _initialChildSize = 0.19;

  // 잠금 상태 플래그
  // 이 플래그로 바텀시트가 잠금 상태인지 여부를 추적
  bool _hasLockedSheetExtent = false;

  // 애니메이션 진행 중 플래그 (레이스 컨디션 방지용)
  bool _isAnimatingSheet = false;

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
    // 카테고리 이름 입력 포커스 리스너 추가
    _categoryFocusNode.addListener(_onCategoryFocusChange);
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

  // AddCategoryWidget 컨텐츠에 필요한 바텀시트 extent를 동적으로 계산
  double _calculateAddCategorySheetExtent({bool withKeyboard = false}) {
    final screenHeight = MediaQuery.of(context).size.height;
    // AddCategoryWidget 컨텐츠 높이 (헤더 48 + 구분선 1 + 패딩 20 + 친구버튼 35 + 텍스트필드 48 + 카운터 18 + 여유 30)
    const contentHeight = 200.0;

    // 키보드가 올라올 때는 키보드 높이도 고려
    final keyboardHeight = withKeyboard ? (this.keyboardHeight + 200) : 0.0;

    // 필요한 총 높이
    final totalNeeded = contentHeight + keyboardHeight;

    // 화면 비율로 변환 (최소 0.25, 최대 0.65)
    final extent = (totalNeeded / screenHeight).clamp(0.25, 0.65);
    return extent;
  }

  // 카테고리 이름 입력 포커스 변경 리스너
  void _onCategoryFocusChange() {
    if (!mounted || _isDisposing) return;

    if (_categoryFocusNode.hasFocus && _showAddCategoryUI) {
      // 키보드가 올라올 때 바텀시트 확장 (동적 계산)
      _animateSheetTo(_calculateAddCategorySheetExtent(withKeyboard: true));
    } else if (!_categoryFocusNode.hasFocus && _showAddCategoryUI) {
      // 키보드가 내려갈 때 바텀시트 축소 (동적 계산)
      _animateSheetTo(_calculateAddCategorySheetExtent(withKeyboard: false));
    }
  }

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
    _errorMessageKey = null;
    _errorMessageArgs = null;

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
          _errorMessageKey = 'camera.editor.image_not_found';
          _errorMessageArgs = null;
          _isLoading = false;
        });
        return;
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _errorMessageKey = 'camera.editor.image_load_error_with_reason';
          _errorMessageArgs = {'error': e.toString()};
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
          _errorMessageKey = 'common.login_required';
          _errorMessageArgs = null;
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
          _errorMessageKey = 'camera.editor.category_load_error_with_reason';
          _errorMessageArgs = {'error': e.toString()};
        });
      }
    }
  }

  // ========== 바텀시트 및 UI 상호작용 메서드들 ==========

  // 카테고리 선택/해제 핸들러
  void _handleCategorySelection(int categoryId) {
    setState(() {
      if (_selectedCategoryIds.contains(categoryId)) {
        _selectedCategoryIds.remove(categoryId);
      } else {
        _selectedCategoryIds.add(categoryId);
      }
    });

    // 카테고리 선택 상태에 따라 바텀시트 높이 조정
    if (_selectedCategoryIds.isEmpty) {
      // 모든 카테고리가 해제되면 기본 위치로
      _animateSheetTo(_kLockedSheetExtent);
    } else {
      // 카테고리가 선택된 상태 → 바텀시트가 버튼보다 아래에 있으면 올림
      // 현재 위치 체크는 postFrameCallback 내부에서 수행하여 타이밍 갭 방지
      _animateSheetToIfNeeded(_kExpandedSheetExtent);
    }
  }

  // 바텀시트가 목표 위치보다 아래에 있을 때만 애니메이션 실행
  void _animateSheetToIfNeeded(double targetSize) {
    if (!mounted || _isDisposing) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposing) return;
      if (!_draggableScrollController.isAttached) return;

      // 현재 위치를 postFrameCallback 내부에서 체크 (타이밍 갭 해결)
      final currentExtent = _draggableScrollController.size;

      // 이미 확장된 상태(목표 위치 근처 또는 그 이상)라면 애니메이션 불필요
      if (currentExtent >= targetSize - 0.02) {
        return;
      }

      _animateSheetTo(targetSize);
    });
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

      // Controller가 attach될 때까지 재시도 (최대 50번, 10ms 간격)
      if (!_draggableScrollController.isAttached) {
        if (retryCount < 50) {
          await Future.delayed(const Duration(milliseconds: 10));
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

      // 애니메이션 시작 플래그 설정 (레이스 컨디션 방지)
      _isAnimatingSheet = true;

      try {
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
      } finally {
        // 애니메이션 종료 플래그 해제
        _isAnimatingSheet = false;
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
      _showErrorSnackBar(
        tr('archive.create_category_name_required', context: context),
      );
      return;
    }

    try {
      // 현재 사용자 정보 가져오기
      final user = _userController.currentUser;
      if (user == null) {
        _showErrorSnackBar(
          tr('common.login_required_relogin', context: context),
        );
        return;
      }

      // 카테고리에 초대된 사용자 ID 목록 생성
      // PUBLIC 카테고리인 경우에만 본인 및 친구 ID 추가
      final isPublicCategory = selectedFriends.isNotEmpty;
      final receiverIds = <int>[];
      if (isPublicCategory) {
        receiverIds.add(user.id);
        for (final friend in selectedFriends) {
          final parsedId = int.tryParse(friend.uid);
          if (parsedId != null && !receiverIds.contains(parsedId)) {
            receiverIds.add(parsedId);
          }
        }
      }

      // 카테고리 생성 API 호출
      final categoryId = await _categoryController.createCategory(
        requesterId: user.id,
        name: _categoryNameController.text.trim(),
        receiverIds: receiverIds,
        isPublic: isPublicCategory,
      );

      if (categoryId == null) {
        _showErrorSnackBar(
          tr('camera.editor.category_create_failed_retry', context: context),
        );
        return;
      }

      _categoriesLoaded = false;

      // 카테고리를 새로 만들고 나면 카테고리 목록을 새로고침
      await _categoryController.loadCategories(
        user.id,
        forceReload: true,
        fetchAllPages: true,
        maxPages: 2,
      );

      _safeSetState(() {
        _showAddCategoryUI = false;
        _categoryNameController.clear();
      });
    } catch (e) {
      _showErrorSnackBar(
        tr('camera.editor.category_create_error', context: context),
      );
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

    _uploadStarted = true; // 중복 업로드 방지 플래그 설정

    try {
      // 현재 사용자 정보 확인
      final currentUser = _userController.currentUser;
      if (currentUser == null) {
        _showErrorSnackBar(tr('common.login_required_retry', context: context));
        _uploadStarted = false;
        return;
      }

      // 업로드할 파일 경로 확인
      final filePath = widget.filePath;
      if (filePath == null || filePath.isEmpty) {
        _safeSetState(() {
          _errorMessageKey = 'camera.editor.upload_file_not_found';
          _errorMessageArgs = null;
        });
        _uploadStarted = false;
        return;
      }

      // 업로드에 필요한 모든 데이터를 스냅샷으로 미리 캡처
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

      // 화면 전환이 완료된 후에 업로드 파이프라인 실행
      // 두 번의 프레임을 늦춘 다음, 업로드를 시작합니다
      // (이중 지연을 통해 화면 전환이 완전히 끝난 후에 업로드가 시작되도록 보장)
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
    final perf = _UploadPerfTrace('PhotoEditor.upload');
    try {
      // UI 전환 이후에 무거운 작업들을 시작 (dispose와 무관하게 동작하도록 스냅샷 사용)
      unawaited(_audioController.stopRealtimeAudio());

      // 녹음된 오디오 초기화
      _audioController.clearCurrentRecording();

      // 캐시는 전체 clear 대신 현재 사용한 이미지 정도만 정리하여서 메모리 사용량을 줄임
      _evictCurrentImageFromCache(filePath: snapshot.filePath);

      // 성능 최적화: 업로드 전에 미리 압축된 파일이 있는지 확인
      // 미리 압축된 파일이 있다면 --> 그 파일을 사용
      // 미리 압축된 파일이 없다면 --> 새로 압축 수행
      final payload = await _prepareUploadPayloadFromSnapshot(snapshot);
      perf.mark('payload prepared');
      if (payload == null) {
        _uploadStarted = false;
        return;
      }

      // 백그라운드에서 업로드 실행
      await _uploadPostInBackground(
        categoryIds: snapshot.categoryIds,
        payload: payload,
      );
      perf.mark('pipeline finished');
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
    final perf = _UploadPerfTrace('PhotoEditor.upload.bg');
    try {
      final mediaResult = await _uploadMediaForPost(payload: payload);
      perf.mark('media uploaded');
      if (mediaResult == null) {
        throw Exception('미디어 업로드에 실패했습니다.');
      }

      // [Video] 게시물 생성 + 카테고리 대표 이미지 업데이트를 병렬로 처리
      final createPostFuture = _createPostWithMedia(
        categoryIds: categoryIds,
        payload: payload,
        mediaResult: mediaResult,
      );
      Future<bool>? updateCategoryCoverFuture;
      if (payload.isVideo && categoryIds.isNotEmpty) {
        updateCategoryCoverFuture = _updateCategoryCoverFromVideo(
          categoryIds: categoryIds,
          payload: payload,
        );
      }

      final results = await Future.wait([
        createPostFuture,
        if (updateCategoryCoverFuture != null) updateCategoryCoverFuture,
      ]);

      final createSuccess = results.isNotEmpty && results.first == true;
      perf.mark('post created');
      if (!createSuccess) {
        throw Exception('게시물 생성에 실패했습니다.');
      }
      if (results.length > 1 && results[1] == false) {
        debugPrint('[PhotoEditor] 비디오 썸네일로 카테고리 업데이트 실패');
      }

      // 카테고리 대표 사진(썸네일) 등 최신 상태가 아카이브 메인에 즉시 반영되도록 강제 갱신
      // (PhotoEditor는 화면 전환 후 dispose될 수 있으므로 context/mounted 의존 없이 컨트롤러만 사용)
      try {
        await _categoryController.loadCategories(
          payload.userId,
          forceReload: true,
        );
        perf.mark('categories refreshed');
      } catch (e) {
        debugPrint('[PhotoEditor] 카테고리 강제 갱신 실패(무시): $e');
      }

      // 업로드가 끝난 후 임시 파일들을 백그라운드에서 삭제
      unawaited(_deleteTemporaryFilesInBackground(payload));
    } catch (e) {
      debugPrint('[PhotoEditor] 백그라운드 업로드 실패: $e');
    } finally {
      // [VideoCompress] 임시 캐시 정리
      if (!kIsWeb) {
        // 웹에서는 VideoCompress 패키지를 사용하지 않음
        unawaited(VideoCompress.deleteAllCache());
      }
    }
  }

  Future<_UploadPayload?> _prepareUploadPayloadFromSnapshot(
    _UploadSnapshot snapshot,
  ) async {
    // 미디어 파일 경로 확인
    final filePath = snapshot.filePath;

    // 미디어 파일 존재 여부 확인
    var mediaFile = File(filePath);
    if (!await mediaFile.exists()) {
      debugPrint('[PhotoEditor] 미디어 파일을 찾을 수 없습니다: $filePath');
      return null;
    }

    if (snapshot.isVideo) {
      try {
        // 비디오 파일인 경우 압축 수행
        mediaFile = await _compressVideoIfNeeded(mediaFile);
      } catch (e) {
        debugPrint('[PhotoEditor] 비디오 압축 실패(원본 사용): $e');
      }
    } else {
      try {
        if (snapshot.compressedFile != null &&
            snapshot.lastCompressedPath == filePath) {
          // 미리 압축된 파일이 있으면 그것을 사용
          mediaFile = snapshot.compressedFile!;
        } else if (snapshot.compressionTask != null &&
            snapshot.lastCompressedPath == filePath) {
          // 백그라운드에서 압축이 완료된 파일이 있으면 그것을 사용
          mediaFile = await snapshot.compressionTask!;
        } else {
          // 미리 압축된 파일이 없고 백그라운드에서 압축도 안 된 경우
          // 새로 이미지 압축 수행
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
      // 녹음된 오디오 파일 존재 여부 확인
      final file = File(candidatePath);
      if (await file.exists()) {
        audioFile = file; // 오디오 파일 설정
        audioPath = candidatePath; // 오디오 파일 경로 설정
      }
    }

    final captionText = snapshot.captionText;
    final caption = captionText.isNotEmpty ? captionText : '';
    final hasCaption = caption.isNotEmpty;

    final shouldIncludeAudio =
        !hasCaption &&
        audioFile != null &&
        snapshot.recordedWaveformData != null;

    // 파형 데이터는 오디오가 첨부되는 경우에만 포함
    final waveform = shouldIncludeAudio ? snapshot.recordedWaveformData : null;

    // 업로드 페이로드 생성
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
    final perf = _UploadPerfTrace('PhotoEditor.upload.media');
    final files = <http.MultipartFile>[];
    final types = <MediaType>[];
    final usageTypes = <MediaUsageType>[];

    // 사진/비디오 파일을 Multipart로 변환
    final mediaMultipart = await _mediaController.fileToMultipart(
      payload.mediaFile,
    );
    perf.mark('multipart(media) ready');

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
      perf.mark('multipart(audio) ready');

      // 음성 파일 추가
      files.add(audioMultipart);

      // 음성 타입 설정
      types.add(MediaType.audio);

      // 음성도 게시물 용도로 설정
      usageTypes.add(MediaUsageType.post);
    }

    perf.mark('multipart all ready (upload start)');
    // 미디어 업로드 호출
    final keys = await _mediaController.uploadMedia(
      files: files,
      types: types,
      usageTypes: usageTypes,
      userId: payload.userId,
      refId: payload.userId,
      usageCount: payload.usageCount,
    );
    perf.mark('uploadMedia done');

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
    perf.mark('keys split');

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
    final waveformJson = await _encodeWaveformDataAsync(payload.waveformData);

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

  // [Video] 썸네일 추출 -> 업로드 -> 카테고리 대표 이미지 변경
  Future<bool> _updateCategoryCoverFromVideo({
    required List<int> categoryIds,
    required _UploadPayload payload,
  }) async {
    if (!payload.isVideo || categoryIds.isEmpty) return true;

    // 추출된 썸네일 파일을 저장할 변수
    File? thumbnailFile;

    try {
      // 비디오 썸네일 추출
      thumbnailFile = await _extractVideoThumbnailFile(payload.mediaPath);
      if (thumbnailFile == null) {
        debugPrint('[PhotoEditor] 비디오 썸네일 생성 실패');
        return false;
      }

      final multipart = await _mediaController.fileToMultipart(
        thumbnailFile,
      ); // Multipart로 File을 변환

      final usageCount = categoryIds.length;

      // 썸네일을 미디어 서버에 업로드드해서 키를 받음
      final keys = await _mediaController.uploadMedia(
        files: [multipart],
        types: [MediaType.image],
        usageTypes: [MediaUsageType.categoryProfile],
        userId: payload.userId,
        refId: categoryIds.first,
        usageCount: usageCount,
      );

      if (keys.length < usageCount) {
        debugPrint('[PhotoEditor] 카테고리 썸네일 키 수가 부족합니다. keys: $keys');
        return false;
      }

      // 각 카테고리에 대해 썸네일 키로 대표 이미지 업데이트
      final results = await Future.wait([
        // 각 카테고리에 대해 대표 이미지 업데이트
        for (var i = 0; i < usageCount; i++)
          _categoryController.updateCustomProfile(
            categoryId: categoryIds[i],
            userId: payload.userId,
            profileImageKey: keys[i],
          ),
      ]);

      return results.every((value) => value == true);
    } catch (e) {
      debugPrint('[PhotoEditor] 비디오 썸네일 업로드/카테고리 업데이트 실패: $e');
      return false;
    } finally {
      if (thumbnailFile != null) {
        try {
          await thumbnailFile.delete(); // 임시 썸네일 파일 삭제
        } catch (e) {
          return false;
        }
      }
    }
  }

  /// 비디오 썸네일 추출 메서드
  Future<File?> _extractVideoThumbnailFile(String videoPath) async {
    if (kIsWeb) return null;
    try {
      final tempDir = await getTemporaryDirectory(); // 임시 디렉토리 경로 가져오기

      // 비디오 썸네일 생성
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 720,
        quality: 80,
      );
      if (thumbnailPath == null || thumbnailPath.isEmpty) return null;
      return File(thumbnailPath); // 썸네일 파일 반환
    } catch (e) {
      debugPrint('[PhotoEditor] 비디오 썸네일 추출 실패: $e');
      return null;
    }
  }

  /// 파형 데이터를 JSON 문자열로 인코딩
  String? _encodeWaveformData(List<double>? waveformData) {
    if (waveformData == null || waveformData.isEmpty) {
      return null;
    }
    // List로 받으 waveformData를 encoding 작업 수행
    final encoded = _encodeWaveformDataWorker(waveformData);
    return encoded.isEmpty ? null : encoded;
  }

  Future<String?> _encodeWaveformDataAsync(List<double>? waveformData) async {
    if (waveformData == null || waveformData.isEmpty) {
      return null;
    }

    // 작은 데이터는 Isolate 오버헤드가 더 클 수 있어 동기 처리.
    if (kIsWeb || waveformData.length < 800) {
      return _encodeWaveformData(waveformData);
    }

    try {
      // 큰 데이터는 Isolate에서 처리하여 메인 스레드 부하 감소
      // Isolate란, Dart에서 별도의 스레드처럼 동작하는 독립적인 실행 컨텍스트입니다.
      final encoded = await compute(_encodeWaveformDataWorker, waveformData);
      return encoded.isEmpty ? null : encoded;
    } catch (e) {
      debugPrint('[PhotoEditor] waveform encode isolate failed: $e');
      return _encodeWaveformData(waveformData);
    }
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

  /// 비디오 크기를 줄여 업로드 실패(413)를 방지합니다.
  /// 비디오 크기가 50MB를 초과하는 경우에만 압축을 시도합니다.
  ///
  /// Parameters:
  ///  - [file]: 압축할 비디오 파일
  ///
  /// Returns:
  ///   - 압축된 비디오 파일 또는 원본 파일
  Future<File> _compressVideoIfNeeded(File file) async {
    if (kIsWeb) return file;

    final size = await file.length();
    if (size <= _kMaxVideoSizeBytes) {
      return file;
    }

    var compressed = await _tryCompressVideo(file, VideoQuality.MediumQuality);
    if (compressed == null) {
      return file;
    }

    final compressedSize = await compressed.length();
    if (compressedSize > _kMaxVideoSizeBytes) {
      final lower = await _tryCompressVideo(file, VideoQuality.LowQuality);
      if (lower != null) {
        compressed = lower;
      }
    }

    return compressed;
  }

  /// 비디오를 지정된 품질로 압축 시도
  /// 실패 시 null 반환
  ///
  /// Parameters:
  ///   - [file]: 압축할 비디오 파일
  ///   - [quality]: 압축 품질 설정
  ///
  /// Returns:
  ///   - 압축된 비디오 파일 또는 null
  Future<File?> _tryCompressVideo(File file, VideoQuality quality) async {
    try {
      final info = await VideoCompress.compressVideo(
        file.path,
        quality: quality,
        includeAudio: true,
        deleteOrigin: false,
      );
      return info?.file;
    } catch (e) {
      debugPrint('[PhotoEditor] 비디오 압축 실패: $e');
      return null;
    }
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
          : _errorMessageKey != null
          ? Center(
              child: Text(
                _errorMessageKey!,
                style: const TextStyle(color: Colors.white),
              ).tr(namedArgs: _errorMessageArgs),
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
                // 애니메이션 진행 중이면 간섭하지 않음 (레이스 컨디션 방지)
                if (_isAnimatingSheet) {
                  return true;
                }

                // 카테고리가 선택된 상태에서는 바텀시트가 너무 내려가지 않도록 방지
                if (_selectedCategoryIds.isNotEmpty) {
                  // 바텀시트가 locked 위치 아래로 내려가려고 하면 방지
                  if (notification.extent < _kLockedSheetExtent - 0.02) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted &&
                          !_isDisposing &&
                          !_isAnimatingSheet && // 애니메이션 중이 아닐 때만
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
                                              // 카테고리 추가 UI
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
                                      // 카테고리 목록 UI
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
                                            _animateSheetTo(
                                              (0.3).sp,
                                            ); // 카테고리를 추가할 때는 시트를 0.3로 변경
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

  /// 이미지 캐시를 정리하는 메서드
  void _clearImageCache() {
    _evictCurrentImageFromCache(
      filePath: widget.filePath,
      downloadUrl: widget.downloadUrl,
    );
  }

  /// 현재 사용된 이미지들을 캐시에서 제거
  void _evictCurrentImageFromCache({String? filePath, String? downloadUrl}) {
    if (filePath != null && filePath.isNotEmpty) {
      // 로컬 파일 이미지 캐시만 제거
      PaintingBinding.instance.imageCache.evict(FileImage(File(filePath)));
    }
    if (downloadUrl != null && downloadUrl.isNotEmpty) {
      // 네트워크 이미지 캐시만 제거
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
    // [VideoCompress] 진행 중인 압축 정리
    if (!kIsWeb) {
      VideoCompress.cancelCompression();
      VideoCompress.dispose();
    }

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
    _categoryFocusNode.removeListener(_onCategoryFocusChange);
    _categoryFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (_draggableScrollController.isAttached) {
      _draggableScrollController.jumpTo(0.0);
    }
    _draggableScrollController.dispose();
    super.dispose();
  }
}
