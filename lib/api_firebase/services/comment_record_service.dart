import 'dart:io';
import 'package:flutter/material.dart';
import '../models/comment_record_model.dart';
import '../repositories/comment_record_repository.dart';
import 'notification_service.dart';

class CommentRecordService {
  // Singleton pattern
  static final CommentRecordService _instance =
      CommentRecordService._internal();
  factory CommentRecordService() => _instance;
  CommentRecordService._internal();

  final CommentRecordRepository _repository = CommentRecordRepository();

  // Lazy initialization으로 순환 의존성 방지
  NotificationService? _notificationService;
  NotificationService get notificationService {
    _notificationService ??= NotificationService();
    return _notificationService!;
  }

  /// 음성 댓글 생성 (유효성 검사 포함)
  Future<CommentRecordModel> createCommentRecord({
    required String audioFilePath,
    required String photoId,
    required String recorderUser,
    required List<double> waveformData,
    required int duration,
    required String profileImageUrl, // 프로필 이미지 URL 추가
    Offset? relativePosition, // 프로필 이미지 상대 위치 (새로운 방식)
  }) async {
    // 1. 입력값 유효성 검사
    _validateInputs(
      audioFilePath: audioFilePath,
      photoId: photoId,
      recorderUser: recorderUser,
      waveformData: waveformData,
      duration: duration,
    );

    // 2. 파일 존재 여부 확인
    await _validateAudioFile(audioFilePath);

    // 3. Repository를 통해 저장
    try {
      final result = await _repository.createCommentRecord(
        audioFilePath: audioFilePath,
        photoId: photoId,
        recorderUser: recorderUser,
        waveformData: waveformData,
        duration: duration,
        profileImageUrl: profileImageUrl, // 프로필 이미지 URL 전달
        relativePosition: relativePosition, // 상대 위치 전달 (새로운 방식)
      );

      // 4. 음성 댓글 알림 생성
      try {
        await notificationService.createVoiceCommentNotification(
          photoId: photoId,
          commentId: result.id,
          actorUserId: recorderUser,
        );
      } catch (e) {
        // 알림 생성 실패는 전체 댓글 생성을 실패시키지 않음
        debugPrint('⚠️ 알림 생성 실패 (댓글 생성은 성공): $e');
      }

      return result;
    } catch (e) {
      throw ServiceException('음성 댓글 생성 실패', originalError: e);
    }
  }

  /// 텍스트 댓글 생성
  Future<CommentRecordModel> createTextComment({
    required String text,
    required String photoId,
    required String recorderUser,
    required String profileImageUrl,
    Offset? relativePosition,
  }) async {
    // 1. 입력값 유효성 검사
    if (text.trim().isEmpty) {
      throw ServiceException('댓글 내용을 입력해주세요');
    }
    if (photoId.isEmpty) {
      throw ServiceException('유효하지 않은 사진 ID입니다');
    }
    if (recorderUser.isEmpty) {
      throw ServiceException('유효하지 않은 사용자 ID입니다');
    }

    // 2. Repository를 통해 저장
    try {
      final result = await _repository.createTextComment(
        text: text,
        photoId: photoId,
        recorderUser: recorderUser,
        profileImageUrl: profileImageUrl,
        relativePosition: relativePosition,
      );

      // 3. 텍스트 댓글 알림 생성
      try {
        await notificationService.createVoiceCommentNotification(
          photoId: photoId,
          commentId: result.id,
          actorUserId: recorderUser,
        );
      } catch (e) {
        debugPrint('⚠️ 알림 생성 실패 (댓글 생성은 성공): $e');
      }

      return result;
    } catch (e) {
      throw ServiceException('텍스트 댓글 생성 실패', originalError: e);
    }
  }

  /// 특정 사진의 음성 댓글들 조회
  Future<List<CommentRecordModel>> getCommentRecordsByPhotoId(
    String photoId,
  ) async {
    if (photoId.isEmpty) {
      throw ServiceException('유효하지 않은 사진 ID입니다');
    }

    try {
      final result = await _repository.getCommentRecordsByPhotoId(photoId);

      return result;
    } catch (e) {
      throw ServiceException('음성 댓글 조회 실패', originalError: e);
    }
  }

  /// 음성 댓글 삭제
  Future<void> deleteCommentRecord(String commentId) async {
    if (commentId.isEmpty) {
      throw ServiceException('유효하지 않은 댓글 ID입니다');
    }

    try {
      await _repository.deleteCommentRecord(commentId);
    } catch (e) {
      throw ServiceException('음성 댓글 삭제 실패', originalError: e);
    }
  }

  /// 음성 댓글 하드 삭제 (문서 + 스토리지 파일)
  Future<void> hardDeleteCommentRecord(String commentId) async {
    if (commentId.isEmpty) {
      throw ServiceException('유효하지 않은 댓글 ID입니다');
    }
    try {
      await _repository.hardDeleteCommentRecord(commentId);
    } catch (e) {
      throw ServiceException('음성 댓글 하드 삭제 실패', originalError: e);
    }
  }

  /// 사용자별 음성 댓글들 조회
  Future<List<CommentRecordModel>> getCommentRecordsByUser(
    String userId,
  ) async {
    if (userId.isEmpty) {
      throw ServiceException('유효하지 않은 사용자 ID입니다');
    }

    try {
      return await _repository.getCommentRecordsByUser(userId);
    } catch (e) {
      throw ServiceException('사용자 음성 댓글 조회 실패', originalError: e);
    }
  }

  /// 프로필 이미지 위치 업데이트 (상대 좌표)
  Future<void> updateRelativeProfilePosition({
    required String commentId,
    required Offset relativePosition,
  }) async {
    if (commentId.isEmpty) {
      throw ServiceException('유효하지 않은 댓글 ID입니다');
    }

    // 상대 좌표 유효성 검사 (0.0 ~ 1.0 범위)
    if (relativePosition.dx < 0.0 ||
        relativePosition.dx > 1.0 ||
        relativePosition.dy < 0.0 ||
        relativePosition.dy > 1.0) {
      throw ServiceException('상대 좌표는 0.0 ~ 1.0 범위여야 합니다: $relativePosition');
    }

    try {
      await _repository.updateRelativeProfilePosition(
        commentId: commentId,
        relativePosition: relativePosition,
      );
    } catch (e) {
      throw ServiceException('상대 프로필 위치 업데이트 실패', originalError: e);
    }
  }

  /// 프로필 이미지 위치 업데이트 (기존 절대 좌표 - 하위호환성)
  Future<void> updateProfilePosition({
    required String commentId,
    required Offset profilePosition,
  }) async {
    if (commentId.isEmpty) {
      throw ServiceException('유효하지 않은 댓글 ID입니다');
    }

    try {
      await _repository.updateProfilePosition(
        commentId: commentId,
        profilePosition: profilePosition,
      );
    } catch (e) {
      throw ServiceException('프로필 위치 업데이트 실패', originalError: e);
    }
  }

  /// 특정 사용자의 모든 음성 댓글의 프로필 이미지 URL 업데이트
  Future<void> updateUserProfileImageUrl({
    required String userId,
    required String newProfileImageUrl,
  }) async {
    if (userId.isEmpty) {
      throw ServiceException('유효하지 않은 사용자 ID입니다');
    }

    if (newProfileImageUrl.isEmpty) {
      throw ServiceException('유효하지 않은 프로필 이미지 URL입니다');
    }

    try {
      await _repository.updateUserProfileImageUrl(
        userId: userId,
        newProfileImageUrl: newProfileImageUrl,
      );
    } catch (e) {
      throw ServiceException('사용자 음성 댓글 프로필 이미지 URL 업데이트 실패', originalError: e);
    }
  }

  /// 실시간 음성 댓글 스트림
  Stream<List<CommentRecordModel>> getCommentRecordsStream(String photoId) {
    if (photoId.isEmpty) {
      throw ServiceException('유효하지 않은 사진 ID입니다');
    }

    return _repository.getCommentRecordsStream(photoId);
  }

  /// 입력값 유효성 검사
  void _validateInputs({
    required String audioFilePath,
    required String photoId,
    required String recorderUser,
    required List<double> waveformData,
    required int duration,
  }) {
    if (audioFilePath.isEmpty) {
      throw ServiceException('음성 파일 경로가 필요합니다');
    }

    if (photoId.isEmpty) {
      throw ServiceException('사진 ID가 필요합니다');
    }

    if (recorderUser.isEmpty) {
      throw ServiceException('녹음자 정보가 필요합니다');
    }

    if (waveformData.isEmpty) {
      throw ServiceException('파형 데이터가 필요합니다');
    }

    if (duration <= 0) {
      throw ServiceException('유효하지 않은 녹음 시간입니다');
    }

    // 녹음 시간 제한 (예: 최대 5분)
    const maxDurationMs = 5 * 60 * 1000; // 5분
    if (duration > maxDurationMs) {
      throw ServiceException('녹음 시간이 너무 깁니다 (최대 5분)');
    }
  }

  /// 오디오 파일 유효성 검사
  Future<void> _validateAudioFile(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw ServiceException('음성 파일이 존재하지 않습니다');
    }

    // 파일 크기 확인 (예: 최대 10MB)
    const maxSizeBytes = 10 * 1024 * 1024; // 10MB
    final fileSize = await file.length();
    if (fileSize > maxSizeBytes) {
      throw ServiceException('음성 파일 크기가 너무 큽니다 (최대 10MB)');
    }

    // 파일 확장자 확인
    final extension = filePath.split('.').last.toLowerCase();
    const allowedExtensions = ['aac', 'm4a', 'mp3', 'wav'];
    if (!allowedExtensions.contains(extension)) {
      throw ServiceException('지원하지 않는 음성 파일 형식입니다');
    }
  }

  /// 파형 데이터 정규화 (필요한 경우)
  List<double> normalizeWaveformData(List<double> waveformData) {
    if (waveformData.isEmpty) return [];

    // 최대값 찾기
    final maxValue =
        waveformData.reduce((a, b) => a.abs() > b.abs() ? a : b).abs();
    if (maxValue == 0) return waveformData;

    // 0.0 ~ 1.0 범위로 정규화
    return waveformData
        .map((value) => (value.abs() / maxValue).clamp(0.0, 1.0))
        .toList();
  }

  /// 음성 댓글 통계 조회
  Future<CommentRecordStats> getCommentRecordStats(String photoId) async {
    try {
      final comments = await getCommentRecordsByPhotoId(photoId);

      return CommentRecordStats(
        totalCount: comments.length,
        totalDuration: comments.fold(
          0,
          (sum, comment) => sum + comment.duration,
        ),
        uniqueRecorders: comments.map((c) => c.recorderUser).toSet().length,
        latestCommentAt:
            comments.isNotEmpty
                ? comments
                    .map((c) => c.createdAt)
                    .reduce((a, b) => a.isAfter(b) ? a : b)
                : null,
      );
    } catch (e) {
      throw ServiceException('음성 댓글 통계 조회 실패', originalError: e);
    }
  }
}

/// 서비스 계층 예외
class ServiceException implements Exception {
  final String message;
  final dynamic originalError;

  ServiceException(this.message, {this.originalError});

  @override
  String toString() => 'ServiceException: $message';
}

/// 음성 댓글 통계 모델
class CommentRecordStats {
  final int totalCount;
  final int totalDuration; // milliseconds
  final int uniqueRecorders;
  final DateTime? latestCommentAt;

  CommentRecordStats({
    required this.totalCount,
    required this.totalDuration,
    required this.uniqueRecorders,
    this.latestCommentAt,
  });
}
