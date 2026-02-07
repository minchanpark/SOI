import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// 비디오 썸네일 생성 유틸리티
class VideoThumbnailGenerator {
  /// 비디오 파일에서 첫 프레임을 캡처하여 썸네일 이미지 파일 생성
  static Future<File?> generateThumbnail(
    String videoPath, {
    int quality = 80,
    int maxWidth = 1080,
    int maxHeight = 1920,
  }) async {
    try {
      // 비디오 파일이 존재하는지 확인
      final videoFile = File(videoPath);
      if (!await videoFile.exists()) {
        debugPrint('비디오 파일이 존재하지 않습니다: $videoPath');
        return null;
      }

      // 임시 디렉토리 가져오기
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath =
          '${tempDir.path}/thumbnail_${DateTime.now().millisecondsSinceEpoch}.webp';

      // video_thumbnail 패키지를 사용하여 썸네일 생성
      final thumbnail = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: thumbnailPath,
        imageFormat: ImageFormat.WEBP,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        quality: quality,
      );

      if (thumbnail == null) {
        debugPrint('썸네일 생성 실패: null 반환');
        return null;
      }

      final thumbnailFile = File(thumbnail);
      if (!await thumbnailFile.exists()) {
        debugPrint('생성된 썸네일 파일이 존재하지 않습니다');
        return null;
      }

      await thumbnailFile.length();

      return thumbnailFile;
    } catch (e, stackTrace) {
      debugPrint('비디오 썸네일 생성 실패: $e');
      debugPrint('StackTrace: $stackTrace');
      return null;
    }
  }

  /// 비디오 썸네일을 메모리에 생성 (Uint8List)
  static Future<List<int>?> generateThumbnailData(
    String videoPath, {
    int quality = 80,
    int maxWidth = 1080,
    int maxHeight = 1920,
  }) async {
    try {
      // 비디오 파일이 존재하는지 확인
      final videoFile = File(videoPath);
      if (!await videoFile.exists()) {
        debugPrint('비디오 파일이 존재하지 않습니다: $videoPath');
        return null;
      }

      // video_thumbnail 패키지를 사용하여 메모리에 썸네일 생성
      final thumbnailData = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        quality: quality,
      );

      if (thumbnailData == null) {
        debugPrint('썸네일 데이터 생성 실패: null 반환');
        return null;
      }

      return thumbnailData;
    } catch (e, stackTrace) {
      debugPrint('비디오 썸네일 데이터 생성 실패: $e');
      debugPrint('StackTrace: $stackTrace');
      return null;
    }
  }

  /// 비디오의 duration 가져오기
  static Future<Duration?> getVideoDuration(String videoPath) async {
    VideoPlayerController? controller;
    try {
      final videoFile = File(videoPath);
      if (!await videoFile.exists()) {
        return null;
      }

      controller = VideoPlayerController.file(videoFile);
      await controller.initialize();

      final duration = controller.value.duration;
      debugPrint('비디오 길이: ${duration.inSeconds}초');

      return duration;
    } catch (e) {
      debugPrint('비디오 길이 가져오기 실패: $e');
      return null;
    } finally {
      await controller?.dispose();
    }
  }
}
