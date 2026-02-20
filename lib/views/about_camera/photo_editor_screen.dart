import 'dart:async';
//import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_compress/video_compress.dart';
import '../../api/controller/audio_controller.dart';
import '../../api/controller/category_controller.dart' as api_category;
import '../../api/controller/media_controller.dart' as api_media;
import '../../api/models/models.dart';
import '../../api/controller/post_controller.dart';
import '../../api/controller/user_controller.dart';
import '../../api/services/media_service.dart';
import '../home_navigator_screen.dart';
import 'add_category_screen.dart';
import 'models/add_category_draft.dart';
import 'widgets/about_photo_editor_screen/audio_recorder_widget.dart';
import 'widgets/about_photo_editor_screen/caption_input_widget.dart';
import 'widgets/about_photo_editor_screen/category_list_widget.dart';
import 'widgets/about_photo_editor_screen/photo_display_widget.dart';
import 'models/photo_editor_upload_models.dart';
import 'services/photo_editor_media_processing_service.dart';

part 'photo_editor_screen_upload.dart';
part 'photo_editor_screen_view.dart';

/// 사진/비디오 편집 및 업로드 화면
/// - 카테고리 선택, 캡션 입력, 오디오 녹음 등 업로드 전 최종 편집 기능 담당
/// - 실제 업로드 실행과 업로드 후 정리 등은 photo_editor_screen_upload.dart에 분리
/// - UI 구성과 사용자 상호작용 처리 등은 photo_editor_screen_view.dart에 분리
/// - 미디어 처리(압축, 파형 인코딩 등)는 services/photo_editor_media_processing_service.dart에 분리
/// - 업로드 준비, 업로드 실행, 업로드 후 정리 등은 담당하지 않습니다.
///
/// Parameters:
/// - [downloadUrl]: 편집할 미디어의 다운로드 URL (네트워크 이미지인 경우 사용)
/// - [filePath]: 편집할 미디어의 로컬 파일 경로 (카메라 촬영 또는 갤러리 선택 시 사용)
/// - [asset]: 편집할 미디어의 AssetEntity (갤러리 선택 시 사용, filePath보다 우선)
/// - [inputText]: 텍스트 전용 편집 모드에서 편집할 텍스트 내용 (텍스트 전용 모드에서만 사용)
/// - [isVideo]: 편집할 미디어가 비디오인지 여부 (true: 비디오, false: 이미지, null인 경우 downloadUrl이나 filePath로 판단)
/// - [initialImage]: 즉시 미리보기를 위해 사용할 ImageProvider (선택적, 제공된 경우 downloadUrl이나 filePath보다 우선)
/// - [isFromCamera]: 카메라에서 직접 촬영된 미디어인지 여부 (true: 촬영됨, false: 갤러리에서 선택됨, 기본값은 true)
class PhotoEditorScreen extends StatefulWidget {
  final String? downloadUrl;
  final String? filePath;
  final AssetEntity? asset;
  final String? inputText;

  // 미디어가 비디오인지 여부를 체크하는 플래그
  final bool? isVideo;
  final ImageProvider? initialImage;

  // 카메라에서 직접 촬영된 미디어인지 여부 (true: 촬영됨, false: 갤러리에서 선택됨)
  final bool isFromCamera;

  const PhotoEditorScreen({
    super.key,
    this.downloadUrl,
    this.filePath,
    this.asset,
    this.inputText,
    this.isVideo,
    this.initialImage,
    this.isFromCamera = true, // 기본값은 촬영된 것으로 설정
  });
  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _showImmediatePreview = false;
  String? _errorMessageKey;
  Map<String, String>? _errorMessageArgs;
  bool _useLocalImage = false;
  ImageProvider? _initialImageProvider;
  final List<int> _selectedCategoryIds = [];
  bool _categoriesLoaded = false;
  bool _shouldAutoOpenCategorySheet = true;
  bool _isDisposing = false;
  bool _uploadStarted = false;
  String? _resolvedFilePath;
  bool _isResolvingAsset = false;

  // ========== 바텀시트 크기 상수 ==========
  static const double _kInitialSheetExtent = 0.0;
  static const double _kLockedSheetExtent = 0.19; // 잠금된 바텀시트 높이
  static const double _kExpandedSheetExtent = 0.31; // 확장된 바텀시트 높이
  static const double _kMaxSheetExtent = 0.8; // 최대 바텀시트 높이

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
  bool get shouldHideBottomSheet => isKeyboardVisible;

  final _draggableScrollController = DraggableScrollableController();
  final TextEditingController _captionController = TextEditingController();
  late AudioController _audioController;
  late api_category.CategoryController _categoryController;
  late UserController _userController;
  late PostController _postController;
  late api_media.MediaController _mediaController;

  final PhotoEditorMediaProcessingService _mediaProcessingService =
      const PhotoEditorMediaProcessingService(); // 미디어 처리를 담당하는 서비스 클래스의 인스턴스를 생성합니다.

  final FocusNode _captionFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_isTextOnlyMode) {
      _captionController.text = _textOnlyContent;
      _isCaptionEmpty = _textOnlyContent.isEmpty;
    }
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

    // [디버깅] 기존 비디오 썸네일 캐시 초기화
    // 테스트를 위해 이전 캐시를 제거하고 새로 시작
    _mediaController.clearVideoThumbnailCache();
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

  void _initializeScreen() {
    if (_isTextOnlyMode) {
      _isLoading = false;
      _errorMessageKey = null;
      _errorMessageArgs = null;
      return;
    }

    if (widget.asset != null) {
      unawaited(_resolveAssetFileIfNeeded());
      return;
    }
    if (!_showImmediatePreview) _loadImage();
  }

  Future<void> _resolveAssetFileIfNeeded() async {
    if (widget.asset == null) return;
    if (_isResolvingAsset || _resolvedFilePath != null) return;

    _isResolvingAsset = true;
    try {
      final file = await widget.asset!.file;
      if (!mounted) return;

      if (file != null) {
        _resolvedFilePath = file.path;
      } else {
        _errorMessageKey = 'camera.editor.image_not_found';
        _errorMessageArgs = null;
      }
    } catch (e) {
      if (!mounted) return;
      _errorMessageKey = 'camera.editor.image_load_error_with_reason';
      _errorMessageArgs = {'error': e.toString()};
    } finally {
      _isResolvingAsset = false;
    }

    if (!mounted) return;
    if (!_showImmediatePreview) {
      await _loadImage();
    } else {
      setState(() {});
    }
  }

  void _primeImmediatePreview() {
    if (widget.initialImage != null) {
      _initialImageProvider = widget.initialImage;
      _showImmediatePreview = true;
      _useLocalImage = true;
      _isLoading = false;
      return;
    }

    final localPath = _currentFilePath;
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
        oldWidget.initialImage != widget.initialImage ||
        oldWidget.asset?.id != widget.asset?.id ||
        oldWidget.inputText != widget.inputText) {
      _categoriesLoaded = false;
      _resolvedFilePath = null;
      _isResolvingAsset = false;

      if (_isTextOnlyMode) {
        _captionController.text = _textOnlyContent;
        _isCaptionEmpty = _textOnlyContent.isEmpty;
        _showImmediatePreview = false;
        _useLocalImage = false;
        _isLoading = false;
        _errorMessageKey = null;
        _errorMessageArgs = null;
      } else {
        if (widget.initialImage != null) {
          _initialImageProvider = widget.initialImage;
          _showImmediatePreview = true;
          _useLocalImage = true;
          _isLoading = false;
        }
        if (widget.asset != null) {
          unawaited(_resolveAssetFileIfNeeded());
        }
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

    final localPath = _currentFilePath;
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

  Future<void> _openAddCategoryScreen() async {
    final draft = await Navigator.push<AddCategoryDraft>(
      context,
      MaterialPageRoute(builder: (context) => const AddCategoryScreen()),
    );

    if (draft == null || !mounted || _isDisposing) return;
    unawaited(_runAddCategoryInBackground(draft));
  }

  Future<void> _runAddCategoryInBackground(AddCategoryDraft draft) async {
    if (_isDisposing) return;
    _showErrorSnackBar(tr('common.please_wait', context: context));

    try {
      final isPublicCategory = draft.selectedFriends.isNotEmpty;
      final receiverIds = <int>[];
      if (isPublicCategory) {
        receiverIds.add(draft.requesterId);
        for (final friend in draft.selectedFriends) {
          final parsedId = int.tryParse(friend.uid);
          if (parsedId != null && !receiverIds.contains(parsedId)) {
            receiverIds.add(parsedId);
          }
        }
      }

      final createCategoryFuture = _categoryController.createCategory(
        requesterId: draft.requesterId,
        name: draft.categoryName,
        receiverIds: receiverIds,
        isPublic: isPublicCategory,
      );

      final selectedCover = draft.selectedCoverImageFile;
      final Future<_BackgroundCoverUploadResult> uploadFuture =
          selectedCover == null
          ? Future.value(const _BackgroundCoverUploadResult())
          : _uploadCategoryCoverImageInBackground(
                  imageFile: selectedCover,
                  userId: draft.requesterId,
                  refId: draft.requesterId,
                )
                .then((keys) => _BackgroundCoverUploadResult(keys: keys))
                .catchError((_) => const _BackgroundCoverUploadResult());

      final parallelResults = await Future.wait<dynamic>([
        createCategoryFuture,
        uploadFuture,
      ]);

      final createdCategoryId = parallelResults[0] as int?;
      final uploadResult = parallelResults[1] as _BackgroundCoverUploadResult;

      if (createdCategoryId == null) {
        if (!mounted) return;
        final message =
            _categoryController.errorMessage ??
            tr('camera.editor.category_create_failed_retry', context: context);
        _showErrorSnackBar(message);
        return;
      }

      var shouldWarnCoverUpdateFailure = false;

      if (selectedCover != null) {
        var profileImageKey = uploadResult.firstKey;

        // create 결과(categoryId)가 필요하므로 updateCustomProfile은 병렬 처리할 수 없습니다.
        // 업로드 결과가 비어 있으면 categoryId 기준으로 1회 재시도합니다.
        if (profileImageKey == null) {
          final retryKeys = await _uploadCategoryCoverImageInBackground(
            imageFile: selectedCover,
            userId: draft.requesterId,
            refId: createdCategoryId,
          );
          if (retryKeys.isNotEmpty) {
            profileImageKey = retryKeys.first;
          }
        }

        if (profileImageKey != null) {
          final profileUpdated = await _categoryController.updateCustomProfile(
            categoryId: createdCategoryId,
            userId: draft.requesterId,
            profileImageKey: profileImageKey,
          );
          if (!profileUpdated) {
            shouldWarnCoverUpdateFailure = true;
          }
        } else {
          shouldWarnCoverUpdateFailure = true;
        }
      }

      try {
        await _categoryController.loadCategories(
          draft.requesterId,
          forceReload: true,
          fetchAllPages: true,
          maxPages: 2,
        );
        _categoriesLoaded = true;
        if (mounted) setState(() {});
      } catch (_) {
        // 생성 자체는 성공했으므로 로드 실패는 종료를 막지 않습니다.
      }

      if (!mounted) return;

      if (shouldWarnCoverUpdateFailure) {
        final warningMessage =
            _categoryController.errorMessage ??
            tr('category.cover.update_failed', context: context);
        _showErrorSnackBar(warningMessage);
      } else {
        _showErrorSnackBar(
          tr('archive.create_category_success', context: context),
        );
      }
    } catch (_) {
      if (!mounted) return;
      _showErrorSnackBar(
        tr('camera.editor.category_create_error', context: context),
      );
    }
  }

  Future<List<String>> _uploadCategoryCoverImageInBackground({
    required File imageFile,
    required int userId,
    required int refId,
  }) async {
    final multipart = await _mediaController.fileToMultipart(imageFile);
    return _mediaController.uploadMedia(
      files: [multipart],
      types: [MediaType.image],
      usageTypes: [MediaUsageType.categoryProfile],
      userId: userId,
      refId: refId,
      usageCount: 1,
    );
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

  // 실제 UI는 _buildEditorScaffold에서 구성
  // build 메서드는 단순히 스캐폴드 빌더를 호출하는 역할로 유지하여 가독성 향상
  // _buildEditorScaffold는 PhotoEditorScreenView에 정의되어 있습니다.
  @override
  Widget build(BuildContext context) => _buildEditorScaffold(context);

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
      filePath: _currentFilePath,
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

    _captionController.removeListener(_handleCaptionChanged);
    _captionController.dispose();
    _captionFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (_draggableScrollController.isAttached) {
      _draggableScrollController.jumpTo(0.0);
    }
    _draggableScrollController.dispose();
    super.dispose();
  }
}

class _BackgroundCoverUploadResult {
  final List<String> keys;

  const _BackgroundCoverUploadResult({this.keys = const []});

  String? get firstKey => keys.isNotEmpty ? keys.first : null;
}
