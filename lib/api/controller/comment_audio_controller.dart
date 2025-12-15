import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart' as ap;

/// 음성 댓글 전용 오디오 컨트롤러
///
/// 각 음성 댓글의 개별 재생/일시정지를 관리합니다.
/// 기존 AudioController와 독립적으로 동작하여 댓글별 오디오 재생을 담당합니다.
class CommentAudioController extends ChangeNotifier {
  // ==================== 상태 관리 ====================

  /// 댓글 ID별 AudioPlayer 인스턴스
  final Map<String, ap.AudioPlayer> _commentPlayers = {};

  /// 댓글 ID별 재생 상태
  final Map<String, bool> _isPlayingStates = {};

  /// 댓글 ID별 현재 재생 위치
  final Map<String, Duration> _currentPositions = {};

  /// 댓글 ID별 총 재생 시간
  final Map<String, Duration> _totalDurations = {};

  /// 댓글 ID별 오디오 URL 캐시
  final Map<String, String> _commentAudioUrls = {};

  /// 현재 재생 중인 댓글 ID
  String? _currentPlayingCommentId;

  /// 로딩 상태
  bool _isLoading = false;

  /// 에러 메시지
  String? _error;

  // ==================== Getters ====================

  /// 현재 재생 중인 댓글 ID
  String? get currentPlayingCommentId => _currentPlayingCommentId;

  /// 현재 어떤 댓글이라도 재생 중인지 확인
  bool get hasAnyPlaying => _isPlayingStates.values.any((playing) => playing);

  /// 로딩 상태
  bool get isLoading => _isLoading;

  /// 에러 메시지
  String? get error => _error;

  /// 특정 댓글이 재생 중인지 확인
  bool isCommentPlaying(String commentId) {
    return _isPlayingStates[commentId] ?? false;
  }

  /// 특정 댓글의 현재 재생 위치
  Duration getCommentPosition(String commentId) {
    return _currentPositions[commentId] ?? Duration.zero;
  }

  /// 특정 댓글의 총 재생 시간
  Duration getCommentDuration(String commentId) {
    return _totalDurations[commentId] ?? Duration.zero;
  }

  /// 특정 댓글의 재생 진행률 (0.0 ~ 1.0)
  double getCommentProgress(String commentId) {
    final position = getCommentPosition(commentId);
    final duration = getCommentDuration(commentId);

    if (duration == Duration.zero) return 0.0;

    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  // ==================== 기본 메서드 ====================

  /// 특정 댓글 재생
  Future<void> playComment(String commentId, String audioUrl) async {
    try {
      _setLoading(true);
      _clearError();

      debugPrint('🎵 CommentAudio - 재생 시작: $commentId');

      // 다른 댓글이 재생 중이면 중지
      if (_currentPlayingCommentId != null &&
          _currentPlayingCommentId != commentId) {
        await _stopCurrentPlaying();
      }

      // AudioPlayer 인스턴스 생성 또는 가져오기
      final player = await _getOrCreatePlayer(commentId, audioUrl);

      // 재생 시작
      await player.play(ap.UrlSource(audioUrl));

      // 상태 업데이트
      _isPlayingStates[commentId] = true;
      _currentPlayingCommentId = commentId;
      _commentAudioUrls[commentId] = audioUrl;

      debugPrint('✅ CommentAudio - 재생 시작 완료: $commentId');
    } catch (e) {
      debugPrint('❌ CommentAudio - 재생 오류: $e');
      _setError('음성 댓글을 재생할 수 없습니다: $e');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  /// 특정 댓글 일시정지
  Future<void> pauseComment(String commentId) async {
    try {
      final player = _commentPlayers[commentId];
      if (player != null) {
        await player.pause();
        _isPlayingStates[commentId] = false;

        debugPrint('⏸️ CommentAudio - 일시정지: $commentId');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ CommentAudio - 일시정지 오류: $e');
    }
  }

  /// 특정 댓글 중지
  Future<void> stopComment(String commentId) async {
    try {
      final player = _commentPlayers[commentId];
      if (player != null) {
        await player.stop();
        _isPlayingStates[commentId] = false;
        _currentPositions[commentId] = Duration.zero;

        if (_currentPlayingCommentId == commentId) {
          _currentPlayingCommentId = null;
        }

        debugPrint('⏹️ CommentAudio - 중지: $commentId');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ CommentAudio - 중지 오류: $e');
    }
  }

  /// 특정 댓글 재생/일시정지 토글
  Future<void> toggleComment(String commentId, String audioUrl) async {
    final isPlaying = isCommentPlaying(commentId);

    if (isPlaying) {
      await pauseComment(commentId);
    } else {
      await playComment(commentId, audioUrl);
    }
  }

  // ==================== Private 메서드 ====================

  /// AudioPlayer 인스턴스 생성 또는 가져오기
  Future<ap.AudioPlayer> _getOrCreatePlayer(
    String commentId,
    String audioUrl,
  ) async {
    if (_commentPlayers.containsKey(commentId)) {
      return _commentPlayers[commentId]!;
    }

    // 새 플레이어 생성
    final player = ap.AudioPlayer();
    _commentPlayers[commentId] = player;

    // 리스너 설정
    _setupPlayerListeners(commentId, player);

    return player;
  }

  /// 플레이어 리스너 설정
  void _setupPlayerListeners(String commentId, ap.AudioPlayer player) {
    // 재생 위치 변화 감지
    player.onPositionChanged.listen((Duration position) {
      _currentPositions[commentId] = position;
      notifyListeners();
    });

    // 재생 시간 변화 감지
    player.onDurationChanged.listen((Duration duration) {
      _totalDurations[commentId] = duration;
      notifyListeners();
    });

    // 재생 상태 변화 감지
    player.onPlayerStateChanged.listen((ap.PlayerState state) {
      final wasPlaying = _isPlayingStates[commentId] ?? false;
      final isNowPlaying = state == ap.PlayerState.playing;

      _isPlayingStates[commentId] = isNowPlaying;

      // 재생 완료 시 처리
      if (state == ap.PlayerState.completed) {
        _isPlayingStates[commentId] = false;
        _currentPositions[commentId] = Duration.zero;

        if (_currentPlayingCommentId == commentId) {
          _currentPlayingCommentId = null;
        }

        debugPrint('🏁 CommentAudio - 재생 완료: $commentId');
      }

      // 상태 변화가 있을 때만 알림
      if (wasPlaying != isNowPlaying) {
        notifyListeners();
      }
    });
  }

  /// 현재 재생 중인 댓글 중지
  Future<void> _stopCurrentPlaying() async {
    if (_currentPlayingCommentId != null) {
      await stopComment(_currentPlayingCommentId!);
    }
  }

  /// 로딩 상태 설정
  void _setLoading(bool loading) {
    _isLoading = loading;
  }

  /// 에러 설정
  void _setError(String error) {
    _error = error;
  }

  /// 에러 초기화
  void _clearError() {
    _error = null;
  }

  // ==================== 고급 기능 메서드 ====================

  /// 특정 위치로 이동
  Future<void> seekToPosition(String commentId, Duration position) async {
    try {
      final player = _commentPlayers[commentId];
      if (player != null) {
        await player.seek(position);
        _currentPositions[commentId] = position;

        debugPrint(
          '⏩ CommentAudio - 위치 이동: $commentId, ${position.inSeconds}초',
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ CommentAudio - 위치 이동 오류: $e');
    }
  }

  /// 재생 재개 (일시정지된 댓글 재개)
  Future<void> resumeComment(String commentId) async {
    try {
      final player = _commentPlayers[commentId];
      if (player != null && !isCommentPlaying(commentId)) {
        await player.resume();
        _isPlayingStates[commentId] = true;
        _currentPlayingCommentId = commentId;

        debugPrint('▶️ CommentAudio - 재생 재개: $commentId');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ CommentAudio - 재생 재개 오류: $e');
    }
  }

  /// 모든 댓글의 재생 상태 정보 반환
  Map<String, bool> getAllPlayingStates() {
    return Map.from(_isPlayingStates);
  }

  /// 특정 댓글의 오디오 URL 반환
  String? getCommentAudioUrl(String commentId) {
    return _commentAudioUrls[commentId];
  }

  /// 현재 로드된 댓글 수 반환
  int get loadedCommentsCount => _commentPlayers.length;

  // ==================== 정리 메서드 ====================

  /// 모든 댓글 재생 중지
  Future<void> stopAllComments() async {
    for (final commentId in _commentPlayers.keys.toList()) {
      await stopComment(commentId);
    }
  }

  /// 특정 댓글의 플레이어 해제
  Future<void> disposeCommentPlayer(String commentId) async {
    final player = _commentPlayers[commentId];
    if (player != null) {
      await player.stop();
      await player.dispose();
      _commentPlayers.remove(commentId);
      _isPlayingStates.remove(commentId);
      _currentPositions.remove(commentId);
      _totalDurations.remove(commentId);
      _commentAudioUrls.remove(commentId);

      if (_currentPlayingCommentId == commentId) {
        _currentPlayingCommentId = null;
      }

      debugPrint('🗑️ CommentAudio - 플레이어 해제: $commentId');
    }
  }

  /// 에러 상태를 사용자에게 보여주고 자동으로 클리어
  void showErrorToUser(BuildContext context) {
    if (_error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_error!),
          backgroundColor: const Color(0xFF5A5A5A),
          duration: const Duration(seconds: 3),
        ),
      );
      _clearError();
    }
  }

  @override
  void dispose() {
    // 모든 플레이어 해제
    for (final player in _commentPlayers.values) {
      player.dispose();
    }
    _commentPlayers.clear();
    _isPlayingStates.clear();
    _currentPositions.clear();
    _totalDurations.clear();
    _commentAudioUrls.clear();

    super.dispose();
  }
}
