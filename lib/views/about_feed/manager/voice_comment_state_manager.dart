import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../api/controller/comment_controller.dart';
import '../../../api/controller/media_controller.dart' as api_media;
import '../../../api/controller/user_controller.dart';
import '../../../api/models/comment.dart';
import '../../../utils/position_converter.dart';
import '../../common_widget/api_photo/pending_api_voice_comment.dart';

/// API 기반 음성/텍스트 댓글 상태 매니저
class VoiceCommentStateManager {
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

  Future<void> loadCommentsForPost(int postId, BuildContext context) async {
    try {
      final commentController = Provider.of<CommentController>(
        context,
        listen: false,
      );
      final comments = await commentController.getComments(postId: postId);
      _postComments[postId] = comments;
      _voiceCommentSavedStates[postId] = comments.isNotEmpty;
      _notifyStateChanged();
    } catch (e) {
      debugPrint('❌ 댓글 로드 실패(postId: $postId): $e');
    }
  }

  void toggleVoiceComment(int postId) {
    _voiceCommentActiveStates[postId] =
        !(_voiceCommentActiveStates[postId] ?? false);
    _notifyStateChanged();
  }

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

    _pendingVoiceComments[postId] = PendingApiVoiceComment(
      text: text.trim(),
      isTextComment: true,
      recorderUserId: currentUser.id,
      profileImageUrl: currentUser.profileImageUrlKey,
    );
    _pendingTextComments[postId] = true;
    _voiceCommentSavedStates[postId] = false;
    _voiceCommentActiveStates[postId] = true;
    _notifyStateChanged();
  }

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

    _pendingVoiceComments[postId] = PendingApiVoiceComment(
      audioPath: audioPath,
      waveformData: waveformData,
      duration: duration,
      recorderUserId: currentUser.id,
      profileImageUrl: currentUser.profileImageUrlKey,
    );
    _pendingTextComments.remove(postId);
    _voiceCommentActiveStates[postId] = true;
    _voiceCommentSavedStates[postId] = false;
    _notifyStateChanged();
  }

  void onProfileImageDragged(int postId, Offset absolutePosition) {
    final imageSize = Size(354.w, 500.h);
    final relativePosition = PositionConverter.toRelativePosition(
      absolutePosition,
      imageSize,
    );

    final pending = _pendingVoiceComments[postId];
    if (pending != null) {
      _pendingVoiceComments[postId] = pending.copyWith(
        relativePosition: relativePosition,
      );
      _notifyStateChanged();
    }
  }

  Future<void> saveVoiceComment(int postId, BuildContext context) async {
    final pending = _pendingVoiceComments[postId];
    if (pending == null) {
      throw StateError('임시 댓글을 찾을 수 없습니다. postId: $postId');
    }

    final userId = pending.recorderUserId;
    if (userId == null) {
      throw StateError('로그인된 사용자를 찾을 수 없습니다.');
    }

    final finalPosition =
        pending.relativePosition ?? _generateAutoProfilePosition(postId);
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
    _pendingVoiceComments.remove(postId);
    _pendingTextComments.remove(postId);
    _voiceCommentActiveStates[postId] = false;
    _notifyStateChanged();

    await _saveCommentToServer(postId, userId, pendingCopy, context);
  }

  Future<void> _saveCommentToServer(
    int postId,
    int userId,
    PendingApiVoiceComment pending,
    BuildContext context,
  ) async {
    try {
      final commentController = Provider.of<CommentController>(
        context,
        listen: false,
      );

      bool success = false;

      if (pending.isTextComment && pending.text != null) {
        success = await commentController.createTextComment(
          postId: postId,
          userId: userId,
          text: pending.text!,
          locationX: pending.relativePosition?.dx,
          locationY: pending.relativePosition?.dy,
        );
      } else if (pending.audioPath != null) {
        final mediaController = Provider.of<api_media.MediaController>(
          context,
          listen: false,
        );
        final audioFile = File(pending.audioPath!);
        final multipartFile = await mediaController.fileToMultipart(audioFile);

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
          return;
        }

        String? waveformJson;
        if (pending.waveformData != null) {
          final roundedWaveform = pending.waveformData!
              .map((value) => double.parse(value.toStringAsFixed(4)))
              .toList();
          waveformJson = jsonEncode(roundedWaveform);
        }

        success = await commentController.createAudioComment(
          postId: postId,
          userId: userId,
          audioKey: audioKey,
          waveformData: waveformJson,
          duration: pending.duration,
          locationX: pending.relativePosition?.dx,
          locationY: pending.relativePosition?.dy,
        );
      }

      if (success) {
        await loadCommentsForPost(postId, context);
      } else {
        _showSnackBar(
          context,
          '댓글 저장에 실패했습니다.',
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      debugPrint('댓글 저장 실패(postId: $postId): $e');
      _showSnackBar(
        context,
        '댓글 저장 중 오류가 발생했습니다.',
        backgroundColor: Colors.red,
      );
    }
  }

  void onVoiceCommentDeleted(int postId) {
    _voiceCommentActiveStates[postId] = false;
    _voiceCommentSavedStates[postId] = false;
    _pendingVoiceComments.remove(postId);
    _pendingTextComments.remove(postId);
    _notifyStateChanged();
  }

  void onSaveCompleted(int postId) {
    _voiceCommentActiveStates[postId] = false;
    _pendingVoiceComments.remove(postId);
    _pendingTextComments.remove(postId);
    _notifyStateChanged();
  }

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

    final pending = _pendingVoiceComments[postId];
    if (pending?.relativePosition != null) {
      occupiedPositions.add(pending!.relativePosition!);
    }

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
