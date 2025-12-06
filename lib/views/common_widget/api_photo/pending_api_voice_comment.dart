import 'dart:ui';

/// API 버전 Pending 음성/텍스트 댓글 상태
class PendingApiVoiceComment {
  final String? audioPath;
  final List<double>? waveformData;
  final int? duration;
  final String? text;
  final bool isTextComment;
  final Offset? relativePosition;
  final int? recorderUserId;
  final String? profileImageUrl;

  const PendingApiVoiceComment({
    this.audioPath,
    this.waveformData,
    this.duration,
    this.text,
    this.isTextComment = false,
    this.relativePosition,
    this.recorderUserId,
    this.profileImageUrl,
  });

  PendingApiVoiceComment copyWith({Offset? relativePosition}) {
    return PendingApiVoiceComment(
      audioPath: audioPath,
      waveformData: waveformData,
      duration: duration,
      text: text,
      isTextComment: isTextComment,
      relativePosition: relativePosition ?? this.relativePosition,
      recorderUserId: recorderUserId,
      profileImageUrl: profileImageUrl,
    );
  }
}
