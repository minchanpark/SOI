import 'dart:async';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../api/controller/audio_controller.dart';
import '../../about_archiving/widgets/wave_form_widget/custom_waveform_widget.dart';

/// 녹음 상태를 나타내는 enum입니다.
enum RecordingState {
  recording, // 녹음 중
  recorded, // 녹음 완료 상태
}

/// 오디오 녹음 위젯
/// 사진 편집 시 음성 메모를 녹음하고 재생하는 기능을 제공합니다.
/// 편집 모드 전용 위젯입니다.
class AudioRecorderWidget extends StatefulWidget {
  // 녹음이 완료되었을 때 호출되는 콜백
  final Function(String?, List<double>?)? onRecordingCompleted;

  // 녹음이 최종적으로 완료되었을 때 호출되는 콜백
  final Function(
    String audioFilePath,
    List<double> waveformData,
    Duration duration,
  )?
  onRecordingFinished;

  // 녹음이 취소되었을 때 호출되는 콜백
  final VoidCallback? onRecordingCleared;

  // 초기 녹음 파일 경로
  final String? initialRecordingPath;

  // 초기 파형 데이터
  final List<double>? initialWaveformData;

  // 동작 설정
  final bool autoStart;
  final AudioController? audioController;

  const AudioRecorderWidget({
    super.key,
    this.onRecordingCompleted,
    this.onRecordingFinished,
    this.onRecordingCleared,
    this.initialRecordingPath,
    this.initialWaveformData,
    this.autoStart = false,
    this.audioController,
  });

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget>
    with SingleTickerProviderStateMixin {
  // ========== 컨트롤러들 ==========
  late AudioController _audioController; // 오디오 상태 관리 컨트롤러
  late RecorderController recorderController; // 녹음 컨트롤러
  PlayerController? playerController; // 재생 컨트롤러

  // ========== 상태 관리 변수들 ==========
  // 현재 녹음 상태를 관리하는 변수
  RecordingState _currentState = RecordingState.recording;

  // 이전 녹음 상태를 관리하는 변수
  RecordingState? _previousState;

  // ========== 녹음 관련 파일을 저장하는 변수들 ==========
  // 녹음된 파일 경로
  String? _recordedFilePath;
  // 파형 데이터
  List<double>? _waveformData;

  // 오디오 상태 모니터링
  Timer? _audioControllerTimer;
  bool _wasRecording = true;

  // ========== 생명주기 메서드들 ==========
  @override
  void initState() {
    super.initState();
    _resolveAudioController();
    _initializeAudioControllers();
    _initializeState();
    _handleAutoStart();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.audioController == null) {
      _audioController = Provider.of<AudioController>(context, listen: false);
    }
  }

  @override
  void dispose() {
    _stopAudioControllerListener();
    recorderController.dispose();
    playerController?.dispose();
    super.dispose();
  }

  // ========== 초기화 메서드들 ==========
  void _resolveAudioController() {
    _audioController =
        widget.audioController ??
        Provider.of<AudioController>(context, listen: false);
  }

  void _initializeAudioControllers() {
    recorderController = RecorderController()
      ..overrideAudioSession = false
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
      ..sampleRate = 44100;

    recorderController.checkPermission();
    playerController = PlayerController();
  }

  // 초기 상태 설정하는 메소드
  void _initializeState() {
    if (widget.initialRecordingPath != null &&
        widget.initialRecordingPath!.isNotEmpty) {
      _currentState = RecordingState.recorded;
      _recordedFilePath = widget.initialRecordingPath;
      _waveformData = widget.initialWaveformData;
    } else if (widget.autoStart) {
      _currentState = RecordingState.recording;
    }
  }

  void _handleAutoStart() {
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startRecording();
      });
    }
  }

  // ========== 녹음 관련 메서드들 ==========

  // 녹음 시작
  Future<void> _startRecording() async {
    try {
      await recorderController.record();
      await _audioController.startRecording();
      // 녹음 중의 상태로 전환
      // 녹음 중이란 것을 나타내는 것임
      _setState(RecordingState.recording);

      // 오디오 컨트롤러 상태 모니터링 시작
      _startAudioControllerListener();
    } catch (e) {
      debugPrint('녹음 시작 오류: $e');
      // 에러 발생 시 위젯을 제거하여 텍스트 필드로 돌아감
      widget.onRecordingCleared?.call();
    }
  }

  Future<void> _stopAndPreparePlayback() async {
    try {
      // 중복 정지 방지
      if (!_audioController.isRecording) {
        debugPrint('이미 녹음이 중지되었습니다');
        return;
      }

      // 리스너 즉시 중지
      _stopAudioControllerListener();

      debugPrint('녹음 정지 및 재생 준비 시작...');

      List<double> waveformData = List<double>.from(
        recorderController.waveData,
      );

      if (waveformData.isNotEmpty) {
        waveformData = waveformData.map((value) => value.abs()).toList();
      }

      // 순차적으로 중지: 먼저 waveform controller
      if (recorderController.isRecording) {
        await recorderController.stop();
      }

      // 그 다음 native recorder (이제 동기적으로 처리됨)
      await _audioController.stopRecordingSimple();

      if (_audioController.currentRecordingPath != null &&
          _audioController.currentRecordingPath!.isNotEmpty &&
          playerController != null) {
        try {
          await playerController!.preparePlayer(
            path: _audioController.currentRecordingPath!,
            shouldExtractWaveform: true,
          );

          if (waveformData.isEmpty) {
            final extractedWaveform = await playerController!
                .extractWaveformData(
                  path: _audioController.currentRecordingPath!,
                  noOfSamples: 100,
                );
            if (extractedWaveform.isNotEmpty) {
              waveformData = extractedWaveform;
            }
          }
        } catch (e) {
          debugPrint('재생 준비 오류: $e');
        }
      }

      final recordingPath = _audioController.currentRecordingPath;
      final recordingDuration = Duration(
        seconds: _audioController.recordingDuration,
      );

      setState(() {
        _previousState = _currentState;
        _currentState = RecordingState.recorded;
        _recordedFilePath = recordingPath;
        _waveformData = waveformData;
      });

      if (widget.onRecordingCompleted != null) {
        widget.onRecordingCompleted!(recordingPath, waveformData);
      }

      if (widget.onRecordingFinished != null &&
          recordingPath != null &&
          recordingPath.isNotEmpty) {
        widget.onRecordingFinished!(
          recordingPath,
          waveformData,
          recordingDuration,
        );
      }
    } catch (e) {
      debugPrint('녹음 정지 오류: $e');
      _stopAudioControllerListener(); // 에러 시에도 정리
    }
  }

  Future<void> _cancelRecording() async {
    try {
      debugPrint('녹음 취소 및 완전 초기화 시작...');

      _stopAudioControllerListener();

      // 중복 정지 방지
      if (recorderController.hasPermission) {
        await recorderController.stop(); // 녹음 중지
      }

      // 네이티브 녹음을 중지하고 파일 경로를 반환합니다.
      await _audioController.stopRecordingSimple();

      if (playerController?.playerState.isPlaying == true) {
        await playerController?.stopPlayer();
      }

      // 상태 초기화 (setState 호출하지 않음)
      _previousState = _currentState;
      _recordedFilePath = null;
      _waveformData = null;
      _audioController.clearCurrentRecording();

      debugPrint('녹음 취소 및 초기화 완료');
    } catch (e) {
      debugPrint('녹음 취소 오류: $e');
      // 에러 발생 시에도 상태만 초기화 (setState 호출하지 않음)
      _previousState = _currentState;
      _recordedFilePath = null;
      _waveformData = null;
      _audioController.clearCurrentRecording();
    }

    // 부모 위젯에 알려서 텍스트 필드로 전환
    widget.onRecordingCleared?.call();
  }

  void _deleteRecording() {
    try {
      if (playerController?.playerState.isPlaying == true) {
        playerController?.stopPlayer();
      }

      // 상태 초기화 (setState 호출하지 않음)
      _previousState = _currentState;
      _recordedFilePath = null;
      _waveformData = null;
      _audioController.clearCurrentRecording();
    } catch (e) {
      debugPrint('녹음 파일 삭제 오류: $e');
    }

    // 부모 위젯에 알려서 텍스트 필드로 전환
    widget.onRecordingCleared?.call();
  }

  // ========== 재생 관련 메서드들 ==========

  Future<void> _togglePlayback() async {
    if (playerController == null || _recordedFilePath == null) return;

    try {
      if (playerController!.playerState.isPlaying) {
        await playerController!.pausePlayer();
        debugPrint('재생 일시정지');
      } else {
        if (playerController!.playerState == PlayerState.initialized ||
            playerController!.playerState == PlayerState.paused) {
          await playerController!.startPlayer();
          debugPrint('재생 시작');
        } else {
          await playerController!.preparePlayer(path: _recordedFilePath!);
          await playerController!.startPlayer();
          debugPrint('재생 준비 후 시작');
        }
      }
      setState(() {});
    } catch (e) {
      debugPrint('재생/일시정지 오류: $e');
    }
  }

  // ========== 오디오 상태 모니터링 ==========

  /// 오디오 컨트롤러 상태 모니터링 시작
  void _startAudioControllerListener() {
    _wasRecording = true;
    _audioControllerTimer = Timer.periodic(Duration(milliseconds: 100), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        _audioControllerTimer = null;
        return;
      }

      final isCurrentlyRecording = _audioController.isRecording;

      if (_wasRecording && !isCurrentlyRecording) {
        timer.cancel();
        _audioControllerTimer = null;
        _handleAudioControllerStopped();
      }
    });
  }

  // 오디오 컨트롤러 상태 모니터링 중지
  void _stopAudioControllerListener() {
    _audioControllerTimer?.cancel();
    _audioControllerTimer = null;
  }

  // 오디오 컨트롤러가 정지 상태로 전환되었을 때 처리
  Future<void> _handleAudioControllerStopped() async {
    try {
      if (!mounted) {
        return;
      }

      List<double> waveformData = List<double>.from(
        recorderController.waveData,
      );
      await recorderController.stop();

      if (waveformData.isNotEmpty) {
        waveformData = waveformData.map((value) => value.abs()).toList();
      }

      _recordedFilePath = _audioController.currentRecordingPath;

      if (playerController != null && _recordedFilePath != null) {
        try {
          await playerController!.preparePlayer(
            path: _recordedFilePath!,
            shouldExtractWaveform: false,
          );
        } catch (e) {
          debugPrint('재생 컨트롤러 준비 오류: $e');
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _previousState = _currentState;
        _currentState = RecordingState.recorded;
        _waveformData = waveformData;
      });

      if (widget.onRecordingCompleted != null) {
        widget.onRecordingCompleted!(_recordedFilePath, waveformData);
      }
      if (widget.onRecordingFinished != null && _recordedFilePath != null) {
        widget.onRecordingFinished!(
          _recordedFilePath!,
          waveformData,
          Duration(seconds: _audioController.recordingDuration),
        );
      }
    } catch (e) {
      if (mounted) {
        // 에러 발생 시 위젯을 제거하여 텍스트 필드로 돌아감
        widget.onRecordingCleared?.call();
      }
    }
  }

  // ========== 상태 관리 및 헬퍼 메서드들 ==========

  void _setState(RecordingState newState) {
    if (mounted) {
      setState(() {
        _previousState = _currentState;
        _currentState = newState;
      });
    }
  }

  void _resetToMicrophoneIcon() {
    // idle 상태가 제거되어 이 메서드는 더 이상 사용되지 않음
    // 대신 onRecordingCleared를 호출하여 텍스트 필드로 돌아감
    widget.onRecordingCleared?.call();
  }

  void resetToMicrophoneIcon() {
    _resetToMicrophoneIcon();
  }

  // ========== UI 빌드 메서드들 ==========

  @override
  Widget build(BuildContext context) {
    bool shouldAnimate =
        !(_previousState == RecordingState.recording &&
            _currentState == RecordingState.recorded);

    if (!shouldAnimate) {
      return _buildCurrentStateWidget();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return ScaleTransition(scale: animation, child: child);
      },
      child: _buildCurrentStateWidget(),
    );
  }

  Widget _buildCurrentStateWidget() {
    String widgetKey;
    if (_previousState == RecordingState.recording &&
        _currentState == RecordingState.recorded) {
      widgetKey = 'audio-ui-no-animation';
    } else {
      widgetKey = _currentState.toString();
    }

    switch (_currentState) {
      case RecordingState.recording:
        return Selector<AudioController, String>(
          key: ValueKey(widgetKey),
          selector: (context, controller) =>
              controller.formattedRecordingDuration,
          builder: (context, duration, child) {
            return SizedBox(
              height: 46,
              child: _buildAudioUI(
                backgroundColor: const Color(
                  0xff373737,
                ).withValues(alpha: 0.66),
                isRecording: true,
                duration: duration,
              ),
            );
          },
        );

      case RecordingState.recorded:
        return SizedBox(
          key: ValueKey(widgetKey),
          height: 46,
          child: _buildAudioUI(
            backgroundColor: const Color(0xff222222),
            isRecording: false,
          ),
        );
    }
  }

  Widget _buildAudioUI({
    required Color backgroundColor,
    required bool isRecording,
    String? duration,
  }) {
    final borderRadius = BorderRadius.circular(21.5);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      key: const ValueKey('audio_ui'),
      curve: Curves.easeInOut,

      decoration: BoxDecoration(borderRadius: borderRadius),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: borderRadius,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: Container(color: backgroundColor),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 14.w),
              // 삭제 버튼
              GestureDetector(
                onTap: isRecording ? _cancelRecording : _deleteRecording,
                child: Image.asset('assets/trash.png', width: 25, height: 25),
              ),
              SizedBox(width: 17.w),
              // 파형 표시 영역
              Expanded(
                child: isRecording
                    ? AudioWaveforms(
                        size: Size(1, 44.h),
                        recorderController: recorderController,
                        waveStyle: const WaveStyle(
                          waveColor: Colors.white,
                          extendWaveform: true,
                          showMiddleLine: false,
                        ),
                      )
                    : _buildWaveformDisplay(),
              ),
              SizedBox(width: 13.w),
              // 시간 표시
              SizedBox(
                child: isRecording
                    ? Text(
                        duration ?? '00:00',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.40,
                        ),
                      )
                    : StreamBuilder<int>(
                        stream:
                            playerController?.onCurrentDurationChanged ??
                            const Stream.empty(),
                        builder: (context, snapshot) {
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
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.40,
                            ),
                          );
                        },
                      ),
              ),
              // 재생/정지 버튼
              IconButton(
                onPressed: isRecording
                    ? _stopAndPreparePlayback
                    : _togglePlayback,
                padding: EdgeInsets.only(bottom: 0.h),
                icon: isRecording
                    ? Icon(Icons.stop, color: Colors.white, size: 35.sp)
                    : StreamBuilder<PlayerState>(
                        stream:
                            playerController?.onPlayerStateChanged ??
                            const Stream.empty(),
                        builder: (context, snapshot) {
                          final isPlaying = snapshot.data?.isPlaying ?? false;
                          return Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 35.sp,
                          );
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaveformDisplay() {
    return _waveformData != null && _waveformData!.isNotEmpty
        ? StreamBuilder<int>(
            stream:
                playerController?.onCurrentDurationChanged ??
                const Stream.empty(),
            builder: (context, positionSnapshot) {
              final currentPosition = positionSnapshot.data ?? 0;
              final totalDuration = playerController?.maxDuration ?? 1;
              final progress = totalDuration > 0
                  ? (currentPosition / totalDuration).clamp(0.0, 1.0)
                  : 0.0;

              return CustomWaveformWidget(
                waveformData: _waveformData!,
                color: Colors.grey,
                activeColor: Colors.white,
                progress: progress,
              );
            },
          )
        : Container(
            height: 52.h,
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
          );
  }
}
