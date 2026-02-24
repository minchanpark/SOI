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

  // ============================================================
  /// 녹음 흐름 메서드
  /// 녹음을 시작하고 상태를 recording으로 전환
  Future<void> startRecording() async {
    try {
      _recordingStartTime = DateTime.now();
      await _recorderController.record();
      await _audioController.startRecording();

      setState(() {
        _lastState = _currentState;
        _currentState = VoiceCommentState.recording;
      });
    } catch (e) {
      debugPrint('녹음 시작 오류: $e');
      setState(() {
        _lastState = _currentState;
        _currentState = VoiceCommentState.idle;
      });
    }
  }

  /// 녹음을 중지하고 상태를 recorded로 전환
  Future<void> stopRecording() async {
    try {
      final waveformData = List<double>.from(
        _recorderController.waveData,
      ).map((value) => value.abs()).toList();

      await _recorderController.stop();
      await _audioController.stopRecordingSimple();

      final filePath = _audioController.currentRecordingPath;
      final recordingDuration = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
          : 0;

      if (filePath != null && filePath.isNotEmpty) {
        await _playerController?.preparePlayer(
          path: filePath,
          shouldExtractWaveform: true,
        );

        setState(() {
          _lastState = _currentState;
          _currentState = VoiceCommentState.recorded;
          _waveformData = waveformData;
        });

        widget.onRecordingCompleted?.call(
          filePath,
          waveformData,
          recordingDuration,
        );
      }
    } catch (e) {
      debugPrint('녹음 중지 오류: $e');
    }
  }

  /// 녹음을 삭제하고 상태를 idle로 복귀
  void deleteRecording() {
    try {
      if (_playerController?.playerState.isPlaying == true) {
        _playerController?.stopPlayer();
      }

      setState(() {
        _lastState = _currentState;
        _currentState = VoiceCommentState.idle;
        _waveformData = null;
      });

      widget.onRecordingDeleted?.call();
    } catch (e) {
      debugPrint('녹음 삭제 오류: $e');
    }
  }
  // ============================================================

  /// AudioController와 RecorderController, PlayerController 초기화
  /// AAC 코덱, 44.1kHz 샘플레이트로 설정
  void _initializeControllers() {
    _audioController = Provider.of<AudioController>(context, listen: false);

    _recorderController = RecorderController()
      ..overrideAudioSession = false
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
      ..sampleRate = 44100;

    _playerController = PlayerController();
  }

  /// 녹음 시작 및 recording 상태로 전환
  /// 녹음 시작 시간을 기록하여 duration 계산에 사용
  Future<void> _startRecording() async {
    try {
      // 녹음 시작 시간 기록
      _recordingStartTime = DateTime.now();

      await _recorderController.record();
      await _audioController.startRecording();

      setState(() {
        _lastState = _currentState;
        _currentState = VoiceCommentState.recording;
      });
    } catch (e) {
      setState(() {
        _lastState = _currentState;
        _currentState = VoiceCommentState.idle;
      });
    }
  }

  /// 녹음 중지 및 recorded 상태로 전환
  /// 파형 데이터를 추출하고 PlayerController를 준비
  Future<void> _stopAndPreparePlayback() async {
    try {
      // 중복 정지 방지
      if (!_audioController.isRecording) {
        debugPrint('이미 녹음이 중지되었습니다');
        return;
      }

      debugPrint('녹음 정지 및 재생 준비 시작...');

      // 파형 데이터 추출
      List<double> waveformData = List<double>.from(
        _recorderController.waveData,
      );
      if (waveformData.isNotEmpty) {
        waveformData = waveformData.map((value) => value.abs()).toList();
      }

      // 순차적으로 중지: 먼저 waveform controller
      if (_recorderController.isRecording) {
        await _recorderController.stop();
      }

      // 그 다음 native recorder (이제 동기적으로 처리됨)
      await _audioController.stopRecordingSimple();

      final filePath = _audioController.currentRecordingPath;
      if (filePath != null && filePath.isNotEmpty) {
        // 녹음 시간 계산
        final recordingDuration = _recordingStartTime != null
            ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
            : 0;

        // 재생 준비
        await _playerController?.preparePlayer(
          path: filePath,
          shouldExtractWaveform: true,
        );

        setState(() {
          _lastState = _currentState;
          _currentState = VoiceCommentState.recorded;
          _waveformData = waveformData;
        });

        // 콜백 호출 (duration 포함)
        widget.onRecordingCompleted?.call(
          filePath,
          waveformData,
          recordingDuration,
        );
      }
    } catch (e) {
      debugPrint('녹음 중지 오류: $e');
    }
  }

  /// 녹음 삭제 및 idle 상태로 복귀
  /// 쓰레기통 아이콘 클릭 시 호출
  void _deleteRecording() {
    try {
      // 재생 중이면 중지
      if (_playerController?.playerState.isPlaying == true) {
        _playerController?.stopPlayer();
      }

      // 상태 초기화
      setState(() {
        _lastState = _currentState;
        _currentState = VoiceCommentState.idle;
        _waveformData = null;
      });

      // 삭제 콜백 호출
      widget.onRecordingDeleted?.call();
    } catch (e) {
      debugPrint('녹음 삭제 오류: $e');
    }
  }

  // ============================================================
  // Playback Flow Methods
  // ============================================================

  /// 오디오 재생/일시정지 토글
  /// PlayerController의 상태에 따라 재생 또는 일시정지 실행
  Future<void> _togglePlayback() async {
    // null 체크와 mounted 체크 추가
    if (!mounted || _playerController == null) {
      return;
    }

    try {
      if (_playerController!.playerState.isPlaying) {
        await _playerController!.pausePlayer();
      } else {
        // 재생이 끝났다면 처음부터 다시 시작
        if (_playerController!.playerState.isStopped) {
          await _playerController!.startPlayer();
        } else {
          await _playerController!.startPlayer();
        }
      }
      if (mounted) {
        setState(() {}); // UI 갱신
      }
    } catch (e) {
      debugPrint('재생/일시정지 오류: $e');
    }
  }

  /// 녹음 중 UI (AudioRecorderWidget과 동일)
  /// 실시간 파형, 녹음 시간, 중지 버튼을 표시
  Widget _buildRecordingUI(String duration) {
    final borderRadius = BorderRadius.circular(21.5);
    return Container(
      width: 353, // 텍스트 필드와 동일한 너비
      height: 46, // 텍스트 필드와 동일한 높이
      decoration: BoxDecoration(
        color: const Color(0xffd9d9d9).withValues(alpha: 0.1),
        borderRadius: borderRadius,
        border: Border.all(
          color: const Color(0x66D9D9D9).withValues(alpha: 0.4),
          width: 1,
        ),
        // 3D: 떠있는 느낌(아래 그림자 + 위쪽 하이라이트)
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            offset: const Offset(0, 10),
            blurRadius: 18,
            spreadRadius: -8,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.06),
            offset: const Offset(0, -2),
            blurRadius: 6,
            spreadRadius: -2,
          ),
        ],
      ),
      // 3D: 상단 하이라이트/하단 음영 오버레이(기존 색 유지)
      foregroundDecoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.18),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 15.w),
          // 쓰레기통 아이콘 (녹음 취소)
          GestureDetector(
            onTap: _deleteRecording,
            child: Image.asset('assets/trash.png', width: 25, height: 25),
          ),
          SizedBox(width: 18.w),
          // 실시간 파형
          Expanded(
            child: AudioWaveforms(
              size: Size(1, 46),
              recorderController: _recorderController,
              waveStyle: const WaveStyle(
                waveColor: Colors.white,
                extendWaveform: true,
                showMiddleLine: false,
              ),
            ),
          ),
          // 녹음 시간
          Text(
            duration,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'Pretendard Variable',
              fontWeight: FontWeight.w500,
              letterSpacing: -0.40,
            ),
          ),
          // 중지 버튼
          IconButton(
            onPressed: _stopAndPreparePlayback,
            padding: EdgeInsets.only(bottom: 3.h),
            icon: Icon(Icons.stop, color: Colors.white, size: 35.sp),
          ),
        ],
      ),
    );
  }

  /// 재생 UI (AudioRecorderWidget과 동일)
  /// 파형, 재생 시간, 재생/일시정지 버튼을 표시
  Widget _buildPlaybackUI() {
    final borderRadius = BorderRadius.circular(21.5);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: 353,
      height: 46,
      // 3D: 바깥쪽 그림자로 태그처럼 떠 보이게
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            offset: const Offset(0, 10),
            blurRadius: 18,
            spreadRadius: -8,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.06),
            offset: const Offset(0, -2),
            blurRadius: 6,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: borderRadius,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: Container(
                  key: ValueKey('playback_bg'),
                  decoration: BoxDecoration(
                    color: const Color(0xffd9d9d9).withValues(alpha: 0.1),
                    border: Border.all(
                      color: const Color(0x66D9D9D9).withValues(alpha: 0.4),
                      width: 1,
                    ),
                    borderRadius: borderRadius,
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              // 3D: 상단 하이라이트/하단 음영 오버레이(기존 배경색은 그대로)
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.18),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 15.w),
                // 쓰레기통 아이콘 (삭제)
                GestureDetector(
                  onTap: _deleteRecording,
                  child: Image.asset('assets/trash.png', width: 25, height: 25),
                ),
                SizedBox(width: 18.w),
                // 재생 파형 - 드래그 가능
                Expanded(
                  child: _buildWaveformDraggable(
                    child: _waveformData != null && _waveformData!.isNotEmpty
                        ? StreamBuilder<int>(
                            stream:
                                _playerController?.onCurrentDurationChanged ??
                                const Stream.empty(),
                            builder: (context, positionSnapshot) {
                              // mounted와 _playerController null 체크 추가
                              if (!mounted || _playerController == null) {
                                return Container();
                              }

                              final currentPosition =
                                  positionSnapshot.data ?? 0;
                              final totalDuration =
                                  _playerController?.maxDuration ?? 1;
                              final progress = totalDuration > 0
                                  ? (currentPosition / totalDuration).clamp(
                                      0.0,
                                      1.0,
                                    )
                                  : 0.0;

                              // _waveformData가 여전히 null이 아닌지 다시 확인
                              if (_waveformData == null ||
                                  _waveformData!.isEmpty) {
                                return Container();
                              }

                              return CustomWaveformWidget(
                                waveformData: _waveformData!,
                                color: Colors.grey,
                                activeColor: Colors.white,
                                progress: progress,
                              );
                            },
                          )
                        : Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade700,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '파형 없음',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14.sp,
                                  fontFamily: "Pretendard",
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                // 재생 시간
                StreamBuilder<int>(
                  stream:
                      _playerController?.onCurrentDurationChanged ??
                      const Stream.empty(),
                  builder: (context, snapshot) {
                    // mounted와 _playerController null 체크 추가
                    if (!mounted || _playerController == null) {
                      return Text(
                        '00:00',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'Pretendard Variable',
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.40,
                        ),
                      );
                    }

                    final currentDurationMs = snapshot.data ?? 0;
                    final currentDuration = Duration(
                      milliseconds: currentDurationMs,
                    );
                    final minutes = currentDuration.inMinutes;
                    final seconds = currentDuration.inSeconds % 60;
                    return Text(
                      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'Pretendard Variable',
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.40,
                      ),
                    );
                  },
                ),
                // 재생/일시정지 버튼
                StreamBuilder<PlayerState>(
                  stream:
                      _playerController?.onPlayerStateChanged ??
                      const Stream.empty(),
                  builder: (context, snapshot) {
                    // mounted와 _playerController null 체크 추가
                    if (!mounted || _playerController == null) {
                      return IconButton(
                        onPressed: null,
                        icon: Icon(
                          Icons.play_arrow,
                          color: Colors.white54,
                          size: 35.sp,
                        ),
                      );
                    }

                    final playerState = snapshot.data;
                    final isPlaying = playerState?.isPlaying ?? false;

                    return IconButton(
                      onPressed: _togglePlayback,
                      padding: EdgeInsets.only(bottom: 3.h),
                      icon: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 35.sp,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Profile Placement Flow Methods
  // ============================================================

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
    Future.delayed(Duration(milliseconds: 400), () {
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

  // ============================================================
  // UI Helper Methods
  // ============================================================

  /// 파형 위에 드래그 가능한 프로필 이미지 오버레이
  /// recorded 상태에서 placing 상태로 전환하는 진입점
  /// 파형을 감싸서 프로필 이미지를 드래그할 수 있게 함
  Widget _buildWaveformDraggable({required Widget child}) {
    if (widget.onProfileImageDragged == null ||
        _waveformData == null ||
        _waveformData!.isEmpty) {
      return child;
    }

    final profileWidget = _buildProfileAvatar(size: _placementAvatarSize);
    final dragWidget = TagBubble(
      contentSize: _placementAvatarSize,
      child: profileWidget,
    );

    return Draggable<String>(
      key: _profileDraggableKey,
      data: 'profile_image',
      dragAnchorStrategy: _tagPointerDragAnchor,
      feedback: Transform.scale(
        scale: 1.2,
        child: Opacity(opacity: 0.8, child: dragWidget),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: dragWidget),
      onDragStarted: _beginPlacementFromWaveform,
      child: child,
    );
  }

  /// 프로필 아바타를 드래그 가능한 위젯으로 생성
  /// isPlacementMode에 따라 배치 완료/취소 로직 실행
  /// placing/saved 상태에서 사용
  Widget _buildProfileDraggable({required bool isPlacementMode}) {
    final avatarSize = isPlacementMode
        ? _placementAvatarSize
        : _defaultAvatarSize;
    final profileWidget = _buildProfileAvatar(size: avatarSize);
    final dragWidget = isPlacementMode
        ? TagBubble(contentSize: avatarSize, child: profileWidget)
        : profileWidget;

    if (widget.onProfileImageDragged == null) {
      return dragWidget;
    }

    return Draggable<String>(
      key: isPlacementMode ? _profileDraggableKey : null,
      data: 'profile_image',
      dragAnchorStrategy: isPlacementMode
          ? _tagPointerDragAnchor
          : pointerDragAnchorStrategy,
      feedback: Transform.scale(
        scale: 1.2,
        child: Opacity(opacity: 0.8, child: dragWidget),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: dragWidget),
      onDragStarted: isPlacementMode ? _holdParentScroll : null,
      onDraggableCanceled: (velocity, offset) {
        if (!isPlacementMode) {
          return;
        }
        _cancelPlacement();
      },
      onDragEnd: (details) {
        if (!isPlacementMode) {
          return;
        }

        if (details.wasAccepted) {
          _finalizePlacement();
        }
      },
      child: dragWidget,
    );
  }

  Offset _tagPointerDragAnchor(
    Draggable<Object> draggable,
    BuildContext context,
    Offset position,
  ) {
    return TagBubble.pointerTipOffset(contentSize: _placementAvatarSize);
  }

  /// 프로필 아바타 위젯 생성
  /// profileImageUrl이 있으면 CachedNetworkImage 사용, 없으면 기본 아이콘 표시
  Widget _buildProfileAvatar({required double size}) {
    return Consumer2<UserController, MediaController>(
      builder: (context, userController, mediaController, _) {
        final profileSource =
            userController.currentUser?.profileImageUrlKey ??
            widget.profileImageUrl;
        final future = _getResolvedProfileImageUrl(
          profileSource,
          mediaController,
        );
        return FutureBuilder<String?>(
          future: future,
          builder: (context, snapshot) {
            final resolvedUrl = snapshot.data ?? widget.profileImageUrl;
            return _buildAvatarFromUrl(resolvedUrl, size: size);
          },
        );
      },
    );
  }

  Future<String?> _getResolvedProfileImageUrl(
    String? profileKey,
    MediaController mediaController,
  ) {
    if (profileKey == null || profileKey.isEmpty) {
      return Future.value(null);
    }

    final uri = Uri.tryParse(profileKey);
    if (uri != null && uri.hasScheme) {
      return Future.value(profileKey);
    }

    final cachedFuture = _profileUrlFutures[profileKey];
    if (cachedFuture != null) {
      return cachedFuture;
    }

    final future = mediaController.getPresignedUrl(profileKey);
    _profileUrlFutures[profileKey] = future;
    return future;
  }

  Widget _buildAvatarFromUrl(String? imageUrl, {required double size}) {
    // 3D: 프로필 태그가 떠 보이도록 원형 그림자 + 하이라이트
    final avatar3dShadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.55),
        offset: const Offset(0, 10),
        blurRadius: 18,
        spreadRadius: -10,
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.06),
        offset: const Offset(0, -2),
        blurRadius: 6,
        spreadRadius: -4,
      ),
    ];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: avatar3dShadow,
      ),
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.06),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.10),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: imageUrl != null && imageUrl.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: size,
                height: size,
                memCacheWidth: (size * 2).round(),
                maxWidthDiskCache: (size * 2).round(),
                fit: BoxFit.cover,
                placeholder: (context, url) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      shape: BoxShape.circle,
                    ),
                  );
                },
                errorWidget: (context, url, error) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.red[700],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error,
                      color: Colors.white,
                      size: 14,
                    ),
                  );
                },
              ),
            )
          : Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xffd9d9d9),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 14),
            ),
    );
  }

  // ============================================================
  // Scroll Management Methods
  // ============================================================

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

  // ============================================================
  // Public Methods
  // ============================================================

  /// 외부에서 저장 완료를 알리는 메서드
  /// 부모 위젯에서 저장이 완료되었음을 알릴 때 사용
  void markAsSaved() {
    if (mounted) {
      _markAsSaved();
    }
  }
}
