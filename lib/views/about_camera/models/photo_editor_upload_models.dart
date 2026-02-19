import 'dart:io';

/// 텍스트 전용 게시물 생성 시 사용하는 고정 기본값
class TextOnlyPostCreateDefaults {
  TextOnlyPostCreateDefaults._();

  static const List<String> postFileKey = [''];
  static const List<String> audioFileKey = [''];
  static const String waveformData = '';
  static const int duration = 0;
  static const double savedAspectRatio = 0;
  static const bool isFromGallery = true;
}

/// 서버 업로드 실행 직전 실제 payload 데이터
class UploadPayload {
  final int userId;
  final String nickName;
  final File mediaFile;
  final String mediaPath;
  final bool isVideo;
  final File? audioFile;
  final String? audioPath;
  final String? caption;
  final List<double>? waveformData;
  final int? audioDurationSeconds;
  final int usageCount;
  final double? aspectRatio;
  final bool isFromGallery;

  const UploadPayload({
    required this.userId,
    required this.nickName,
    required this.mediaFile,
    required this.mediaPath,
    required this.isVideo,
    required this.usageCount,
    required this.isFromGallery,
    this.audioFile,
    this.audioPath,
    this.caption,
    this.waveformData,
    this.audioDurationSeconds,
    this.aspectRatio,
  });
}

/// 화면 전환 이전에 캡처해 두는 업로드 스냅샷
class UploadSnapshot {
  final int userId;
  final String nickName;
  final String filePath;
  final bool isVideo;
  final String captionText;
  final String? recordedAudioPath;
  final List<double>? recordedWaveformData;
  final int? recordedAudioDurationSeconds;
  final List<int> categoryIds;
  final Future<File>? compressionTask;
  final File? compressedFile;
  final String? lastCompressedPath;

  const UploadSnapshot({
    required this.userId,
    required this.nickName,
    required this.filePath,
    required this.isVideo,
    required this.captionText,
    required this.categoryIds,
    required this.compressionTask,
    required this.compressedFile,
    required this.lastCompressedPath,
    this.recordedAudioPath,
    this.recordedWaveformData,
    this.recordedAudioDurationSeconds,
  });
}

/// 업로드 후 반환된 미디어 키 집합
class MediaUploadResult {
  final List<String> mediaKeys;
  final List<String> audioKeys;

  const MediaUploadResult({required this.mediaKeys, required this.audioKeys});
}
