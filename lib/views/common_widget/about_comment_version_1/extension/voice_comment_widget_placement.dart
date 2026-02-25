// ignore_for_file: invalid_use_of_protected_member

part of '../voice_comment_widget.dart';

/// 음성 댓글 위젯의 프로필 배치 및 저장 관련 로직
/// - recorded 상태에서 placing 상태로 전환하는 진입점
/// - 프로필 드래그 시 부모 스크롤 잠금/해제
/// - 배치 완료 시 저장 요청 및 상태 전환
extension _VoiceCommentWidgetPlacementExtension on _VoiceCommentWidgetState {
  /// recorded 상태에서 placing 상태로 전환
  /// 파형 위의 프로필 이미지를 드래그할 때 호출
  void _beginPlacementFromWaveform() {
    if (_waveformData == null || _waveformData!.isEmpty) {
      return;
    }
    if (_currentState == VoiceCommentState.placing) {
      return;
    }

    _holdParentScroll();
    setState(() {
      _lastState = _currentState;
      _currentState = VoiceCommentState.placing;
    });
  }

  /// 프로필 배치 완료 및 saved 상태로 전환
  /// onSaveRequested 콜백을 호출하여 Firebase에 저장
  Future<void> _finalizePlacement() async {
    if (_isFinalizingPlacement) {
      return;
    }

    _releaseParentScroll();
    _isFinalizingPlacement = true;

    // 저장이 끝나기 전에 UI에서 미리 프로필을 표시
    if (_currentState != VoiceCommentState.saved) {
      setState(() {
        _lastState = _currentState;
        _currentState = VoiceCommentState.saved;
      });
    }

    try {
      if (widget.onSaveRequested != null) {
        await widget.onSaveRequested!.call();
      }

      if (!mounted) {
        return;
      }

      _markAsSaved();
      widget.onSaveCompleted?.call();
    } catch (e) {
      if (mounted) {
        // 저장 실패 시 다시 파형 모드로 복귀
        setState(() {
          _lastState = _currentState;
          _currentState = VoiceCommentState.recorded;
        });
      }
    } finally {
      _isFinalizingPlacement = false;
    }
  }

  /// 프로필 배치 취소 및 recorded 상태로 복귀
  /// 드래그를 취소하거나 유효하지 않은 위치에 드롭했을 때 호출
  void _cancelPlacement() {
    if (!mounted || _currentState != VoiceCommentState.placing) {
      return;
    }

    _releaseParentScroll();

    if (_isTextCommentPlacement) {
      return;
    }

    setState(() {
      _lastState = _currentState;
      _currentState = VoiceCommentState.recorded;
    });
  }

  /// saved 상태로 변경하고 컨트롤러 정리
  /// 내부에서 호출되는 상태 변경 메서드
  void _markAsSaved() {
    _releaseParentScroll();
    // 애니메이션을 위해 _lastState 설정
    setState(() {
      _lastState = _currentState;
      _currentState = VoiceCommentState.saved;
      _isTextCommentPlacement = false;
    });

    // 상태 변경 후 컨트롤러들을 정리 (애니메이션 후에)
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _cleanupControllers();
        setState(() {
          // 파형 데이터 정리
          _waveformData = null;
        });
      }
    });

    // 저장 완료 콜백 호출
    widget.onSaved?.call();
  }

  /// RecorderController와 PlayerController 정리
  /// saved 상태로 전환 후 리소스 해제
  void _cleanupControllers() {
    try {
      // 재생 중이면 중지
      if (_playerController?.playerState.isPlaying == true) {
        _playerController?.stopPlayer();
      }

      // 녹음 중이면 중지
      if (_recorderController.isRecording) {
        _recorderController.stop();
      }

      // 컨트롤러들 해제
      _playerController?.dispose();
      _playerController = null;
    } catch (e) {
      debugPrint('컨트롤러 정리 중 오류: $e');
    }
  }

  /// 부모 스크롤을 잠금
  /// placing 상태에서 프로필 드래그 중 스크롤 방지
  void _holdParentScroll() {
    if (_scrollHoldController != null) {
      return;
    }
    final scrollable = Scrollable.maybeOf(context);
    final position = scrollable?.position;
    if (position == null) {
      return;
    }
    _scrollHoldController = position.hold(() => _scrollHoldController = null);
  }

  /// 부모 스크롤 잠금 해제
  /// placing 상태 종료 시 스크롤 복원
  void _releaseParentScroll() {
    _scrollHoldController?.cancel();
    _scrollHoldController = null;
  }
}
