import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../api/controller/audio_controller.dart';
import '../../../api/controller/media_controller.dart';
import '../../../api/controller/user_controller.dart';
import '../../about_archiving/widgets/wave_form_widget/custom_waveform_widget.dart';
import '../api_photo/tag_pointer.dart';

part 'extension/voice_comment_widget_recording.dart';
part 'extension/voice_comment_widget_playback.dart';
part 'extension/voice_comment_widget_profile_drag.dart';
part 'extension/voice_comment_widget_placement.dart';

enum VoiceCommentState {
  idle, // 초기 상태 (녹음 버튼 표시)
  recording, // 녹음 중
  recorded, // 녹음 완료 (재생 가능)
  placing, // 프로필 배치 중 (드래그 가능)
  saved, // 저장 완료 (프로필 이미지 표시)
}

/// 음성 댓글 위젯
/// - 음성 댓글 녹음, 재생, 삭제, 프로필 배치 등 모든 관련 UI와 로직을 포함하는 통합 위젯
class VoiceCommentWidget extends StatefulWidget {
  final bool autoStart; // 자동 녹음 시작 여부
  final Function(String?, List<double>?, int?)?
  onRecordingCompleted; // 녹음 완료 콜백 (duration 추가)
  final VoidCallback? onRecordingDeleted; // 녹음 삭제 콜백
  final VoidCallback? onSaved; // 저장 완료 콜백 추가
  final Future<void> Function()? onSaveRequested; // 저장 요청 콜백 (파형 배치 확정 시)
  final VoidCallback? onSaveCompleted; // 저장 완료 후 위젯 초기화 콜백
  final String? profileImageUrl; // 프로필 이미지 URL 추가
  final bool startAsSaved; // 저장된 상태로 시작할지 여부
  final bool startInPlacingMode; // placing 모드로 시작할지 여부 (텍스트 댓글용)
  final Function(Offset)? onProfileImageDragged; // 프로필 이미지 드래그 콜백
  final bool enableMultipleComments; // 여러 댓글 지원 여부
  final bool hasExistingComments; // 기존 댓글 존재 여부

  const VoiceCommentWidget({
    super.key,
    this.autoStart = false,
    this.onRecordingCompleted,
    this.onRecordingDeleted,
    this.onSaved,
    this.onSaveRequested, // 저장 요청 콜백 추가
    this.onSaveCompleted, // 저장 완료 후 위젯 초기화 콜백 추가
    this.profileImageUrl, // 프로필 이미지 URL 추가
    this.startAsSaved = false, // 기본값은 false
    this.startInPlacingMode = false, // 기본값은 false
    this.onProfileImageDragged, // 드래그 콜백 추가
    this.enableMultipleComments = false, // 여러 댓글 지원 기본값 false
    this.hasExistingComments = false, // 기존 댓글 존재 기본값 false
  });

  @override
  State<VoiceCommentWidget> createState() => _VoiceCommentWidgetState();
}

class _VoiceCommentWidgetState extends State<VoiceCommentWidget> {
  // ============================================================
  // 상태 관리를 위한 변수들
  // ============================================================
  late AudioController _audioController;
  late RecorderController _recorderController;
  PlayerController? _playerController;

  VoiceCommentState _currentState = VoiceCommentState.idle;
  List<double>? _waveformData;

  // 녹음 시작 시간 추가
  DateTime? _recordingStartTime;

  // 부모 스크롤을 잠그기 위한 컨트롤러
  ScrollHoldController? _scrollHoldController;

  bool _isFinalizingPlacement = false; // 중복 저장 방지
  final GlobalKey _profileDraggableKey = GlobalKey();
  static const double _defaultAvatarSize = 54.0;
  static const double _placementAvatarSize = 27.0;

  /// 이전 녹음 상태 (애니메이션 제어용)
  VoiceCommentState? _lastState;
  final Map<String, Future<String?>> _profileUrlFutures = {};
  bool _isTextCommentPlacement = false; // 텍스트 댓글 배치 여부

  // ============================================================
  // 여러 가지 생명주기 관련 메서드
  // ============================================================

  @override
  void initState() {
    super.initState();

    // 저장된 상태로 시작해야 하는 경우
    if (widget.startAsSaved) {
      _currentState = VoiceCommentState.saved;
      return;
    }

    // Placing 모드로 시작해야 하는 경우 (텍스트 댓글용)
    if (widget.startInPlacingMode) {
      _isTextCommentPlacement = true;
      _currentState = VoiceCommentState.placing;
      _initializeControllers(); // 컨트롤러 초기화 (dispose에서 필요)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentState == VoiceCommentState.placing) {
          _holdParentScroll();
        }
      });
      return;
    }

    /// 컨트롤러 초기화
    /// 컨트롤러를 이 위치에서 초기화하는 이유:
    /// 1. 위젯이 생성될 때 컨트롤러가 즉시 사용 가능하도록 보장하기 위해.
    /// 2. 상태 관리 및 리소스 해제를 위젯의 생명 주기에 맞추기 위해.
    _initializeControllers();

    // autoStart는 saved/placing 상태가 아닐 때만 적용
    if (widget.autoStart && _currentState != VoiceCommentState.saved) {
      _currentState = VoiceCommentState.recording;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startRecording();
      });
    }
  }

  @override
  void dispose() {
    _releaseParentScroll();
    // 저장된 상태가 아닌 경우에만 컨트롤러 해제
    if (_currentState != VoiceCommentState.saved) {
      _recorderController.dispose();
      _playerController?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // recording→recorded 또는 배치 상태 전환에서는 애니메이션 비활성화
    final bool skipAnimation =
        (_lastState == VoiceCommentState.recording &&
            _currentState == VoiceCommentState.recorded) ||
        _currentState == VoiceCommentState.placing ||
        _lastState == VoiceCommentState.placing;

    if (skipAnimation) {
      // 필요한 전환은 애니메이션 없이 즉시 처리
      return _buildCurrentStateWidget();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: _buildCurrentStateWidget(),
    );
  }

  /// 현재 상태에 맞는 위젯을 반환
  /// idle/recording/recorded/placing/saved 상태별로 적절한 UI를 생성
  Widget _buildCurrentStateWidget() {
    // recording에서 recorded로 전환할 때 같은 키를 사용하여 애니메이션 방지
    String widgetKey;
    if (_lastState == VoiceCommentState.recording &&
        _currentState == VoiceCommentState.recorded) {
      widgetKey = 'audio-ui-no-animation';
    } else if (_currentState == VoiceCommentState.placing) {
      widgetKey = 'profile-placement';
    } else if (_currentState == VoiceCommentState.saved) {
      widgetKey = 'profile-mode';
    } else {
      widgetKey = _currentState.toString();
    }

    switch (_currentState) {
      case VoiceCommentState.idle:
        // comment.png 표시 (기존 feed_home.dart에서 처리)
        return Container(
          key: ValueKey(widgetKey),
          height: 52.h, // 녹음 UI와 동일한 높이
          alignment: Alignment.center, // 중앙 정렬
          child: const SizedBox.shrink(),
        );

      case VoiceCommentState.recording:
        return Selector<AudioController, String>(
          key: ValueKey(widgetKey),
          selector: (context, controller) =>
              controller.formattedRecordingDuration,
          builder: (context, duration, child) {
            return _buildRecordingUI(duration);
          },
        );

      case VoiceCommentState.recorded:
        return Container(key: ValueKey(widgetKey), child: _buildPlaybackUI());

      // 배치 모드 UI
      // 프로필 드래그 앤 드롭을 위한 UI
      case VoiceCommentState.placing:
        return Container(
          key: ValueKey(widgetKey),
          child: _buildProfileDraggable(isPlacementMode: true),
        );

      // 저장된 상태 UI
      // 프로필 이미지 표시
      case VoiceCommentState.saved:
        return Container(
          key: ValueKey(widgetKey),
          child: _buildProfileDraggable(isPlacementMode: false),
        );
    }
  }

  /// 외부에서 저장 완료를 알리는 메서드
  /// 부모 위젯에서 저장이 완료되었음을 알릴 때 사용
  void markAsSaved() {
    if (mounted) {
      _markAsSaved();
    }
  }
}
