import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// 업로드 관련 모델 정의
String _encodeWaveformDataWorker(List<double> waveformData) {
  if (waveformData.isEmpty) return '';

  final buffer = StringBuffer();
  for (var i = 0; i < waveformData.length; i++) {
    if (i > 0) buffer.write(', ');
    buffer.write(double.parse(waveformData[i].toStringAsFixed(6)).toString());
  }
  return buffer.toString();
}

/// 이미지/비디오 처리와 파형 인코딩 책임만 담당합니다.
/// 업로드 준비, 업로드 실행, 업로드 후 정리 등은 담당하지 않습니다.
/// 업로드 관련 로직은 photo_editor_screen_upload.dart에 있습니다.
class PhotoEditorMediaProcessingService {
  const PhotoEditorMediaProcessingService();

  static const int _maxImageSizeBytes = 1024 * 1024;
  static const int _initialCompressionQuality = 85;
  static const int _minCompressionQuality = 40;
  static const int _qualityDecrement = 10;
  static const int _initialImageDimension = 2200;
  static const int _minImageDimension = 960;
  static const double _dimensionScaleFactor = 0.85;
  static const int _fallbackCompressionQuality = 35;
  static const int _fallbackImageDimension = 1024;

  static const int _maxVideoSizeBytes = 50 * 1024 * 1024;

  /// 이미지의 가로세로 비율을 계산하는 메서드
  Future<double?> calculateImageAspectRatio(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final width = image.width.toDouble();
      final height = image.height.toDouble();

      image.dispose();
      codec.dispose();

      if (height == 0) return null;
      return width / height;
    } catch (e) {
      debugPrint('[PhotoEditor] 이미지 aspect ratio 계산 실패: $e');
      return null;
    }
  }

  /// 비디오에서 썸네일 이미지를 추출하는 메서드
  Future<File?> extractVideoThumbnailFile(String videoPath) async {
    if (kIsWeb) return null;
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.WEBP,
        maxWidth: 720,
        quality: 80,
      );
      if (thumbnailPath == null || thumbnailPath.isEmpty) return null;
      return File(thumbnailPath);
    } catch (e) {
      debugPrint('[PhotoEditor] 비디오 썸네일 추출 실패: $e');
      return null;
    }
  }

  /// 파형 데이터를 문자열로 인코딩하는 메서드
  Future<String?> encodeWaveformDataAsync(List<double>? waveformData) async {
    if (waveformData == null || waveformData.isEmpty) {
      return null;
    }

    if (kIsWeb || waveformData.length < 800) {
      return _encodeWaveformData(waveformData);
    }

    try {
      final encoded = await compute(_encodeWaveformDataWorker, waveformData);
      return encoded.isEmpty ? null : encoded;
    } catch (e) {
      debugPrint('[PhotoEditor] waveform encode isolate failed: $e');
      return _encodeWaveformData(waveformData);
    }
  }

  /// 비디오 파일이 최대 허용 크기를 초과하는 경우 압축하는 메서드
  Future<File> compressVideoIfNeeded(File file) async {
    if (kIsWeb) return file;

    final size = await file.length();
    if (size <= _maxVideoSizeBytes) {
      return file;
    }

    var compressed = await _tryCompressVideoWithBitrate(
      // 기본 비트레이트로 압축
      file,
      bitrate: 1500000,
      frameRate: 30,
    );
    if (compressed != null) {
      final compressedSize = await compressed.length();
      if (compressedSize <= _maxVideoSizeBytes) {
        debugPrint('[PhotoEditor] 1단계 압축 성공: ${compressedSize ~/ 1024}KB');
        return compressed;
      }
    }

    compressed = await _tryCompressVideoWithBitrate(
      // 더 낮은 비트레이트로 재시도
      file,
      bitrate: 1000000,
      frameRate: 30,
    );
    if (compressed != null) {
      final compressedSize = await compressed.length();
      if (compressedSize <= _maxVideoSizeBytes) {
        debugPrint('[PhotoEditor] 2단계 압축 성공: ${compressedSize ~/ 1024}KB');
        return compressed;
      }
    }

    compressed = await _tryCompressVideoWithBitrate(
      // 비트레이트를 더 낮춰서 압축 시도
      file,
      bitrate: 800000,
      frameRate: 30,
    );
    if (compressed != null) {
      final compressedSize = await compressed.length();
      if (compressedSize <= _maxVideoSizeBytes) {
        debugPrint('[PhotoEditor] 3단계 압축 성공: ${compressedSize ~/ 1024}KB');
        return compressed;
      }
    }

    debugPrint('[PhotoEditor] 비트레이트 압축 실패, MediumQuality 시도');
    compressed = await _tryCompressVideo(file, VideoQuality.MediumQuality);

    return compressed ?? file;
  }

  /// 이미지 파일이 최대 허용 크기를 초과하는 경우 압축하는 메서드
  Future<File> compressImageIfNeeded(File file) async {
    var currentSize = await file.length();
    if (currentSize <= _maxImageSizeBytes) {
      return file;
    }

    final compressedFile = await _tryProgressiveCompression(file); // 점진적 압축 시도
    if (compressedFile != null) {
      currentSize = await compressedFile.length();
      if (currentSize <= _maxImageSizeBytes) {
        return compressedFile;
      }
    }

    final fallbackFile = await _tryFallbackCompression(file); // 최후의 수단 압축 시도
    return fallbackFile ?? compressedFile ?? file;
  }

  /// 비디오 압축을 시도하는 메서드, 실패 시 null 반환
  Future<File?> _tryCompressVideo(File file, VideoQuality quality) async {
    try {
      final info = await VideoCompress.compressVideo(
        // 기본 설정으로 압축 시도
        file.path,
        quality: quality,
        includeAudio: true,
        deleteOrigin: false,
      );
      return info?.file;
    } catch (e) {
      debugPrint('[PhotoEditor] 비디오 압축 실패: $e');
      return null;
    }
  }

  /// 비디오 압축을 시도하는 메서드, 실패 시 null 반환
  Future<File?> _tryCompressVideoWithBitrate(
    File file, {
    required int bitrate,
    int frameRate = 30,
  }) async {
    try {
      final info = await VideoCompress.compressVideo(
        // 비트레이트 설정으로 압축 시도
        file.path,
        quality: VideoQuality.DefaultQuality,
        frameRate: frameRate,
        includeAudio: true,
        deleteOrigin: false,
      );
      return info?.file;
    } catch (e) {
      debugPrint('[PhotoEditor] 비디오 비트레이트 압축 실패: $e');
      return null;
    }
  }

  /// 이미지 압축을 시도하는 메서드, 실패 시 null 반환
  Future<File?> _tryProgressiveCompression(File file) async {
    final tempDir = await getTemporaryDirectory();
    File? bestCompressed;
    var quality = _initialCompressionQuality;
    var dimension = _initialImageDimension;

    while (quality >= _minCompressionQuality) {
      final compressed = await _compressWithSettings(
        // 점진적 압축 시도
        file,
        tempDir,
        quality: quality,
        dimension: dimension,
        suffix: quality.toString(),
      );

      if (compressed == null) break;

      bestCompressed = compressed;
      final size = await compressed.length();
      if (size <= _maxImageSizeBytes) break;

      quality -= _qualityDecrement;
      dimension = math.max(
        (dimension * _dimensionScaleFactor).round(),
        _minImageDimension,
      );
    }

    return bestCompressed;
  }

  /// 최후의 수단으로 더 낮은 품질과 작은 차원으로 압축하는 메서드, 실패 시 null 반환
  /// 이 방법은 일반적인 압축 방법으로는 크기를 줄이지 못할 때 시도하는 마지막 단계입니다.
  ///
  /// Parameters:
  /// - [file]: 압축할 원본 이미지 파일
  ///
  /// Returns:
  /// - 압축된 이미지 파일 또는 null (압축 실패 시)
  Future<File?> _tryFallbackCompression(File file) async {
    final tempDir = await getTemporaryDirectory();
    return _compressWithSettings(
      file,
      tempDir,
      quality: _fallbackCompressionQuality,
      dimension: _fallbackImageDimension,
      suffix: 'force',
    );
  }

  /// 실제 이미지 압축을 수행하는 메서드, 실패 시 null 반환
  ///
  /// Parameters:
  /// - [file]: 압축할 원본 이미지 파일
  /// - [tempDir]: 압축된 파일을 저장할 임시 디렉토리
  /// - [quality]: 압축 품질 (0-100)
  /// - [dimension]: 압축 후 이미지의 최대 가로/세로 길이
  /// - [suffix]: 압축된 파일 이름에 붙일 접미사 (예: quality 수준)
  ///
  /// Returns:
  /// - 압축된 이미지 파일 또는 null (압축 실패 시)
  Future<File?> _compressWithSettings(
    File file,
    Directory tempDir, {
    required int quality,
    required int dimension,
    required String suffix,
  }) async {
    final targetPath = p.join(
      tempDir.path,
      'soi_upload_${DateTime.now().millisecondsSinceEpoch}_$suffix.webp',
    );

    final compressedXFile = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: quality,
      minWidth: dimension,
      minHeight: dimension,
      format: CompressFormat.webp,
    );

    return compressedXFile != null ? File(compressedXFile.path) : null;
  }

  /// 파형 데이터를 문자열로 인코딩하는 메서드, null 또는 빈 리스트인 경우 null 반환
  ///
  /// Parameters:
  /// - [waveformData]: 인코딩할 파형 데이터 리스트
  ///
  /// Returns:
  /// - 인코딩된 문자열 또는 null (입력 데이터가 null이거나 비어있는 경우)
  String? _encodeWaveformData(List<double>? waveformData) {
    if (waveformData == null || waveformData.isEmpty) {
      return null;
    }
    final encoded = _encodeWaveformDataWorker(waveformData);
    return encoded.isEmpty ? null : encoded;
  }
}
