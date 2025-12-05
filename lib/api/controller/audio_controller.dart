import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart' as ap;

/// API 기반 음성 댓글 오디오 컨트롤러
///
/// 음성 댓글의 재생/일시정지를 관리합니다.
/// Firebase 버전과 독립적으로 동작합니다.
class AudioController extends ChangeNotifier {
  // ==================== 상태 관리 ====================

  /// AudioPlayer 인스턴스
  ap.AudioPlayer? _audioPlayer;

  /// 현재 재생 중인 오디오 URL
  String? _currentAudioUrl;

  /// 재생 상태
  bool _isPlaying = false;

  /// 로딩 상태
  bool _isLoading = false;

  /// 현재 재생 위치
  Duration _currentPosition = Duration.zero;

  /// 총 재생 시간
  Duration _totalDuration = Duration.zero;

  /// 에러 메시지
  String? _error;

  /// 스트림 구독
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<ap.PlayerState>? _stateSubscription;

  // ==================== Getters ====================

  /// 현재 재생 중인 오디오 URL
  String? get currentAudioUrl => _currentAudioUrl;

  /// 재생 중인지 여부
  bool get isPlaying => _isPlaying;

  /// 로딩 중인지 여부
  bool get isLoading => _isLoading;

  /// 현재 재생 위치
  Duration get currentPosition => _currentPosition;

  /// 총 재생 시간
  Duration get totalDuration => _totalDuration;

  /// 재생 진행률 (0.0 ~ 1.0)
  double get progress {
    if (_totalDuration == Duration.zero) return 0.0;
    return (_currentPosition.inMilliseconds / _totalDuration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  /// 에러 메시지
  String? get error => _error;

  // ==================== 재생 제어 ====================

  /// 오디오 재생
  Future<void> play(String audioUrl) async {
    try {
      _setLoading(true);
      _clearError();

      // 같은 URL이 재생 중이면 재개
      if (_currentAudioUrl == audioUrl && _audioPlayer != null) {
        await _audioPlayer!.resume();
        _isPlaying = true;
        _setLoading(false);
        notifyListeners();
        return;
      }

      // 다른 오디오가 재생 중이면 정지
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
        await _disposePlayer();
      }

      // 새 플레이어 생성
      _audioPlayer = ap.AudioPlayer();
      _currentAudioUrl = audioUrl;

      // 스트림 리스너 설정
      _setupListeners();

      // 재생 시작
      await _audioPlayer!.play(ap.UrlSource(audioUrl));
      _isPlaying = true;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('오디오 재생 실패: $e');
      _setLoading(false);
    }
  }

  /// 일시정지
  Future<void> pause() async {
    try {
      if (_audioPlayer != null && _isPlaying) {
        await _audioPlayer!.pause();
        _isPlaying = false;
        notifyListeners();
      }
    } catch (e) {
      _setError('일시정지 실패: $e');
    }
  }

  /// 재생/일시정지 토글
  Future<void> togglePlayPause(String audioUrl) async {
    if (_currentAudioUrl == audioUrl && _isPlaying) {
      await pause();
    } else {
      await play(audioUrl);
    }
  }

  /// 정지
  Future<void> stop() async {
    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
        _isPlaying = false;
        _currentPosition = Duration.zero;
        notifyListeners();
      }
    } catch (e) {
      _setError('정지 실패: $e');
    }
  }

  /// 특정 위치로 이동
  Future<void> seek(Duration position) async {
    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.seek(position);
        _currentPosition = position;
        notifyListeners();
      }
    } catch (e) {
      _setError('탐색 실패: $e');
    }
  }

  /// 특정 URL이 현재 재생 중인지 확인
  bool isUrlPlaying(String audioUrl) {
    return _currentAudioUrl == audioUrl && _isPlaying;
  }

  // ==================== 내부 메서드 ====================

  void _setupListeners() {
    _positionSubscription = _audioPlayer!.onPositionChanged.listen((position) {
      _currentPosition = position;
      notifyListeners();
    });

    _durationSubscription = _audioPlayer!.onDurationChanged.listen((duration) {
      _totalDuration = duration;
      notifyListeners();
    });

    _stateSubscription = _audioPlayer!.onPlayerStateChanged.listen((state) {
      _isPlaying = state == ap.PlayerState.playing;

      // 재생 완료 시 초기화
      if (state == ap.PlayerState.completed) {
        _currentPosition = Duration.zero;
        _isPlaying = false;
      }

      notifyListeners();
    });
  }

  Future<void> _disposePlayer() async {
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _stateSubscription?.cancel();

    _positionSubscription = null;
    _durationSubscription = null;
    _stateSubscription = null;

    await _audioPlayer?.dispose();
    _audioPlayer = null;
    _currentAudioUrl = null;
    _currentPosition = Duration.zero;
    _totalDuration = Duration.zero;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    debugPrint('🔴 ApiCommentAudioController Error: $message');
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  // ==================== Lifecycle ====================

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }
}
