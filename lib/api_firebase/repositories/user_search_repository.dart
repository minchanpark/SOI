import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_search_model.dart';

/// 검색 결과 캐시 엔트리
class _CacheEntry {
  final List<UserSearchModel> results;
  final DateTime timestamp;

  _CacheEntry(this.results, this.timestamp);

  bool isExpired(Duration ttl) {
    return DateTime.now().difference(timestamp) > ttl;
  }
}

/// 사용자 검색 Repository 클래스
/// Firestore의 users 컬렉션에서 사용자 검색 기능 제공
/// LRU 캐싱으로 O(1) 성능 달성
class UserSearchRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // LRU 캐시 (검색어 -> 결과)
  final Map<String, _CacheEntry> _searchCache = {};

  // LRU 캐시 (전화번호 리스트 -> 결과)
  final Map<String, _CacheEntry> _phoneSearchCache = {};

  // LRU 캐시 (단일 전화번호 -> 결과)
  final Map<String, _CacheEntry> _singlePhoneCache = {};

  static const int _maxCacheSize = 100;
  static const Duration _cacheTTL = Duration(minutes: 5);

  /// users 컬렉션 참조
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// 현재 사용자 UID 가져오기
  String? get _currentUserUid => _auth.currentUser?.uid;

  /// 전화번호를 해시화하는 함수
  String _hashPhoneNumber(String phoneNumber) {
    // 전화번호에서 숫자만 추출
    var cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // 앞자리 0 제거 (Firestore 데이터와 일치시키기 위해)
    if (cleanNumber.startsWith('0')) {
      cleanNumber = cleanNumber.substring(1);
    }

    // 현재 Firestore에는 해시값이 아닌 전화번호가 저장되어 있으므로
    // 일단 전화번호를 그대로 반환 (추후 해시 마이그레이션 필요)
    return cleanNumber;

    // SHA-256 해시 생성 (추후 사용)
    // final bytes = utf8.encode(cleanNumber);
    // final hash = sha256.convert(bytes);
    // return hash.toString();
  }

  /// 전화번호로 사용자 검색 (성능 최적화 버전)
  ///
  /// [phoneNumber] 검색할 전화번호
  ///
  /// 성능 최적화:
  /// - LRU 캐싱: O(1) 조회 (캐시 히트)
  /// - 단일 쿼리: 네트워크 요청 1회 (기존 3회 → 1회)
  /// - 불필요한 중간 연산 제거
  ///
  /// 시간 복잡도:
  /// - 캐시 히트: O(1)
  /// - 캐시 미스: O(log n)
  ///
  /// returns: 검색된 사용자 단일 정보 또는 null
  Future<UserSearchModel?> searchUserByPhoneNumber(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      return null;
    }

    final hashedPhoneNumber = _hashPhoneNumber(phoneNumber);

    // 1. 캐시 확인 (O(1))
    final cachedEntry = _singlePhoneCache[hashedPhoneNumber];
    if (cachedEntry != null && !cachedEntry.isExpired(_cacheTTL)) {
      final results = cachedEntry.results;
      return results.isEmpty ? null : results.first;
    }

    try {
      // 2. 단일 Firestore 쿼리 (기존 3회 → 1회)
      final querySnapshot = await _usersCollection
          .where('phone', isEqualTo: hashedPhoneNumber)
          .limit(1)
          .get();

      // 3. allowPhoneSearch 필터링 (클라이언트 측, 단일 결과이므로 O(1))
      final filteredDocs = querySnapshot.docs.where((doc) {
        final data = doc.data();
        final allowSearch = data['allowPhoneSearch'];
        return allowSearch != false; // null이거나 true인 경우 허용
      }).toList();

      UserSearchModel? result;
      if (filteredDocs.isNotEmpty) {
        result = UserSearchModel.fromFirestore(filteredDocs.first);
      }

      // 4. 캐시 저장 (null 결과도 캐싱하여 반복 쿼리 방지)
      _updateSinglePhoneCache(
        hashedPhoneNumber,
        result != null ? [result] : [],
      );

      return result;
    } catch (e) {
      debugPrint('Single phone search error: $e');
      throw Exception('전화번호 검색 실패: $e');
    }
  }

  /// 단일 전화번호 캐시 업데이트
  void _updateSinglePhoneCache(String key, List<UserSearchModel> results) {
    // 캐시 크기 제한 (LRU 방식)
    if (_singlePhoneCache.length >= _maxCacheSize) {
      final oldestKey = _singlePhoneCache.entries
          .reduce(
            (a, b) => a.value.timestamp.isBefore(b.value.timestamp) ? a : b,
          )
          .key;
      _singlePhoneCache.remove(oldestKey);
    }

    _singlePhoneCache[key] = _CacheEntry(List.from(results), DateTime.now());
  }

  /// 여러 전화번호로 사용자 일괄 검색 (성능 최적화 버전)
  ///
  /// [phoneNumbers] 검색할 전화번호 목록
  ///
  /// 성능 최적화:
  /// - LRU 캐싱: O(1) 조회 (캐시 히트)
  /// - 병렬 배치 처리: Future.wait()로 동시 쿼리 실행
  /// - Set 기반 중복 제거: O(n) 시간 복잡도
  /// - 쿼리 시점 현재 사용자 제외
  ///
  /// 시간 복잡도:
  /// - 캐시 히트: O(1)
  /// - 캐시 미스: O(k) where k = 배치 수 (병렬 처리로 실질적 레이턴시 감소)
  Future<List<UserSearchModel>> searchUsersByPhoneNumbers(
    List<String> phoneNumbers,
  ) async {
    if (phoneNumbers.isEmpty) {
      return [];
    }

    // 1. 캐시 키 생성 (정규화: 정렬 + 중복 제거)
    final hashedNumbers = phoneNumbers.map(_hashPhoneNumber).toSet().toList()
      ..sort();
    final cacheKey = hashedNumbers.join(',');

    // 2. 캐시 확인 (O(1))
    final cachedEntry = _phoneSearchCache[cacheKey];
    if (cachedEntry != null && !cachedEntry.isExpired(_cacheTTL)) {
      // 캐시 히트인 경우: 즉시 반환
      return List.from(cachedEntry.results);
    }
    // 캐시 미스인 경우: Firestore 쿼리 실행
    try {
      final currentUid = _currentUserUid;

      // 3. 배치 생성 (Firestore whereIn 제한: 최대 10개)
      final batches = <List<String>>[];
      for (int i = 0; i < hashedNumbers.length; i += 10) {
        batches.add(hashedNumbers.skip(i).take(10).toList());
      }

      // 4. 병렬 배치 처리 (Future.wait로 동시 실행)
      final batchFutures = batches.map((batch) async {
        final querySnapshot = await _usersCollection
            .where('phone', whereIn: batch)
            .where('allowPhoneSearch', isEqualTo: true)
            .get();

        return querySnapshot.docs
            .map((doc) => UserSearchModel.fromFirestore(doc))
            .toList();
      });

      final batchResults = await Future.wait(batchFutures);

      // 5. Set 기반 중복 제거 및 현재 사용자 제외 (O(n))
      final seenUids = <String>{};
      final results = <UserSearchModel>[];

      for (final batchResult in batchResults) {
        for (final user in batchResult) {
          // 중복 제거 및 현재 사용자 제외 (O(1) 조회)
          if (user.uid != currentUid && !seenUids.contains(user.uid)) {
            seenUids.add(user.uid);
            results.add(user);
          }
        }
      }

      // 6. 캐시 저장
      _updatePhoneCache(cacheKey, results);

      return results;
    } catch (e) {
      debugPrint('Phone search error: $e');
      throw Exception('전화번호 일괄 검색 실패: $e');
    }
  }

  /// 전화번호 캐시 업데이트
  void _updatePhoneCache(String key, List<UserSearchModel> results) {
    // 캐시 크기 제한 (LRU 방식)
    if (_phoneSearchCache.length >= _maxCacheSize) {
      // 가장 오래된 엔트리 제거
      final oldestKey = _phoneSearchCache.entries
          .reduce(
            (a, b) => a.value.timestamp.isBefore(b.value.timestamp) ? a : b,
          )
          .key;
      _phoneSearchCache.remove(oldestKey);
    }

    _phoneSearchCache[key] = _CacheEntry(List.from(results), DateTime.now());
  }

  /// ID로 사용자 검색 (성능 최적화 버전)
  ///
  /// [id] 검색할 사용자 ID
  /// [limit] 최대 결과 수
  ///
  /// 성능 최적화:
  /// - LRU 캐싱: O(1) 조회 (캐시 히트)
  /// - 단일 쿼리: 네트워크 요청 1회
  /// - Set 기반 중복 제거: O(n) 시간 복잡도
  /// - 쿼리 시점 현재 사용자 제외
  ///
  /// 시간 복잡도:
  /// - 캐시 히트: O(1)
  /// - 캐시 미스: O(log n + k) where k = limit
  Future<List<UserSearchModel>> searchUsersById(
    String id, {
    int limit = 20,
  }) async {
    if (id.isEmpty) {
      return [];
    }

    // 캐시 키 생성
    final cacheKey = '$id:$limit';

    // 1. 캐시 확인 (O(1))
    final cachedEntry = _searchCache[cacheKey];
    if (cachedEntry != null && !cachedEntry.isExpired(_cacheTTL)) {
      // 캐시 히트인 경우: 즉시 반환
      return List.from(cachedEntry.results);
    }

    // 캐시 미스인 경우: Firestore 쿼리 실행
    try {
      final currentUid = _currentUserUid;

      // 2. 단일 prefix 쿼리로 통합 (정확한 일치 포함)
      // prefix 검색은 정확한 일치도 자동으로 포함하므로 1회 쿼리만 필요
      final querySnapshot = await _usersCollection
          .where('id', isGreaterThanOrEqualTo: id)
          .where('id', isLessThan: '$id\uf8ff') // Unicode 최댓값으로 range 종료
          .limit(limit + 1) // 현재 사용자 제외 대비 +1
          .get();

      // 3. Set 기반 중복 제거 및 변환 (O(n))
      final seenUids = <String>{};
      final results = <UserSearchModel>[];

      for (final doc in querySnapshot.docs) {
        final user = UserSearchModel.fromFirestore(doc);

        // 현재 사용자 제외 및 중복 제거 (O(1) 조회)
        if (user.uid != currentUid && !seenUids.contains(user.uid)) {
          seenUids.add(user.uid);
          results.add(user);

          // limit 도달 시 조기 종료
          if (results.length >= limit) {
            break;
          }
        }
      }

      // 4. 캐시 저장 (LRU 관리)
      _updateCache(cacheKey, results);

      return results;
    } catch (e) {
      debugPrint('Search error: $e');
      throw Exception('ID 검색 실패: $e');
    }
  }

  /// LRU 캐시 업데이트
  void _updateCache(String key, List<UserSearchModel> results) {
    // 캐시 크기 제한 (LRU 방식)
    if (_searchCache.length >= _maxCacheSize) {
      // 가장 오래된 엔트리 제거
      final oldestKey = _searchCache.entries
          .reduce(
            (a, b) => a.value.timestamp.isBefore(b.value.timestamp) ? a : b,
          )
          .key;
      _searchCache.remove(oldestKey);
    }

    _searchCache[key] = _CacheEntry(List.from(results), DateTime.now());
  }

  /// 캐시 초기화 (선택적)
  void clearSearchCache() {
    _searchCache.clear();
    _phoneSearchCache.clear();
    _singlePhoneCache.clear();
    debugPrint('🗑️ All search caches cleared');
  }

  /// 사용자 ID로 사용자 검색
  ///
  /// [userId] 검색할 사용자 ID
  Future<UserSearchModel?> searchUserById(String userId) async {
    try {
      final userDoc = await _usersCollection.doc(userId).get();

      if (!userDoc.exists) {
        return null;
      }

      return UserSearchModel.fromFirestore(userDoc);
    } catch (e) {
      throw Exception('사용자 ID 검색 실패: $e');
    }
  }
}
