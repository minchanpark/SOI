import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:audio_waveforms/audio_waveforms.dart';
import '../services/audio_service.dart';
import '../models/audio_data_model.dart';

/// 오디오 관련 UI와 비즈니스 로직 사이의 중개 역할을 합니다.
class AudioController extends ChangeNotifier {
  // 상태 변수들
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isRecording = false;
  String? _currentRecordingPath;
  String? _currentPlayingAudioId;
  String? _currentPlayingAudioUrl; // 현재 재생 중인 오디오 URL 추가
  String? _currentRecordingUserId; // 현재 녹음 중인 사용자 ID 추가
  int _recordingDuration = 0;
  double _recordingLevel = 0.0;
  double _playbackPosition = 0.0;
  double _playbackDuration = 0.0;
  final double _uploadProgress = 0.0;
  String? _error;

  final List<AudioDataModel> _audioList = [];
  Timer? _recordingTimer;
  StreamSubscription<double>? _uploadSubscription;

  // 실시간 오디오 추적을 위한 AudioPlayer 관리
  ap.AudioPlayer? _realtimeAudioPlayer;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<ap.PlayerState>? _stateSubscription;

  // Service 인스턴스 - 모든 비즈니스 로직은 Service에서 처리
  final AudioService _audioService = AudioService();

  // ==================== 파형 관련 (audio_waveforms) ====================

  PlayerController? _playerController;
  final bool _isPlayerInitialized = false;

  /// PlayerController getter
  PlayerController? get playerController => _playerController;

  /// 플레이어 초기화 상태 getter
  bool get isPlayerInitialized => _isPlayerInitialized;

  // ==================== 권한 관리 ====================

  /// 마이크 권한 요청
  Future<bool> requestMicrophonePermission() async {
    return await _audioService.requestMicrophonePermission();
  }

  // ==================== Getters ====================

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String? get currentRecordingPath => _currentRecordingPath;
  String? get currentPlayingAudioId => _currentPlayingAudioId;
  String? get currentPlayingAudioUrl => _currentPlayingAudioUrl; // getter 추가
  String? get currentRecordingUserId =>
      _currentRecordingUserId; // 현재 녹음 중인 사용자 ID getter
  int get recordingDuration => _recordingDuration;
  double get recordingLevel => _recordingLevel;
  double get playbackPosition => _playbackPosition;
  double get playbackDuration => _playbackDuration;
  double get uploadProgress => _uploadProgress;
  String? get error => _error;
  List<AudioDataModel> get audioList => _audioList;

  /// 실시간 재생 위치 (Duration 타입)
  Duration get currentPosition =>
      Duration(milliseconds: (_playbackPosition * 1000).round());

  /// 실시간 재생 길이 (Duration 타입)
  Duration get currentDuration =>
      Duration(milliseconds: (_playbackDuration * 1000).round());

  /// 녹음 시간을 포맷팅하여 반환합니다 (예: "01:23")
  String get formattedRecordingDuration {
    final minutes = (_recordingDuration ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordingDuration % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // ==================== 초기화 ====================

  /// Controller 초기화
  Future<void> initialize() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _audioService.initialize();

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        // debugPrint('오디오 기능이 준비되었습니다.');
      } else {
        _error = result.error;
        // debugPrint(result.error ?? '오디오 초기화에 실패했습니다.');
      }
    } catch (e) {
      // debugPrint('오디오 컨트롤러 초기화 오류: $e');
      _isLoading = false;
      _error = '오디오 초기화 중 오류가 발생했습니다.';
      notifyListeners();
    }
  }

  /// Controller 종료
  @override
  void dispose() {
    debugPrint('🔊 AudioController dispose 시작');

    // 1. 타이머 및 스트림 정리
    _recordingTimer?.cancel();
    _uploadSubscription?.cancel();

    // 2. 모든 재생 중지 (동기적으로 처리)
    try {
      if (_realtimeAudioPlayer != null) {
        _realtimeAudioPlayer!.stop();
      }
    } catch (e) {
      debugPrint('AudioController dispose: 실시간 플레이어 정지 오류: $e');
    }

    // 3. 리스너 정리
    _disposeRealtimeListeners();

    // 4. 플레이어 정리 (순차적으로)
    try {
      _playerController?.dispose();
    } catch (e) {
      debugPrint('AudioController dispose: 파형 플레이어 정리 오류: $e');
    }

    try {
      _realtimeAudioPlayer?.dispose();
    } catch (e) {
      debugPrint('AudioController dispose: 실시간 플레이어 정리 오류: $e');
    }

    debugPrint('AudioController dispose 완료');
    super.dispose();
  }

  // ==================== 네이티브 녹음 관리 ====================

  /// 네이티브 녹음 시작
  Future<void> startRecording([String? userId]) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 1. 먼저 마이크 권한 확인/요청`
      final hasPermission = await requestMicrophonePermission();

      if (!hasPermission) {
        _isLoading = false;
        _error = '마이크 권한이 필요합니다.';
        notifyListeners();
        // debugPrint('마이크 권한이 없어 녹음을 시작할 수 없습니다.');
        throw Exception('마이크 권한이 필요합니다.');
      }

      // 2. 권한이 있을 때만 네이티브 녹음 시작
      final result = await _audioService.startRecording();

      if (result.isSuccess) {
        _isRecording = true;
        _currentRecordingPath = result.data;
        _currentRecordingUserId = userId; // 녹음 중인 사용자 ID 설정
        _recordingDuration = 0;

        // 녹음 시간 타이머 시작
        _startRecordingTimer();

        _isLoading = false;
        notifyListeners();
      } else {
        _isLoading = false;
        notifyListeners();

        debugPrint('네이티브 녹음 시작 실패: ${result.error}');
      }
    } catch (e) {
      debugPrint('네이티브 녹음 시작 오류: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 간단한 네이티브 녹음 중지 (UI용)
  Future<void> stopRecordingSimple() async {
    try {
      _isLoading = true;
      notifyListeners();

      // 타이머 및 구독 정리
      _stopRecordingTimer();

      // debugPrint('네이티브 간단 녹음 중지...');
      final result = await _audioService.stopRecordingSimple();

      _isLoading = false;
      _isRecording = false;

      if (result.isSuccess) {
        _currentRecordingPath = result.data ?? '';
      } else {
        _error = result.error;
        debugPrint('네이티브 간단 녹음 중지 실패: ${result.error}');
      }

      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _isRecording = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// 녹음 시간 타이머 시작
  void _startRecordingTimer() {
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _recordingDuration++;
      notifyListeners();
    });
  }

  /// 녹음 시간 타이머 중지
  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  // ==================== 유틸리티 ====================

  /// 에러 상태 초기화
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// 현재 녹음 경로 초기화
  void clearCurrentRecording() {
    _currentRecordingPath = null;
    _currentRecordingUserId = null;
    _recordingDuration = 0;
    _recordingLevel = 0.0;
    notifyListeners();
  }

  // ==================== 실시간 오디오 추적 ====================

  /// 실시간 AudioPlayer 초기화
  void _initializeRealtimePlayer() {
    if (_realtimeAudioPlayer != null) return;

    _realtimeAudioPlayer = ap.AudioPlayer();
    _setupRealtimeListeners();
  }

  /// 실시간 리스너 설정
  void _setupRealtimeListeners() {
    if (_realtimeAudioPlayer == null) return;

    // 재생 위치 변화 감지
    _positionSubscription = _realtimeAudioPlayer!.onPositionChanged.listen((
      Duration position,
    ) {
      _playbackPosition = position.inMilliseconds / 1000.0; // 초 단위로 변환
      notifyListeners();
    });

    // 재생 시간 변화 감지
    _durationSubscription = _realtimeAudioPlayer!.onDurationChanged.listen((
      Duration duration,
    ) {
      _playbackDuration = duration.inMilliseconds / 1000.0; // 초 단위로 변환
      notifyListeners();
    });

    // 재생 상태 변화 감지
    _stateSubscription = _realtimeAudioPlayer!.onPlayerStateChanged.listen((
      ap.PlayerState state,
    ) {
      _isPlaying = state == ap.PlayerState.playing;
      if (state == ap.PlayerState.completed) {
        _playbackPosition = 0.0;
        _currentPlayingAudioUrl = null;
      }
      notifyListeners();
    });
  }

  /// 실시간 오디오 재생 (중복 방지)
  Future<void> playRealtimeAudio(String audioUrl) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 이미 같은 오디오가 재생 중이면 일시정지/재생 토글
      if (_currentPlayingAudioUrl == audioUrl && _isPlaying) {
        if (_realtimeAudioPlayer != null) {
          await _realtimeAudioPlayer!.pause();
        }
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 기존과 URL 이 다를 때만 완전 정리
      if (_realtimeAudioPlayer != null && _currentPlayingAudioUrl != audioUrl) {
        await _realtimeAudioPlayer!.stop();
        await _realtimeAudioPlayer!.dispose();
        _disposeRealtimeListeners();
        _realtimeAudioPlayer = null;
        _currentPlayingAudioUrl = null;
      }

      // 새 플레이어 생성

      _initializeRealtimePlayer();

      // 새 오디오 재생
      debugPrint('새 오디오 재생 시작: $audioUrl');
      await _realtimeAudioPlayer!.play(ap.UrlSource(audioUrl));
      _currentPlayingAudioUrl = audioUrl;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('재생 오류: $e');
      _isLoading = false;
      _error = '음성 파일을 재생할 수 없습니다.';
      notifyListeners();
    }
  }

  /// 실시간 오디오 일시정지
  Future<void> pauseRealtimeAudio() async {
    if (_realtimeAudioPlayer != null && _isPlaying) {
      await _realtimeAudioPlayer!.pause();
      debugPrint('실시간 오디오 일시정지');
    }
  }

  /// 실시간 오디오 정지
  Future<void> stopRealtimeAudio() async {
    if (_realtimeAudioPlayer != null) {
      await _realtimeAudioPlayer!.stop();
      _playbackPosition = 0.0;
      _currentPlayingAudioUrl = null;
      debugPrint('실시간 오디오 정지');
      notifyListeners();
    }
  }

  /// 오디오 토글 (재생/일시정지) - UI용 간편 메서드
  Future<void> toggleAudio(String audioUrl, {String? commentId}) async {
    // commentId 는 향후 서로 다른 재생소스를 구분하기 위한 확장 포인트
    if (_currentPlayingAudioUrl == audioUrl) {
      if (_isPlaying) {
        await pauseRealtimeAudio();
      } else {
        await playRealtimeAudio(audioUrl);
      }
      return;
    }
    await playRealtimeAudio(audioUrl);
  }

  /// 오디오 정지 - UI용 간편 메서드
  Future<void> stopAudio() async {
    await stopRealtimeAudio();
  }

  /// 실시간 리스너 정리
  void _disposeRealtimeListeners() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _stateSubscription?.cancel();
    _positionSubscription = null;
    _durationSubscription = null;
    _stateSubscription = null;
  }
}
