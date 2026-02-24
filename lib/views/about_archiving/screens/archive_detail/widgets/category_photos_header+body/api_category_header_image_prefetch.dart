import 'dart:collection';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:soi/api/models/category.dart';

/// 카테고리 헤더 이미지 프리페칭 모델
/// Category 객체에서 헤더 이미지 URL과 캐시 키를 추출하여 프리페칭에 필요한 정보를 담는 모델입니다.
///
/// Parameters:
///   - [imageUrl]: 프리페칭할 이미지의 URL
///   - [cacheKey]: 캐시 키 (중복 프리페칭 방지 및 캐시 관리에 사용)
///
/// Returns:
///   - CategoryHeaderImagePrefetch 객체 또는 null (이미지 URL이 없는 경우)
class CategoryHeaderImagePrefetch {
  final String imageUrl;
  final String cacheKey;

  const CategoryHeaderImagePrefetch({
    required this.imageUrl,
    required this.cacheKey,
  });

  static CategoryHeaderImagePrefetch? fromCategory(Category category) {
    final rawUrl = category.photoUrl; // Category 객체에서 헤더 이미지 URL 추출
    if (rawUrl == null || rawUrl.isEmpty) return null;

    final uri = Uri.tryParse(rawUrl); // URL 파싱 시도 (유효하지 않은 URL인 경우 null 반환)
    final normalizedUrl =
        uri?.replace(query: '', fragment: '').toString() ?? rawUrl;

    return CategoryHeaderImagePrefetch(
      imageUrl: rawUrl,
      cacheKey: 'category_header_${category.id}_$normalizedUrl',
    );
  }
}

/// 카테고리 헤더 이미지 프리페칭 레지스트리
/// 프리페칭 요청을 관리하여 중복 요청 방지 및 완료된 프리페칭 캐싱을 담당합니다.
class CategoryHeaderImagePrefetchRegistry {
  static const int _maxDoneEntries = 120; // 완료된 프리페칭 캐시 최대 개수 (LRU 방식으로 관리)
  static final Map<String, Future<void>> _headerPrefetchInFlight =
      {}; // 현재 진행 중인 프리페칭 요청 (cacheKey -> Future)
  static final LinkedHashSet<String> _headerPrefetchDone =
      LinkedHashSet(); // 완료된 프리페칭 캐시 (cacheKey)

  const CategoryHeaderImagePrefetchRegistry._();

  /// 카테고리 헤더 이미지 프리페칭 요청
  /// 프리페칭이 이미 완료되었거나 진행 중인 경우에는 기존 상태를 활용하여 중복 요청을 방지합니다.
  /// 프리페칭이 필요한 경우에는 precacheImage를 사용하여 이미지를 미리 로드합니다.
  /// 프리페칭 실패 시에는 예외를 무시하고 로그만 출력하여 사용자 경험에 영향을 주지 않도록 합니다.
  static Future<void> prefetchIfNeeded(
    BuildContext context,
    CategoryHeaderImagePrefetch payload,
  ) {
    final cacheKey = payload.cacheKey;
    if (_headerPrefetchDone.contains(cacheKey)) {
      return Future.value();
    }

    final inFlight =
        _headerPrefetchInFlight[cacheKey]; // 이미 진행 중인 프리페칭 요청이 있는지 확인
    if (inFlight != null) {
      return inFlight;
    }

    final task = _runPrefetch(context, payload); // 프리페칭 작업 시작
    _headerPrefetchInFlight[cacheKey] = task;
    return task;
  }

  /// 실제 프리페칭 작업을 수행하는 내부 메서드
  /// precacheImage를 사용하여 이미지를 미리 로드하고, 완료되면 캐시 상태를 업데이트합니다.
  /// 프리페칭 실패 시에는 예외를 무시하고 로그만 출력하여 사용자 경험에 영향을 주지 않도록 합니다.
  static Future<void> _runPrefetch(
    BuildContext context,
    CategoryHeaderImagePrefetch payload,
  ) async {
    try {
      await precacheImage(
        CachedNetworkImageProvider(
          payload.imageUrl,
          cacheKey: payload.cacheKey,
        ),
        context,
      );
      _markDone(payload.cacheKey);
    } catch (e) {
      if (foundation.kDebugMode) {
        debugPrint('[HeaderPrefetch] 헤더 이미지 프리로드 실패 (무시됨): $e');
      }
    } finally {
      _headerPrefetchInFlight.remove(payload.cacheKey);
    }
  }

  /// 완료된 프리페칭 캐시에 항목을 추가하는 내부 메서드
  /// 캐시가 최대 개수를 초과하는 경우에는 가장 오래된 항목을 제거하여 LRU 방식으로 관리합니다.
  static void _markDone(String cacheKey) {
    _headerPrefetchDone.add(cacheKey); // 완료된 프리페칭 캐시에 추가
    if (_headerPrefetchDone.length <= _maxDoneEntries) {
      return; // 최대 개수를 초과하지 않으면 종료
    }
    final oldestKey = _headerPrefetchDone.first; // 가장 오래된 항목 가져오기
    _headerPrefetchDone.remove(oldestKey); // 가장 오래된 항목 제거
  }
}
