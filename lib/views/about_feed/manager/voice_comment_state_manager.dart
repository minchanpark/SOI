import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../api/controller/comment_controller.dart';
import '../../../api/controller/media_controller.dart' as api_media;
import '../../../api/controller/user_controller.dart';
import '../../../api/models/comment.dart';
import '../../../api/models/comment_creation_result.dart';
import '../../../utils/position_converter.dart';
import '../../common_widget/api_photo/pending_api_voice_comment.dart';

/// API 기반 음성/텍스트 댓글 상태 매니저
/// 각 게시물별로 음성/텍스트 댓글의 활성화 상태, 저장 상태, 대기 중인 댓글 등을 관리
///
/// Parameters:
///   - [voiceCommentActiveStates]: 게시물 ID별 음성/텍스트 댓글 활성화 상태 맵
///   - [voiceCommentSavedStates]: 게시물 ID별 음성/텍스트 댓글 저장 상태 맵
///   - [pendingVoiceComments]: 게시물 ID별 대기 중인 음성/텍스트 댓글 맵
///   - [postComments]: 게시물 ID별 댓글 목록 맵
///   - [pendingTextComments]: 게시물 ID별 대기 중인 텍스트 댓글 상태 맵
///   - [autoPlacementIndices]: 게시물 ID별 자동 배치 인덱스 맵
///   - [onStateChanged]: 상태 변경 시 호출되는 콜백 함수
class VoiceCommentStateManager {
  static const int _kMaxWaveformSamples = 30;
  final Map<int, bool> _voiceCommentActiveStates = {};
  final Map<int, bool> _voiceCommentSavedStates = {};
  final Map<int, PendingApiVoiceComment> _pendingVoiceComments = {};
  final Map<int, List<Comment>> _postComments = {};
  final Map<int, bool> _pendingTextComments = {};
  final Map<int, int> _autoPlacementIndices = {};

  VoidCallback? _onStateChanged;

  Map<int, bool> get voiceCommentActiveStates => _voiceCommentActiveStates;
  Map<int, bool> get voiceCommentSavedStates => _voiceCommentSavedStates;
  Map<int, PendingApiVoiceComment> get pendingVoiceComments =>
      _pendingVoiceComments;
  Map<int, List<Comment>> get postComments => _postComments;
  Map<int, bool> get pendingTextComments => _pendingTextComments;

  void setOnStateChanged(VoidCallback? callback) {
    _onStateChanged = callback;
  }

  void _notifyStateChanged() {
    _onStateChanged?.call();
  }

  /// 댓글을 특정 게시물에 대해 로드하는 메서드
  Future<void> loadCommentsForPost(int postId, BuildContext context) async {
    try {
      // 댓글 컨트롤러 가져오기
      final commentController = Provider.of<CommentController>(
        context,
        listen: false,
      );
      // 댓글 불러오기
      final comments = await commentController.getComments(postId: postId);

      // 불러온 댓글 저장
      _postComments[postId] = comments;

      // 저장된 댓글이 있는지 여부 업데이트
      _voiceCommentSavedStates[postId] = comments.isNotEmpty;
      _notifyStateChanged();
    } catch (e) {
      debugPrint('댓글 로드 실패(postId: $postId): $e');
    }
  }

  /// 음성/텍스트 댓글 활성화 상태 토글 메서드
  void toggleVoiceComment(int postId) {
    final newValue = !(_voiceCommentActiveStates[postId] ?? false);
    _voiceCommentActiveStates[postId] = newValue;
    if (!newValue) {
      _clearPendingState(postId);
    }
    _notifyStateChanged();
  }

  /// 텍스트 댓글이 완료되었을 때 호출되는 메서드
  Future<void> onTextCommentCompleted(
    int postId,
    String text,
    UserController userController,
  ) async {
    if (text.trim().isEmpty) {
      debugPrint('[VoiceCommentStateManager] text is empty');
      return;
    }
    final currentUser = userController.currentUser;
    if (currentUser == null) {
      debugPrint('[VoiceCommentStateManager] current user is null');
      return;
    }

    // 텍스트 댓글 대기 상태 설정
    _pendingVoiceComments[postId] = PendingApiVoiceComment(
      text: text.trim(),
      isTextComment: true,
      recorderUserId: currentUser.id,
      profileImageUrl: currentUser.profileImageUrlKey,
    );

    // 텍스트 댓글 대기 상태 설정
    _pendingTextComments[postId] = true;

    // 저장된 댓글 상태 업데이트
    _voiceCommentSavedStates[postId] = false;

    // 상태 변경 알림
    _notifyStateChanged();
  }

  /// 음성 댓글이 완료되었을 때 호출되는 메서드
  Future<void> onVoiceCommentCompleted(
    int postId,
    String? audioPath,
    List<double>? waveformData,
    int? duration,
    UserController userController,
  ) async {
    if (audioPath == null || waveformData == null || duration == null) {
      debugPrint('[VoiceCommentStateManager] invalid audio comment payload');
      return;
    }
    final currentUser = userController.currentUser;
    if (currentUser == null) {
      debugPrint('[VoiceCommentStateManager] current user is null');
      return;
    }

    // 음성 댓글 대기 상태 설정
    _pendingVoiceComments[postId] = PendingApiVoiceComment(
      audioPath: audioPath,
      waveformData: waveformData,
      duration: duration,
      recorderUserId: currentUser.id,
      profileImageUrl: currentUser.profileImageUrlKey,
    );

    // 저장된 댓글 상태 업데이트
    _pendingTextComments.remove(postId);

    // 저장된 댓글 상태 업데이트
    _voiceCommentSavedStates[postId] = false;

    // 상태 변경 알림
    _notifyStateChanged();
  }

  /// 프로필 이미지 위치가 드래그로 변경되었을 때 호출되는 메서드
  void onProfileImageDragged(int postId, Offset absolutePosition) {
    final imageSize = Size(354.w, 500.h);

    // 절대 위치를 상대 위치로 변환
    final relativePosition = PositionConverter.toRelativePosition(
      absolutePosition,
      imageSize,
    );

    // 대기 중인 댓글의 위치 업데이트
    final pending = _pendingVoiceComments[postId];
    if (pending != null) {
      _pendingVoiceComments[postId] = pending.copyWith(
        relativePosition: relativePosition,
      );

      // 상태 변경 알림
      _notifyStateChanged();
    }
  }

  /// 음성/텍스트 댓글을 서버에 저장하는 메서드
  Future<void> saveVoiceComment(int postId, BuildContext context) async {
    // 대기 중인 댓글 가져오기
    final pending = _pendingVoiceComments[postId];
    if (pending == null) {
      throw StateError('임시 댓글을 찾을 수 없습니다. postId: $postId');
    }

    // 로그인된 사용자 ID 가져오기
    final userId = pending.recorderUserId;
    if (userId == null) {
      throw StateError('로그인된 사용자를 찾을 수 없습니다.');
    }

    // 최종 위치 결정
    final finalPosition =
        pending.relativePosition ?? _generateAutoProfilePosition(postId);

    // 최종 위치가 지정되지 않은 경우 자동 배치 위치 생성
    final pendingCopy = PendingApiVoiceComment(
      audioPath: pending.audioPath,
      waveformData: pending.waveformData,
      duration: pending.duration,
      text: pending.text,
      isTextComment: pending.isTextComment,
      relativePosition: finalPosition,
      recorderUserId: pending.recorderUserId,
      profileImageUrl: pending.profileImageUrl,
    );

    _voiceCommentSavedStates[postId] = true;
    _pendingVoiceComments[postId] = pendingCopy;
    _pendingTextComments.remove(postId);
    _voiceCommentActiveStates[postId] = false;
    _notifyStateChanged();

    // 비동기적으로 서버에 댓글 저장
    // UI 스레드를 차단하지 않도록 함
    Future.microtask(() async {
      final didSave = await _saveCommentToServer(
        postId,
        userId,
        pendingCopy,
        context,
      );

      if (!didSave) {
        _voiceCommentSavedStates[postId] = false;
        _notifyStateChanged();
        return;
      }

      // 저장이 성공하면 대기 중인 댓글 제거
      _pendingVoiceComments.remove(postId);

      // 상태 변경 알림
      _notifyStateChanged();
    });
  }

  /// 댓글을 서버에 저장하는 내부 메서드
  Future<bool> _saveCommentToServer(
    int postId,
    int userId,
    PendingApiVoiceComment pending,
    BuildContext context,
  ) async {
    try {
      // 댓글 컨트롤러 가져오기
      final commentController = Provider.of<CommentController>(
        context,
        listen: false,
      );

      CommentCreationResult creationResult =
          const CommentCreationResult.failure();

      if (pending.isTextComment && pending.text != null) {
        // 텍스트 댓글 저장하고 그 결과를 success에 할당
        creationResult = await commentController.createTextComment(
          postId: postId,
          userId: userId,
          text: pending.text!,
          locationX: pending.relativePosition!.dx,
          locationY: pending.relativePosition!.dy,
        );
      } else if (pending.audioPath != null) {
        // media 컨트롤러 가져오기
        final mediaController = Provider.of<api_media.MediaController>(
          context,
          listen: false,
        );
        // 오디오 파일 객체 생성 --> Stirng으로 되어있는 경로를 File 객체로 변환
        final audioFile = File(pending.audioPath!);

        // 파일을 멀티파트로 변환 --> 서버 업로드를 위해
        final multipartFile = await mediaController.fileToMultipart(audioFile);

        // 오디오 업로드하고 그 키를 받아옴
        final audioKey = await mediaController.uploadCommentAudio(
          file: multipartFile,
          userId: userId,
          postId: postId,
        );

        if (audioKey == null) {
          _showSnackBar(
            context,
            '음성 업로드에 실패했습니다.',
            backgroundColor: Colors.red,
          );
          return false;
        }

        // 파형 데이터를 JSON 문자열로 변환 (서버 제한을 고려해 축소)
        final waveformJson = _encodeWaveformForRequest(pending.waveformData);

        // 오디오 댓글 생성하고 그 결과를 success에 할당
        creationResult = await commentController.createAudioComment(
          postId: postId,
          userId: userId,
          audioFileKey: audioKey,
          waveformData: waveformJson!,
          duration: pending.duration!,
          locationX: pending.relativePosition!.dx,
          locationY: pending.relativePosition!.dy,
        );
      }

      if (creationResult.success) {
        if (creationResult.comment != null) {
          _addCommentToCache(postId, creationResult.comment!);
        } else {
          await loadCommentsForPost(postId, context);
        }
        return true;
      }

      _showSnackBar(context, '댓글 저장에 실패했습니다.', backgroundColor: Colors.red);
      return false;
    } catch (e) {
      debugPrint('댓글 저장 실패(postId: $postId): $e');
      _showSnackBar(
        context,
        '댓글 저장 중 오류가 발생했습니다.',
        backgroundColor: Colors.red,
      );
      return false;
    }
  }

  void _addCommentToCache(int postId, Comment comment) {
    final existing = List<Comment>.from(_postComments[postId] ?? const []);
    existing.add(comment);
    _postComments[postId] = existing;
    _voiceCommentSavedStates[postId] = true;
    _notifyStateChanged();
  }

  /// 음성/텍스트 댓글이 삭제되었을 때 호출되는 메서드
  void onVoiceCommentDeleted(int postId) {
    _voiceCommentActiveStates[postId] = false;
    _voiceCommentSavedStates[postId] = false;
    _clearPendingState(postId);
    _notifyStateChanged();
  }

  /// 음성/텍스트 댓글이 저장이 완료되었을 때 호출되는 메서드
  void onSaveCompleted(int postId) {
    _voiceCommentActiveStates[postId] = false;
    _clearPendingState(postId);
    _notifyStateChanged();
  }

  /// 자동 배치 위치 생성기
  Offset _generateAutoProfilePosition(int postId) {
    final occupiedPositions = <Offset>[];
    final comments = _postComments[postId] ?? const <Comment>[];

    for (final comment in comments) {
      if (comment.hasLocation) {
        occupiedPositions.add(
          Offset(comment.locationX ?? 0.5, comment.locationY ?? 0.5),
        );
      }
    }

    // 현재 대기 중인 댓글의 위치도 포함
    final pending = _pendingVoiceComments[postId];
    if (pending?.relativePosition != null) {
      occupiedPositions.add(pending!.relativePosition!);
    }

    // 자동 배치 패턴
    const pattern = [
      Offset(0.5, 0.5),
      Offset(0.62, 0.5),
      Offset(0.38, 0.5),
      Offset(0.5, 0.62),
      Offset(0.5, 0.38),
      Offset(0.62, 0.62),
      Offset(0.38, 0.62),
      Offset(0.62, 0.38),
      Offset(0.38, 0.38),
    ];

    const maxAttempts = 30;
    final patternLength = pattern.length;
    final startingIndex = _autoPlacementIndices[postId] ?? 0;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final rawIndex = startingIndex + attempt;
      final baseOffset = pattern[rawIndex % patternLength];
      final loop = rawIndex ~/ patternLength;
      final candidate = _applyJitter(baseOffset, loop, attempt);

      if (!_isPositionTooClose(candidate, occupiedPositions)) {
        _autoPlacementIndices[postId] = rawIndex + 1;
        return candidate;
      }
    }

    _autoPlacementIndices[postId] = startingIndex + 1;
    return const Offset(0.5, 0.5);
  }

  ///
  Offset _applyJitter(Offset base, int loop, int attempt) {
    if (loop <= 0) {
      return _clampOffset(base);
    }
    final step = (0.02 * loop).clamp(0.02, 0.08).toDouble();
    final dxDirection = (attempt % 2 == 0) ? 1 : -1;
    final dyDirection = ((attempt ~/ 2) % 2 == 0) ? 1 : -1;

    final offsetWithJitter = Offset(
      base.dx + (step * dxDirection),
      base.dy + (step * dyDirection),
    );

    return _clampOffset(offsetWithJitter);
  }

  Offset _clampOffset(Offset offset) {
    const min = 0.05;
    const max = 0.95;
    return Offset(
      offset.dx.clamp(min, max).toDouble(),
      offset.dy.clamp(min, max).toDouble(),
    );
  }

  bool _isPositionTooClose(Offset candidate, List<Offset> occupied) {
    const threshold = 0.04;
    for (final existing in occupied) {
      if ((candidate.dx - existing.dx).abs() < threshold &&
          (candidate.dy - existing.dy).abs() < threshold) {
        return true;
      }
    }
    return false;
  }

  void dispose() {
    _pendingVoiceComments.clear();
    _pendingTextComments.clear();
    _postComments.clear();
  }

  void _clearPendingState(int postId) {
    _pendingVoiceComments.remove(postId);
    _pendingTextComments.remove(postId);
  }

  // 음성 파형 데이터를 서버 요청용으로 인코딩
  // (샘플링 및 JSON 인코딩)
  String? _encodeWaveformForRequest(List<double>? waveformData) {
    if (waveformData == null || waveformData.isEmpty) return null;
    final sampled = _sampleWaveformData(waveformData, _kMaxWaveformSamples);
    final rounded = sampled
        .map((value) => double.parse(value.toStringAsFixed(4)))
        .toList();
    return jsonEncode(rounded);
  }

  // 파형 데이터 샘플링
  // (최대 길이로 샘플링하여 데이터 크기 축소)
  List<double> _sampleWaveformData(List<double> source, int maxLength) {
    if (source.length <= maxLength) return source;
    final step = source.length / maxLength;
    return List<double>.generate(
      maxLength,
      (index) => source[(index * step).floor()],
    );
  }

  void _showSnackBar(
    BuildContext context,
    String message, {
    Color? backgroundColor,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? const Color(0xFF5A5A5A),
      ),
    );
  }
}
