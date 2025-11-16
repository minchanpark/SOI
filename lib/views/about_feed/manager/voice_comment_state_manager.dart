import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../api_firebase/controllers/auth_controller.dart';
import '../../../api_firebase/controllers/comment_record_controller.dart';
import '../../../api_firebase/models/comment_record_model.dart';
import '../../../utils/position_converter.dart';

/// 보류 중인 음성 댓글 정보를 담는 단순 데이터 객체
class PendingVoiceComment {
  final String? audioPath;
  final List<double>? waveformData;
  final int? duration;
  final String? text; // 텍스트 댓글용
  final bool isTextComment; // 텍스트 댓글 여부
  final Offset? relativePosition;
  final String? recorderUserId;
  final String? profileImageUrl;

  const PendingVoiceComment({
    this.audioPath,
    this.waveformData,
    this.duration,
    this.text,
    this.isTextComment = false,
    this.relativePosition,
    this.recorderUserId,
    this.profileImageUrl,
  });

  PendingVoiceComment withPosition(Offset? position) {
    return PendingVoiceComment(
      audioPath: audioPath,
      waveformData: waveformData,
      duration: duration,
      text: text,
      isTextComment: isTextComment,
      relativePosition: position,
      recorderUserId: recorderUserId,
      profileImageUrl: profileImageUrl,
    );
  }
}

class VoiceCommentStateManager {
  // 음성 댓글 상태 관리 (다중 댓글 지원)
  final Map<String, bool> _voiceCommentActiveStates = {};
  final Map<String, bool> _voiceCommentSavedStates = {};

  // 사진별 여러 댓글 ID 저장
  final Map<String, List<String>> _savedCommentIds = {};

  // 임시 음성 댓글 데이터 (파형 클릭 시 저장용)
  final Map<String, PendingVoiceComment> _pendingVoiceComments = {};

  // 실시간 스트림 관리
  final Map<String, List<CommentRecordModel>> _photoComments = {};
  final Map<String, StreamSubscription<List<CommentRecordModel>>>
  _commentStreams = {};

  // Getters
  Map<String, bool> get voiceCommentActiveStates => _voiceCommentActiveStates;
  Map<String, bool> get voiceCommentSavedStates => _voiceCommentSavedStates;
  Map<String, List<String>> get savedCommentIds => _savedCommentIds;
  Map<String, List<CommentRecordModel>> get photoComments => _photoComments;
  Map<String, PendingVoiceComment> get pendingVoiceComments =>
      _pendingVoiceComments;

  /// Pending 댓글이 있는지 확인
  bool hasPendingComment(String photoId) {
    return _pendingVoiceComments.containsKey(photoId);
  }

  /// Pending 댓글이 텍스트 댓글인지 확인
  bool isPendingTextComment(String photoId) {
    final pending = _pendingVoiceComments[photoId];
    return pending?.isTextComment ?? false;
  }

  /// Pending 텍스트 댓글 맵 (photoId -> isPendingText)
  Map<String, bool> get pendingTextComments {
    final Map<String, bool> result = {};
    _pendingVoiceComments.forEach((photoId, pending) {
      result[photoId] = pending.isTextComment;
    });
    return result;
  }

  // 콜백 함수들
  VoidCallback? _onStateChanged;

  void setOnStateChanged(VoidCallback? callback) {
    _onStateChanged = callback;
  }

  void _notifyStateChanged() {
    _onStateChanged?.call();
  }

  /// 음성 댓글 토글
  void toggleVoiceComment(String photoId) {
    _voiceCommentActiveStates[photoId] =
        !(_voiceCommentActiveStates[photoId] ?? false);

    _notifyStateChanged();
  }

  /// 음성 댓글 녹음 완료 콜백 (임시 저장)
  Future<void> onVoiceCommentCompleted(
    String photoId,
    String? audioPath,
    List<double>? waveformData,
    int? duration, {
    String? recorderUserId,
    String? profileImageUrl,
  }) async {
    if (audioPath == null || waveformData == null || duration == null) {
      return;
    }

    // 임시 저장 (파형 클릭 시 실제 저장)
    _pendingVoiceComments[photoId] = PendingVoiceComment(
      audioPath: audioPath,
      waveformData: waveformData,
      duration: duration,
      isTextComment: false,
      recorderUserId: recorderUserId,
      profileImageUrl: profileImageUrl,
    );
    _notifyStateChanged();
  }

  /// 텍스트 댓글 완료 콜백 (임시 저장)
  Future<void> onTextCommentCompleted(
    String photoId,
    String text, {
    String? recorderUserId,
    String? profileImageUrl,
  }) async {
    if (text.isEmpty) {
      debugPrint('⚠️ [StateManager] 텍스트가 비어있음');
      return;
    }

    // 임시 저장 (프로필 위치 지정 후 실제 저장)
    _pendingVoiceComments[photoId] = PendingVoiceComment(
      text: text,
      isTextComment: true,
      recorderUserId: recorderUserId,
      profileImageUrl: profileImageUrl,
    );

    _notifyStateChanged();
  }

  /// 실제 음성 댓글 저장 (파형 클릭 시 호출)
  Future<void> saveVoiceComment(String photoId, BuildContext context) async {
    final pendingComment = _pendingVoiceComments[photoId];
    if (pendingComment == null) {
      throw StateError('임시 음성 댓글 데이터를 찾을 수 없습니다. photoId: $photoId');
    }

    try {
      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final commentRecordController = CommentRecordController();
      final currentUserId = authController.getUserId;

      if (currentUserId == null || currentUserId.isEmpty) {
        throw Exception('로그인된 사용자를 찾을 수 없습니다.');
      }

      final profileImageUrl = await authController
          .getUserProfileImageUrlWithCache(currentUserId);

      // Pending comment already has the position
      final currentProfilePosition = pendingComment.relativePosition;

      if (currentProfilePosition == null) {
        throw StateError('음성 댓글 저장 위치를 찾을 수 없습니다. photoId: $photoId');
      }

      CommentRecordModel? commentRecord;

      // 텍스트 댓글과 음성 댓글 구분하여 저장
      if (pendingComment.isTextComment) {
        if (pendingComment.text == null || pendingComment.text!.isEmpty) {
          throw Exception('텍스트 댓글 내용이 비어있습니다.');
        }
        commentRecord = await commentRecordController.createTextComment(
          text: pendingComment.text!,
          photoId: photoId,
          recorderUser: currentUserId,
          profileImageUrl: profileImageUrl,
          relativePosition: currentProfilePosition,
        );
      } else {
        if (pendingComment.audioPath == null ||
            pendingComment.waveformData == null ||
            pendingComment.duration == null) {
          throw Exception('음성 댓글 데이터가 유효하지 않습니다.');
        }
        commentRecord = await commentRecordController.createCommentRecord(
          audioFilePath: pendingComment.audioPath!,
          photoId: photoId,
          recorderUser: currentUserId,
          waveformData: pendingComment.waveformData!,
          duration: pendingComment.duration!,
          profileImageUrl: profileImageUrl,
          relativePosition: currentProfilePosition,
        );
      }

      if (commentRecord == null) {
        if (context.mounted) {
          commentRecordController.showErrorToUser(context);
        }
        throw Exception('댓글 저장에 실패했습니다. photoId: $photoId');
      }

      _voiceCommentSavedStates[photoId] = true;

      // 다중 댓글 지원: 기존 댓글 목록에 새 댓글 추가 (중복 방지)
      if (_savedCommentIds[photoId] == null) {
        _savedCommentIds[photoId] = [commentRecord.id];
      } else {
        // 중복 확인 후 추가
        if (!_savedCommentIds[photoId]!.contains(commentRecord.id)) {
          _savedCommentIds[photoId]!.add(commentRecord.id);
        }
      }

      // 임시 데이터 삭제
      _pendingVoiceComments.remove(photoId);

      _notifyStateChanged();
    } catch (e) {
      debugPrint("댓글 저장 중 오류 발생: $e");
      rethrow;
    }
  }

  /// 음성 댓글 삭제 콜백
  void onVoiceCommentDeleted(String photoId) {
    _voiceCommentActiveStates[photoId] = false;
    _voiceCommentSavedStates[photoId] = false;
    _notifyStateChanged();
  }

  /// 음성 댓글 저장 완료 후 위젯 초기화 (추가 댓글을 위한)
  void onSaveCompleted(String photoId) {
    // 저장 완료 후 다시 버튼 상태로 돌아가서 추가 댓글 녹음 가능
    _voiceCommentActiveStates[photoId] = false;

    // 임시 데이터 정리
    _pendingVoiceComments.remove(photoId);
    _notifyStateChanged();
  }

  /// 프로필 이미지 드래그 처리 (절대 위치를 상대 위치로 변환하여 저장)
  void onProfileImageDragged(String photoId, Offset absolutePosition) {
    // 이미지 크기 (ScreenUtil 기준 - PhotoDisplayWidget과 동일하게)
    final imageSize = Size(354.w, 500.h);

    // 절대 위치를 상대 위치로 변환 (0.0 ~ 1.0 범위)
    final relativePosition = PositionConverter.toRelativePosition(
      absolutePosition,
      imageSize,
    );

    // UI에 즉시 반영 (임시 위치) - stored in pendingComment
    final pendingComment = _pendingVoiceComments[photoId];
    if (pendingComment != null) {
      _pendingVoiceComments[photoId] = pendingComment.withPosition(
        relativePosition,
      );
      _notifyStateChanged();
      // 저장 전 위치만 갱신하고 종료
      return;
    }

    _notifyStateChanged();

    // 음성 댓글이 이미 저장된 경우에만 즉시 Firestore 업데이트
    if (_voiceCommentSavedStates[photoId] == true) {
      final commentIds = _savedCommentIds[photoId];
      if (commentIds != null && commentIds.isNotEmpty) {
        _updateProfilePositionInFirestore(
          photoId,
          relativePosition,
          commentIds.last,
        );
      }
    }
  }

  /// 특정 사진의 음성 댓글 정보를 실시간 구독하여 프로필 위치 동기화
  void subscribeToVoiceCommentsForPhoto(String photoId, String currentUserId) {
    try {
      _commentStreams[photoId]?.cancel();

      _commentStreams[photoId] = CommentRecordController()
          .getCommentRecordsStream(photoId)
          .listen(
            (comments) =>
                _handleCommentsUpdate(photoId, currentUserId, comments),
          );

      // 실시간 스트림과 별개로 기존 댓글도 직접 로드
      _loadExistingCommentsForPhoto(photoId, currentUserId);
    } catch (e) {
      debugPrint('Feed - 실시간 댓글 구독 시작 실패 - 사진 $photoId: $e');
    }
  }

  /// 특정 사진의 기존 댓글을 직접 로드 (실시간 스트림과 별개)
  Future<void> _loadExistingCommentsForPhoto(
    String photoId,
    String currentUserId,
  ) async {
    try {
      final commentController = CommentRecordController();
      await commentController.loadCommentRecordsByPhotoId(photoId);
      final comments = commentController.getCommentsByPhotoId(photoId);

      if (comments.isNotEmpty) {
        _handleCommentsUpdate(photoId, currentUserId, comments);
      }
    } catch (e) {
      debugPrint('Feed - 기존 댓글 직접 로드 실패: $e');
    }
  }

  /// 댓글 업데이트 처리 (다중 댓글 지원)
  void _handleCommentsUpdate(
    String photoId,
    String currentUserId,
    List<CommentRecordModel> comments,
  ) {
    _photoComments[photoId] = comments;

    // 현재 사용자의 모든 댓글 처리 (다중 댓글 지원)
    final userComments = comments
        .where((comment) => comment.recorderUser == currentUserId)
        .toList();

    if (userComments.isNotEmpty) {
      // 사진별 댓글 ID 목록 업데이트 (중복 방지)
      final mergedIds = <String>[
        ...(_savedCommentIds[photoId] ?? const <String>[]),
        ...userComments.map((c) => c.id),
      ];

      _savedCommentIds[photoId] = mergedIds.toSet().toList();

      // 각 댓글은 자신의 위치를 relativePosition 필드에 저장
      // 별도로 위치를 추출하거나 저장할 필요 없음
    } else {
      // 현재 사용자의 댓글이 없는 경우 상태 초기화
      _voiceCommentSavedStates[photoId] = false;

      // 다른 사용자의 댓글은 유지하되 현재 사용자 관련 상태만 초기화
      if (comments.isEmpty) {
        _photoComments[photoId] = [];
      }
    }

    _notifyStateChanged();
  }

  /// Firestore에 프로필 위치 업데이트
  Future<void> _updateProfilePositionInFirestore(
    String photoId,
    Offset position,
    String targetCommentId,
  ) async {
    if (targetCommentId.isEmpty) {
      return;
    }

    try {
      final success = await CommentRecordController()
          .updateRelativeProfilePosition(
            commentId: targetCommentId,
            photoId: photoId,
            relativePosition: position,
          );

      if (success) {
        // Position updated in Firestore comment
        _notifyStateChanged();
      }
    } catch (e) {
      debugPrint('음성 댓글 위치 업데이트 실패: $e');
    }
  }

  // 리소스 정리
  void dispose() {
    for (var subscription in _commentStreams.values) {
      subscription.cancel();
    }
    _commentStreams.clear();
  }
}
