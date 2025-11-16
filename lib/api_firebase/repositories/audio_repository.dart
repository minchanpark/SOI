import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

/// Firebase에서 오디오 관련 데이터를 가져오고, 저장하고, 업데이트하고 삭제하는 등의 로직들
class AudioRepository {
  static const MethodChannel _channel = MethodChannel('native_recorder');

  // ==================== 권한 관리 (네이티브) ====================

  /// 마이크 권한 요청 (네이티브에서 처리)
  static Future<bool> requestMicrophonePermission() async {
    try {
      final bool granted = await _channel.invokeMethod(
        'requestMicrophonePermission',
      );

      if (granted) {
        return true;
      } else {
        debugPrint('네이티브 마이크 권한이 거부되었습니다.');
        return false;
      }
    } catch (e) {
      debugPrint('네이티브 마이크 권한 요청 중 오류: $e');
      return false;
    }
  }

  // ==================== 네이티브 녹음 관리 ====================

  /// 네이티브 녹음 시작 (메인)
  /// Returns: 생성된 파일 경로
  static Future<String> startRecording() async {
    try {
      final tempDir = await getTemporaryDirectory();
      //final String fileExtension = '.m4a'; // AAC 코덱 사용
      String filePath =
          '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      final String startedPath = await _channel.invokeMethod('startRecording', {
        'filePath': filePath,
      });

      return startedPath; // 실제 생성된 파일 경로 반환
    } catch (e) {
      debugPrint('네이티브 녹음 시작 오류: $e');
      return '';
    }
  }

  /// 네이티브 녹음 중지
  /// Returns: 녹음된 파일 경로
  static Future<String?> stopRecording() async {
    try {
      final String? filePath = await _channel.invokeMethod('stopRecording');

      return filePath;
    } catch (e) {
      debugPrint('네이티브 녹음 중지 오류: $e');
      return null;
    }
  }

  /// 네이티브 녹음 상태 확인
  static Future<bool> isRecording() async {
    try {
      final bool recording = await _channel.invokeMethod('isRecording');
      return recording;
    } catch (e) {
      debugPrint('네이티브 녹음 상태 확인 오류: $e');
      return false;
    }
  }

  /// 재생 상태 확인 (기본값 false)
  bool get isPlaying => false;

  // 네이티브에서는 재생 진행률 스트림 제공하지 않음

  // ==================== 파일 관리 ====================

  /// 파일 크기 계산 (MB 단위)
  Future<double> getFileSize(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return 0.0;

    final bytes = await file.length();
    return bytes / (1024 * 1024); // MB로 변환
  }

  /// 임시 파일 삭제
  Future<void> deleteLocalFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 임시 디렉토리 정리
  Future<void> cleanupTempFiles() async {
    final tempDir = await getTemporaryDirectory();
    final audioFiles = tempDir.listSync().where(
      (file) =>
          file.path.contains('audio_') &&
          (file.path.endsWith('.ogg') ||
              file.path.endsWith('.aac') ||
              file.path.endsWith('.m4a') ||
              file.path.endsWith('.wav')),
    );

    for (final file in audioFiles) {
      try {
        await file.delete();
      } catch (e) {
        debugPrint('임시 파일 삭제 실패: $e');
      }
    }
  }

  // ==================== Firestore 관리 ====================

  // ==================== Supabase Storage 관리 ====================

  /// 오디오 파일을 Supabase Storage에 업로드
  Future<String?> uploadAudioToSupabaseStorage({
    required File audioFile,
    required String categoryId,
    required String userId,
    String? customFileName,
  }) async {
    final supabase = Supabase.instance.client;
    try {
      // 파일 존재 확인
      if (!await audioFile.exists()) {
        debugPrint('오디오 파일이 존재하지 않습니다: ${audioFile.path}');
        return null;
      }

      // 파일 크기 확인
      final fileSize = await audioFile.length();
      if (fileSize == 0) {
        debugPrint('오디오 파일 크기가 0입니다');
        return null;
      }

      // 파일명 생성
      final fileName =
          customFileName ??
          '${categoryId}_${userId}_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // supabase storage에 오디오 업로드
      await supabase.storage.from('audio').upload(fileName, audioFile);

      // 즉시 공개 URL 생성
      final publicUrl = supabase.storage.from('audio').getPublicUrl(fileName);

      debugPrint('AudioRepository: 오디오 업로드 성공 - $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('AudioRepository: 오디오 업로드 오류 - $e');
      return null;
    }
  }

  // ==================== Firebase Storage 관리 ====================

  /// 오디오 파일에서 파형 데이터 추출
  Future<List<double>> extractWaveformData(String audioFilePath) async {
    final controller = PlayerController();

    try {
      await controller.preparePlayer(
        path: audioFilePath,
        shouldExtractWaveform: true,
      );

      // 파형 추출 완료 대기 (PhotoGridItem과 동일한 로직)
      List<double> rawData = [];
      int attempts = 0;
      const maxAttempts = 200; // 20초 대기 (업로드 시에는 더 오래 기다림)

      while (attempts < maxAttempts && rawData.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;

        try {
          final currentData = controller.waveformData;
          if (currentData.isNotEmpty) {
            rawData = currentData;

            break;
          }
        } catch (e) {
          // 아직 준비되지 않음, 계속 대기
          rethrow;
        }
      }

      if (rawData.isEmpty) {
        return [];
      }

      // 데이터 최적화 (100개 포인트로 압축)
      final compressedData = _compressWaveformData(rawData, targetLength: 100);

      return compressedData;
    } catch (e) {
      debugPrint('❌ 파형 데이터 추출 실패: $e');
      return [];
    } finally {
      controller.dispose();
    }
  }

  /// 파형 데이터 압축
  List<double> _compressWaveformData(
    List<double> data, {
    int targetLength = 100,
  }) {
    if (data.length <= targetLength) return data;

    final step = data.length / targetLength;
    final compressed = <double>[];

    for (int i = 0; i < targetLength; i++) {
      final index = (i * step).round();
      if (index < data.length) {
        compressed.add(data[index]);
      }
    }

    return compressed;
  }

  /// 오디오 길이 계산 (더 정확한 방법)
  Future<double> getAudioDurationAccurate(String audioFilePath) async {
    final controller = PlayerController();

    try {
      await controller.preparePlayer(path: audioFilePath);
      final duration = controller.maxDuration;
      return duration / 1000.0; // 밀리초를 초로 변환
    } catch (e) {
      debugPrint('오디오 길이 계산 실패: $e');
      return 0.0;
    } finally {
      controller.dispose();
    }
  }
}
