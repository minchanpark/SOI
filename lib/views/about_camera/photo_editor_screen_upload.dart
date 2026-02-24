part of 'photo_editor_screen.dart';

/// 업로드 준비 및 실행 관련 로직을 모아둔 extension
/// 업로드 직전에 필요한 데이터 준비, 실제 업로드 실행, 업로드 후 정리 작업 등을 담당
extension _PhotoEditorScreenUploadExtension on _PhotoEditorScreenState {
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

  Future<void> _deleteTemporaryFilesInBackground(UploadPayload payload) async {
    await _deleteTemporaryFile(payload.mediaFile, payload.mediaPath);
    if (payload.audioFile != null && payload.audioPath != null) {
      await _deleteTemporaryFile(payload.audioFile!, payload.audioPath!);
    }
  }

  String? get _currentFilePath => _resolvedFilePath ?? widget.filePath;

  bool get _isTextOnlyMode {
    final text = widget.inputText?.trim();
    return text != null &&
        text.isNotEmpty &&
        widget.filePath == null &&
        widget.asset == null &&
        widget.downloadUrl == null;
  }

  String get _textOnlyContent => widget.inputText?.trim() ?? '';

  Future<void> _uploadThenNavigate(List<int> categoryIds) async {
    if (_uploadStarted) return;

    _uploadStarted = true;

    try {
      final currentUser = _userController.currentUser;
      if (currentUser == null) {
        _showErrorSnackBar(tr('common.login_required_retry', context: context));
        _uploadStarted = false;
        return;
      }

      if (_isTextOnlyMode) {
        final inputText = _textOnlyContent;
        if (inputText.isEmpty) {
          _showErrorSnackBar(tr('camera.text_input_hint', context: context));
          _uploadStarted = false;
          return;
        }
        if (categoryIds.isEmpty) {
          _uploadStarted = false;
          return;
        }

        _navigateToHome();
        SchedulerBinding.instance.addPostFrameCallback((_) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            unawaited(
              _runTextOnlyUploadAfterNavigation(
                userId: currentUser.id,
                nickName: currentUser.userId,
                categoryIds: List<int>.from(categoryIds),
                inputText: inputText,
              ),
            );
          });
        });
        return;
      }

      final filePath = _currentFilePath;
      if (filePath == null || filePath.isEmpty) {
        _safeSetState(() {
          _errorMessageKey = 'camera.editor.upload_file_not_found';
          _errorMessageArgs = null;
        });
        _uploadStarted = false;
        return;
      }

      final snapshot = UploadSnapshot(
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

      _navigateToHome();
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

  /// 텍스트 전용 게시물 업로드(미디어 파일 없이 텍스트만 있는 경우)
  /// 홈으로 먼저 이동한 후 업로드를 실행하여, 업로드 중에도 홈 화면에서 다른 작업을 할 수 있도록 함
  Future<void> _runTextOnlyUploadAfterNavigation({
    required int userId,
    required String nickName,
    required List<int> categoryIds,
    required String inputText,
  }) async {
    try {
      final success = await _postController.createPost(
        userId: userId,
        nickName: nickName,
        content: inputText,
        categoryIds: categoryIds,
        postFileKey: TextOnlyPostCreateDefaults.postFileKey,
        audioFileKey: TextOnlyPostCreateDefaults.audioFileKey,
        waveformData: TextOnlyPostCreateDefaults.waveformData,
        duration: TextOnlyPostCreateDefaults.duration,
        savedAspectRatio: TextOnlyPostCreateDefaults.savedAspectRatio,
        isFromGallery: TextOnlyPostCreateDefaults.isFromGallery,
        postType: PostType.textOnly,
      );

      if (!success) {
        throw Exception('텍스트 게시물 생성에 실패했습니다.');
      }

      try {
        await _categoryController.loadCategories(userId, forceReload: true);
      } catch (e) {
        debugPrint('[PhotoEditor] text-only categories refresh failed: $e');
      }
    } catch (e) {
      debugPrint('[PhotoEditor] 텍스트 게시물 업로드 실패: $e');
    } finally {
      _uploadStarted = false;
    }
  }

  Future<void> _runUploadPipelineAfterNavigation(
    UploadSnapshot snapshot,
  ) async {
    try {
      unawaited(_audioController.stopRealtimeAudio());
      _audioController.clearCurrentRecording();
      _evictCurrentImageFromCache(filePath: snapshot.filePath);

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

  Future<void> _uploadPostInBackground({
    required List<int> categoryIds,
    required UploadPayload payload,
  }) async {
    try {
      final mediaResult = await _uploadMediaForPost(payload: payload);
      if (mediaResult == null) {
        throw Exception('미디어 업로드에 실패했습니다.');
      }

      final createPostFuture = _createPostWithMedia(
        categoryIds: categoryIds,
        payload: payload,
        mediaResult: mediaResult,
      );

      Future<List<String>?>? updateCategoryCoverFuture;
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
      if (!createSuccess) {
        throw Exception('게시물 생성에 실패했습니다.');
      }

      if (payload.isVideo && results.length > 1) {
        final thumbnailKeys = results[1] as List<String>?;
        if (thumbnailKeys != null && thumbnailKeys.isNotEmpty) {
          final videoS3Key = mediaResult.mediaKeys.isNotEmpty
              ? mediaResult.mediaKeys[0]
              : null;
          if (videoS3Key != null) {
            _mediaController.cacheThumbnailForVideo(
              videoS3Key,
              thumbnailKeys[0],
            );
          } else {
            throw Exception('비디오 S3 키가 없어 캐싱 불가');
          }
        } else {
          throw Exception('카테고리 대표 이미지 업데이트에 실패했습니다.');
        }
      }

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
      throw Exception('[PhotoEditor] 백그라운드 업로드 실패: $e');
    } finally {
      if (!kIsWeb) {
        unawaited(VideoCompress.deleteAllCache());
      }
    }
  }

  Future<UploadPayload?> _prepareUploadPayloadFromSnapshot(
    UploadSnapshot snapshot,
  ) async {
    final filePath = snapshot.filePath;
    var mediaFile = File(filePath);
    if (!await mediaFile.exists()) {
      throw Exception('미디어 파일을 찾을 수 없습니다.');
    }

    if (snapshot.isVideo) {
      try {
        mediaFile = await _mediaProcessingService.compressVideoIfNeeded(
          mediaFile,
        );
      } catch (e) {
        debugPrint('[PhotoEditor] 비디오 압축 실패(원본 사용): $e');
      }
    } else {
      try {
        if (snapshot.compressedFile != null &&
            snapshot.lastCompressedPath == filePath) {
          mediaFile = snapshot.compressedFile!;
        } else if (snapshot.compressionTask != null &&
            snapshot.lastCompressedPath == filePath) {
          mediaFile = await snapshot.compressionTask!;
        } else {
          mediaFile = await _mediaProcessingService.compressImageIfNeeded(
            mediaFile,
          );
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
    final waveform = shouldIncludeAudio ? snapshot.recordedWaveformData : null;

    double? aspectRatio;
    if (!snapshot.isVideo) {
      aspectRatio = await _mediaProcessingService.calculateImageAspectRatio(
        mediaFile,
      );
    }

    return UploadPayload(
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
      aspectRatio: aspectRatio,
      isFromGallery: !widget.isFromCamera,
    );
  }

  Future<MediaUploadResult?> _uploadMediaForPost({
    required UploadPayload payload,
  }) async {
    final files = <http.MultipartFile>[];
    final types = <MediaType>[];
    final usageTypes = <MediaUsageType>[];

    final mediaMultipart = await _mediaController.fileToMultipart(
      payload.mediaFile,
    );
    files.add(mediaMultipart);
    types.add(payload.isVideo ? MediaType.video : MediaType.image);
    usageTypes.add(MediaUsageType.post);

    if (payload.audioFile != null) {
      final audioMultipart = await _mediaController.fileToMultipart(
        payload.audioFile!,
      );
      files.add(audioMultipart);
      types.add(MediaType.audio);
      usageTypes.add(MediaUsageType.post);
    }

    final keys = await _mediaController.uploadMedia(
      files: files,
      types: types,
      usageTypes: usageTypes,
      userId: payload.userId,
      refId: payload.userId,
      usageCount: payload.usageCount,
    );

    if (keys.isEmpty) return null;

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

    return MediaUploadResult(mediaKeys: mediaKeys, audioKeys: audioKeys);
  }

  void _navigateToHome() {
    if (!mounted || _isDisposing) return;

    _audioController.stopRealtimeAudio();
    _audioController.clearCurrentRecording();

    HomePageNavigationBar.requestTab(0);

    final navigator = Navigator.of(context);
    var foundHome = false;
    navigator.popUntil((route) {
      final isHome = route.settings.name == '/home_navigation_screen';
      foundHome = foundHome || isHome;
      return isHome || route.isFirst;
    });

    if (!foundHome && mounted) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomePageNavigationBar(
            key: HomePageNavigationBar.rootKey,
            currentPageIndex: 0,
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

  Future<bool> _createPostWithMedia({
    required List<int> categoryIds,
    required UploadPayload payload,
    required MediaUploadResult mediaResult,
  }) async {
    final waveformJson = await _mediaProcessingService.encodeWaveformDataAsync(
      payload.waveformData,
    );

    if (kDebugMode) {
      debugPrint(
        "[PhotoEditor] userId: ${payload.userId}\nnickName: ${payload.nickName}\ncontent: ${payload.caption}\npostFileKey: ${mediaResult.mediaKeys}\naudioFileKey: ${mediaResult.audioKeys}\ncategoryIds: $categoryIds\nwaveformData: $waveformJson\nduration: ${payload.audioDurationSeconds}\naspectRatio: ${payload.aspectRatio}\nisFromGallery: ${payload.isFromGallery}",
      );
    }

    final success = await _postController.createPost(
      userId: payload.userId,
      nickName: payload.nickName,
      content: payload.caption,
      postFileKey: mediaResult.mediaKeys,
      audioFileKey: mediaResult.audioKeys,
      categoryIds: categoryIds,
      waveformData: waveformJson,
      duration: payload.audioDurationSeconds,
      savedAspectRatio: payload.aspectRatio,
      isFromGallery: payload.isFromGallery,
      postType: PostType.multiMedia,
    );

    if (kDebugMode) debugPrint('[PhotoEditor] 게시물 생성 결과: $success');
    return success;
  }

  Future<List<String>?> _updateCategoryCoverFromVideo({
    required List<int> categoryIds,
    required UploadPayload payload,
  }) async {
    if (!payload.isVideo || categoryIds.isEmpty) return null;

    final categoriesToUpdate = <int>[];
    for (final categoryId in categoryIds) {
      final category = _categoryController.getCategoryById(categoryId);
      if (category != null &&
          (category.photoUrl == null || category.photoUrl!.isEmpty)) {
        categoriesToUpdate.add(categoryId);
      }
    }

    if (categoriesToUpdate.isEmpty) {
      debugPrint('[PhotoEditor] 모든 카테고리에 이미 대표사진이 설정되어 있어 스킵');
      return null;
    }

    File? thumbnailFile;
    try {
      thumbnailFile = await _mediaProcessingService.extractVideoThumbnailFile(
        payload.mediaPath,
      );
      if (thumbnailFile == null) {
        debugPrint('[PhotoEditor] 비디오 썸네일 생성 실패');
        return null;
      }

      final multipart = await _mediaController.fileToMultipart(thumbnailFile);
      final usageCount = categoriesToUpdate.length;

      final keys = await _mediaController.uploadMedia(
        files: [multipart],
        types: [MediaType.image],
        usageTypes: [MediaUsageType.categoryProfile],
        userId: payload.userId,
        refId: categoriesToUpdate.first,
        usageCount: usageCount,
      );

      if (keys.length < usageCount) {
        debugPrint('[PhotoEditor] 카테고리 썸네일 키 수가 부족합니다. keys: $keys');
        return null;
      }

      final results = await Future.wait([
        for (var i = 0; i < usageCount; i++)
          _categoryController.updateCustomProfile(
            categoryId: categoriesToUpdate[i],
            userId: payload.userId,
            profileImageKey: keys[i],
          ),
      ]);

      final allSuccess = results.every((value) => value == true);
      if (!allSuccess) {
        debugPrint('[PhotoEditor] 일부 카테고리 대표 이미지 업데이트 실패');
      }

      return keys;
    } catch (e) {
      debugPrint('[PhotoEditor] 비디오 썸네일 업로드/카테고리 업데이트 실패: $e');
      return null;
    } finally {
      if (thumbnailFile != null) {
        try {
          await thumbnailFile.delete();
        } catch (_) {}
      }
    }
  }

  void _startPreCompressionIfNeeded() {
    if (widget.isVideo == true) return;

    final filePath = _currentFilePath;
    if (filePath == null || filePath.isEmpty) return;
    if (_lastCompressedPath == filePath && _compressionTask != null) return;

    _lastCompressedPath = filePath;
    _compressionTask = _mediaProcessingService
        .compressImageIfNeeded(File(filePath))
        .then((compressed) {
          _compressedFile = compressed;
          return compressed;
        })
        .catchError((error) {
          debugPrint('백그라운드 압축 실패: $error');
          _compressedFile = File(filePath);
          return File(filePath);
        });
  }
}
