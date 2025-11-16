import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_search_model.dart';

/// 사용자 검색 Repository 클래스
/// Firestore의 users 컬렉션에서 사용자 검색 기능 제공
class UserSearchRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

  /// 전화번호로 사용자 검색
  ///
  /// [phoneNumber] 검색할 전화번호
  Future<UserSearchModel?> searchUserByPhoneNumber(String phoneNumber) async {
    try {
      final hashedPhoneNumber = _hashPhoneNumber(phoneNumber);

      // 먼저 전체 사용자 중 phone 필드가 있는 문서 확인
      final allUsersSnapshot = await _usersCollection.limit(10).get();
      for (final doc in allUsersSnapshot.docs) {
        final data = doc.data();

        // 전화번호가 있는 경우 해시값 비교
        if (data['phone'] != null && data['phone'] == hashedPhoneNumber) {}
      }

      // allowPhoneSearch 조건 없이 먼저 검색해보기
      final testQuery =
          await _usersCollection
              .where('phone', isEqualTo: hashedPhoneNumber)
              .get();
      if (testQuery.docs.isNotEmpty) {
        testQuery.docs.first.data();
      }

      // allowPhoneSearch가 null이거나 true인 경우 모두 허용
      final querySnapshot =
          await _usersCollection
              .where('phone', isEqualTo: hashedPhoneNumber)
              .limit(1)
              .get();

      // 추가 필터링: allowPhoneSearch가 명시적으로 false가 아닌 경우만 허용
      final filteredDocs =
          querySnapshot.docs.where((doc) {
            final data = doc.data();
            final allowSearch = data['allowPhoneSearch'];
            return allowSearch != false; // null이거나 true인 경우 허용
          }).toList();

      if (filteredDocs.isEmpty) {
        return null;
      }

      final userDoc = filteredDocs.first;
      userDoc.data();

      return UserSearchModel.fromFirestore(userDoc);
    } catch (e) {
      debugPrint('전화번호 검색 중 오류 발생: $e');
      throw Exception('전화번호 검색 실패: $e');
    }
  }

  /// 여러 전화번호로 사용자 일괄 검색
  ///
  /// [phoneNumbers] 검색할 전화번호 목록
  Future<List<UserSearchModel>> searchUsersByPhoneNumbers(
    List<String> phoneNumbers,
  ) async {
    if (phoneNumbers.isEmpty) {
      return [];
    }

    try {
      final hashedNumbers = phoneNumbers.map(_hashPhoneNumber).toList();

      // Firestore의 'in' 쿼리 제한으로 인해 배치 처리 (최대 10개씩)
      final List<UserSearchModel> results = [];

      for (int i = 0; i < hashedNumbers.length; i += 10) {
        final batch = hashedNumbers.skip(i).take(10).toList();

        final querySnapshot =
            await _usersCollection
                .where('phone', whereIn: batch)
                .where('allowPhoneSearch', isEqualTo: true)
                .get();

        final batchResults =
            querySnapshot.docs.map((doc) {
              return UserSearchModel.fromFirestore(doc);
            }).toList();

        results.addAll(batchResults);
      }

      // 현재 사용자 제외
      final currentUid = _currentUserUid;
      if (currentUid != null) {
        results.removeWhere((user) => user.uid == currentUid);
      }

      return results;
    } catch (e) {
      throw Exception('전화번호 일괄 검색 실패: $e');
    }
  }

  /// 닉네임으로 사용자 검색
  ///
  /// [nickname] 검색할 닉네임
  /// [limit] 최대 결과 수
  Future<List<UserSearchModel>> searchUsersById(
    String id, {
    int limit = 20,
  }) async {
    if (id.isEmpty) {
      return [];
    }

    try {
      // Firestore에서는 부분 검색이 제한적이므로
      // 정확한 일치와 prefix 검색을 조합
      final List<UserSearchModel> results = [];

      // 1. 정확한 일치 검색
      final exactMatch =
          await _usersCollection.where('id', isEqualTo: id).limit(limit).get();

      results.addAll(
        exactMatch.docs.map((doc) {
          return UserSearchModel.fromFirestore(doc);
        }),
      );

      // 2. prefix 검색 (결과가 부족한 경우)
      if (results.length < limit) {
        final remaining = limit - results.length;
        final prefixMatch =
            await _usersCollection
                .where('id', isGreaterThanOrEqualTo: id)
                .where('id', isLessThan: '${id}z')
                .limit(remaining + 10) // 중복 제거를 위해 여유분 가져오기
                .get();

        final prefixResults =
            prefixMatch.docs
                .map((doc) => UserSearchModel.fromFirestore(doc))
                .where(
                  (user) =>
                      !results.any((existing) => existing.uid == user.uid),
                )
                .take(remaining)
                .toList();

        results.addAll(prefixResults);
      }

      // 현재 사용자 제외
      final currentUid = _currentUserUid;
      if (currentUid != null) {
        results.removeWhere((user) => user.uid == currentUid);
      }

      return results;
    } catch (e) {
      throw Exception('닉네임 검색 실패: $e');
    }
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

  /// 인기 사용자 추천 (최근 가입자)
  ///
  /// [limit] 최대 결과 수
  Future<List<UserSearchModel>> getRecentUsers({int limit = 10}) async {
    try {
      final querySnapshot =
          await _usersCollection
              .orderBy('createdAt', descending: true)
              .limit(limit + 1) // 현재 사용자 제외를 위해 +1
              .get();

      final results =
          querySnapshot.docs.map((doc) {
            return UserSearchModel.fromFirestore(doc);
          }).toList();

      // 현재 사용자 제외
      final currentUid = _currentUserUid;
      if (currentUid != null) {
        results.removeWhere((user) => user.uid == currentUid);
      }

      return results.take(limit).toList();
    } catch (e) {
      throw Exception('인기 사용자 조회 실패: $e');
    }
  }

  /// 사용자 검색 설정 업데이트
  ///
  /// [allowPhoneSearch] 전화번호 검색 허용 여부
  Future<void> updateSearchSettings({required bool allowPhoneSearch}) async {
    final currentUid = _currentUserUid;
    if (currentUid == null) {
      throw Exception('사용자가 로그인되어 있지 않습니다');
    }

    try {
      await _usersCollection.doc(currentUid).update({
        'allowPhoneSearch': allowPhoneSearch,
      });
    } catch (e) {
      throw Exception('검색 설정 업데이트 실패: $e');
    }
  }

  /// 현재 사용자의 전화번호 등록
  ///
  /// [phoneNumber] 등록할 전화번호
  Future<void> registerPhoneNumber(String phoneNumber) async {
    final currentUid = _currentUserUid;
    if (currentUid == null) {
      throw Exception('사용자가 로그인되어 있지 않습니다');
    }

    try {
      final hashedPhoneNumber = _hashPhoneNumber(phoneNumber);

      await _usersCollection.doc(currentUid).update({
        'phone': hashedPhoneNumber,
        'allowPhoneSearch': true, // 기본값으로 검색 허용
      });
    } catch (e) {
      throw Exception('전화번호 등록 실패: $e');
    }
  }

  /// 현재 사용자의 전화번호 삭제
  Future<void> removePhoneNumber() async {
    final currentUid = _currentUserUid;
    if (currentUid == null) {
      throw Exception('사용자가 로그인되어 있지 않습니다');
    }

    try {
      await _usersCollection.doc(currentUid).update({
        'phone': FieldValue.delete(),
        'allowPhoneSearch': false,
      });
    } catch (e) {
      throw Exception('전화번호 삭제 실패: $e');
    }
  }

  /// 검색 가능한 사용자인지 확인
  ///
  /// [userId] 확인할 사용자 ID
  Future<bool> isSearchableUser(String userId) async {
    try {
      final userDoc = await _usersCollection.doc(userId).get();

      if (!userDoc.exists) {
        return false;
      }

      final userData = userDoc.data();
      return userData?['allowPhoneSearch'] == true ||
          userData?['nickname'] != null;
    } catch (e) {
      return false;
    }
  }

  /// 연락처 기반 친구 추천
  ///
  /// [contactPhoneNumbers] 연락처 전화번호 목록
  /// [excludeUserIds] 제외할 사용자 ID 목록 (이미 친구인 사용자 등)
  Future<List<UserSearchModel>> getSuggestedFriends(
    List<String> contactPhoneNumbers, {
    List<String> excludeUserIds = const [],
  }) async {
    try {
      final foundUsers = await searchUsersByPhoneNumbers(contactPhoneNumbers);

      // 제외할 사용자들 필터링
      final filteredUsers =
          foundUsers.where((user) {
            return !excludeUserIds.contains(user.uid);
          }).toList();

      return filteredUsers;
    } catch (e) {
      throw Exception('친구 추천 조회 실패: $e');
    }
  }
}
