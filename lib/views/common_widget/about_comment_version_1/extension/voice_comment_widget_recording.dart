// ignore_for_file: invalid_use_of_protected_member

part of '../voice_comment_widget.dart';

/// 음성 댓글 위젯의 녹음 관련 로직
/// - AudioController와 RecorderController, PlayerController 초기화
/// - 녹음 시작/중지 및 recorded 상태로 전환
/// - 녹음 삭제 및 idle 상태로 복귀
extension _VoiceCommentWidgetRecordingExtension on _VoiceCommentWidgetState {
  /// 컨트롤러 초기화
  /// AudioController는 Provider에서 가져오고, RecorderController와 PlayerController는 새 인스턴스 생성
  /// RecorderController와 PlayerController를 새로운 인스턴스로 가지고 오는 이유는
  /// : RecorderController는 녹음 상태와 파형 데이터를 관리하는 역할을 하며, PlayerController는 재생 상태와 관련된 기능을 담당하기 때문입니다.
  /// : 각각의 컨트롤러가 독립적으로 관리되어야 녹음과 재생 기능이 원활하게 작동할 수 있습니다. 만약 같은 인스턴스를 공유한다면, 녹음과 재생 상태가 충돌할 수 있고, 이는 버그로 이어질 수 있습니다.
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
}
