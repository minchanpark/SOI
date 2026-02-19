part of 'photo_editor_screen.dart';

/// UI 빌드 및 사용자 인터랙션 처리 관련 로직을 모아둔 extension
/// 캡션 입력, 카테고리 선택, 텍스트 전용 미리보기, 에디터 스캐폴드 빌드 등
/// 화면 구성과 관련된 모든 로직을 담당
extension _PhotoEditorScreenViewExtension on _PhotoEditorScreenState {
  void _handleMicTap() {
    _safeSetState(() => _showAudioRecorder = true);
    _captionFocusNode.unfocus();
  }

  /// 캡션 입력창과 오디오 녹음 UI를 전환하는 AnimatedSwitcher 위젯
  Widget _buildCaptionInputBar() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: _showAudioRecorder
          ?
            // 오디오 녹음 UI
            Padding(
              key: const ValueKey('audio_recorder'),
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: AudioRecorderWidget(
                audioController: _audioController,
                autoStart: true,
                onRecordingFinished: (audioFilePath, waveformData, duration) {
                  _safeSetState(() {
                    _recordedAudioPath = audioFilePath;
                    _recordedWaveformData = waveformData;
                    _recordedAudioDurationSeconds = duration.inSeconds;
                  });
                },
                onRecordingCleared: () {
                  _safeSetState(() {
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
          :
            // 캡션 입력 UI
            FocusScope(
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
      final user = _userController.currentUser;
      if (user == null) {
        _showErrorSnackBar(
          tr('common.login_required_relogin', context: context),
        );
        return;
      }

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
    } catch (_) {
      _showErrorSnackBar(
        tr('camera.editor.category_create_error', context: context),
      );
    }
  }

  /// 텍스트 전용 미리보기 위젯
  Widget _buildTextOnlyPreviewWidget() {
    return Container(
      width: 354.w,
      height: 500.h,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: const Color(0xff2b2b2b), width: 2.0),
      ),
      child: SingleChildScrollView(
        child: Text(
          _textOnlyContent,
          style: TextStyle(
            color: Colors.white,
            fontSize: 17.sp,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  /// 에디터 화면의 기본 Scaffold 위젯을 빌드하는 메서드
  /// 로딩 상태, 에러 메시지, 미디어 프리뷰, 캡션 입력창 등을 포함하여 화면 전체 구성을 담당
  ///
  /// PhotoEditorScreenState에서 호출되며,
  /// 화면의 주요 UI 요소들을 배치하고 사용자 인터랙션을 처리하는 중심 역할을 합니다.
  Widget _buildEditorScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SOI',
              style: TextStyle(
                color: const Color(0xfff9f9f9),
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
                Positioned.fill(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isTextOnlyMode)
                          _buildTextOnlyPreviewWidget()
                        else
                          PhotoDisplayWidget(
                            filePath: _currentFilePath,
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
                if (!_isTextOnlyMode)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: isKeyboardVisible
                        ? 10.h
                        : MediaQuery.of(context).size.height *
                              _PhotoEditorScreenState._kLockedSheetExtent,
                    child: SizedBox(child: _buildCaptionInputBar()),
                  ),
              ],
            ),
      bottomSheet: shouldHideBottomSheet
          ? null
          : NotificationListener<DraggableScrollableNotification>(
              onNotification: (notification) {
                if (_isAnimatingSheet) {
                  return true;
                }

                if (_selectedCategoryIds.isNotEmpty) {
                  if (notification.extent <
                      _PhotoEditorScreenState._kLockedSheetExtent - 0.02) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted &&
                          !_isDisposing &&
                          !_isAnimatingSheet &&
                          _draggableScrollController.isAttached) {
                        _draggableScrollController.jumpTo(
                          _PhotoEditorScreenState._kLockedSheetExtent,
                        );
                      }
                    });
                  }
                  return true;
                }

                if (!_hasLockedSheetExtent && notification.extent < 0.01) {
                  if (mounted && !_isDisposing && !_hasLockedSheetExtent) {
                    _animateSheetTo(
                      _PhotoEditorScreenState._kLockedSheetExtent,
                      lockExtent: true,
                    );
                  }
                }
                return true;
              },
              child: DraggableScrollableSheet(
                controller: _draggableScrollController,
                initialChildSize: _initialChildSize,
                minChildSize: _minChildSize,
                maxChildSize: _PhotoEditorScreenState._kMaxSheetExtent,
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
                        decoration: const BoxDecoration(
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
                                    ? const SizedBox()
                                    : Center(
                                        child: Container(
                                          height: 3.h,
                                          width: 56.w,
                                          margin: EdgeInsets.symmetric(
                                            vertical: 11.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xffcdcdcd),
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
                                  duration: const Duration(milliseconds: 300),
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
                                                    _safeSetState(() {
                                                      _showAddCategoryUI =
                                                          false;
                                                      _categoryNameController
                                                          .clear();
                                                    });
                                                    _animateSheetTo(
                                                      _PhotoEditorScreenState
                                                          ._kLockedSheetExtent,
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
                                              _uploadThenNavigate(
                                                _selectedCategoryIds,
                                              );
                                            }
                                          },
                                          addCategoryPressed: () {
                                            _safeSetState(
                                              () => _showAddCategoryUI = true,
                                            );
                                            _animateSheetTo((0.3).sp);
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
}
