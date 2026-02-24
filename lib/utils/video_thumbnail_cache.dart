import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// 비디오 썸네일 3-tier 캐시 (Memory → Disk → Generate)
///
/// 메모리 캐시(즉시) → 디스크 캐시(5-50ms) → 비디오에서 생성(500-2000ms)
/// 순서로 조회하여 최적의 성능을 제공합니다.
class VideoThumbnailCache {
  // Tier 1: 메모리 캐시 (LRU)
  static const int _maxEntries = 120;
  static const int _maxBytes = 12 * 1024 * 1024;
  static final LinkedHashMap<String, _MemoryCacheEntry> _memoryCache =
      LinkedHashMap<String, _MemoryCacheEntry>();
  static int _currentBytes = 0;

  // 디스크 캐시 디렉토리 경로 (lazy init)
  static String? _cacheDirPath;

  /// 안정적인 캐시 키 생성
  /// postFileKey가 유효하면 이를 사용하고,
  /// 그렇지 않으면 videoUrl에서 쿼리와 프래그먼트를 제거하여 생성
  static String buildStableCacheKey({
    String? fileKey,
    required String videoUrl,
  }) {
    final trimmedFileKey = fileKey?.trim();
    if (trimmedFileKey != null && trimmedFileKey.isNotEmpty) {
      return trimmedFileKey;
    }

    final uri = Uri.tryParse(videoUrl);
    if (uri == null) {
      return videoUrl.split('#').first.split('?').first;
    }

    return uri.replace(query: null, fragment: null).toString();
  }

  /// 메모리 캐시에서 동기적으로 조회 (UI 즉시 반영용)
  static Uint8List? getFromMemory(String cacheKey) {
    final entry = _memoryCache.remove(cacheKey);
    if (entry == null) return null;

    // LRU 갱신: 최근 접근한 키를 뒤로 이동
    _memoryCache[cacheKey] = entry;
    return entry.bytes;
  }

  /// 3-tier 캐시에서 썸네일 조회
  ///
  /// [videoUrl]: 비디오 presigned URL
  /// [cacheKey]: 안정적인 캐시 키 (postFileKey)
  static Future<Uint8List?> getThumbnail({
    required String videoUrl,
    required String cacheKey,
    int maxWidth = 262,
    int quality = 75,
  }) async {
    // Tier 1: 메모리 캐시 (즉시)
    final memHit = getFromMemory(cacheKey);
    if (memHit != null) {
      if (kDebugMode) {
        debugPrint('[VideoThumbnailCache] Memory hit: $cacheKey');
      }
      return memHit;
    }

    // Tier 2: 디스크 캐시 (~5-50ms)
    final diskHit = await _loadFromDisk(cacheKey);
    if (diskHit != null) {
      _putIntoMemory(cacheKey, diskHit);
      if (kDebugMode) {
        debugPrint('[VideoThumbnailCache] Disk hit: $cacheKey');
      }
      return diskHit;
    }

    // Tier 3: 비디오에서 생성 (500-2000ms)
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: maxWidth,
        quality: quality,
      );

      if (bytes != null) {
        _putIntoMemory(cacheKey, bytes);
        // 디스크에 백그라운드 저장 (await 없이)
        _saveToDisk(cacheKey, bytes);
        if (kDebugMode) {
          debugPrint('[VideoThumbnailCache] Generated & cached: $cacheKey');
        }
      }
      return bytes;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VideoThumbnailCache] Generation failed: $e');
      }
      return null;
    }
  }

  /// 디스크 캐시 디렉토리 경로 (lazy init)
  static Future<String> _getCacheDir() async {
    if (_cacheDirPath != null) return _cacheDirPath!;

    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/video_thumbnails');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    _cacheDirPath = cacheDir.path;
    return _cacheDirPath!;
  }

  /// postFileKey를 파일명으로 변환
  static String _sanitizeKey(String key) {
    return '${key.replaceAll('/', '_').replaceAll('\\', '_').replaceAll(':', '_').replaceAll(' ', '_')}.jpg';
  }

  /// 디스크에서 썸네일 로드
  static Future<Uint8List?> _loadFromDisk(String cacheKey) async {
    try {
      final dir = await _getCacheDir();
      final file = File('$dir/${_sanitizeKey(cacheKey)}');
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VideoThumbnailCache] Disk read failed: $e');
      }
    }
    return null;
  }

  /// 디스크에 썸네일 저장
  static Future<void> _saveToDisk(String cacheKey, Uint8List bytes) async {
    try {
      final dir = await _getCacheDir();
      final file = File('$dir/${_sanitizeKey(cacheKey)}');
      await file.writeAsBytes(bytes, flush: true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VideoThumbnailCache] Disk write failed: $e');
      }
    }
  }

  static void _putIntoMemory(String cacheKey, Uint8List bytes) {
    final incomingSize = bytes.lengthInBytes;

    if (incomingSize > _maxBytes) {
      if (kDebugMode) {
        debugPrint(
          '[VideoThumbnailCache] Skip memory cache (too large): key=$cacheKey bytes=$incomingSize',
        );
      }
      return;
    }

    final previous = _memoryCache.remove(cacheKey);
    if (previous != null) {
      _currentBytes -= previous.sizeBytes;
    }

    _memoryCache[cacheKey] = _MemoryCacheEntry(
      bytes: bytes,
      sizeBytes: incomingSize,
    );
    _currentBytes += incomingSize;

    _evictIfNeeded();
  }

  static void _evictIfNeeded() {
    while (_memoryCache.length > _maxEntries || _currentBytes > _maxBytes) {
      if (_memoryCache.isEmpty) break;
      final oldestKey = _memoryCache.keys.first;
      final removed = _memoryCache.remove(oldestKey);
      if (removed == null) break;
      _currentBytes -= removed.sizeBytes;
      if (_currentBytes < 0) {
        _currentBytes = 0;
      }
    }
  }

  static void clearMemory() {
    _memoryCache.clear();
    _currentBytes = 0;
  }

  static Map<String, int> debugStats() {
    return <String, int>{
      'entries': _memoryCache.length,
      'bytes': _currentBytes,
      'maxEntries': _maxEntries,
      'maxBytes': _maxBytes,
    };
  }
}

class _MemoryCacheEntry {
  final Uint8List bytes;
  final int sizeBytes;

  const _MemoryCacheEntry({required this.bytes, required this.sizeBytes});
}
