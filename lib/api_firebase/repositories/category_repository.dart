import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category_data_model.dart';

/// Firebase에서 category 관련 데이터를 가져오고, 저장하고, 업데이트하고 삭제하는 등의 로직들
class CategoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, String?> _categoryCoverCache = {};

  // ==================== Firestore 관련 ====================

  /// 사용자의 카테고리 목록을 스트림으로 가져오기 (병렬 처리 최적화)
  Stream<List<CategoryDataModel>> getUserCategoriesStream(String userId) {
    return _firestore
        .collection('categories')
        .where('mates', arrayContains: userId)
        .snapshots()
        .asyncMap((querySnapshot) async {
          // 병렬로 모든 카테고리의 커버 사진을 가져오기
          final categoryFutures = querySnapshot.docs.map((doc) async {
            final data = doc.data();
            String? categoryPhotoUrl = data['categoryPhotoUrl'] as String?;

            // 커버 사진이 없는 경우에만 최신 사진 쿼리
            if (categoryPhotoUrl == null || categoryPhotoUrl.isEmpty) {
              final photosSnapshot = await _firestore
                  .collection('categories')
                  .doc(doc.id)
                  .collection('photos')
                  .where('unactive', isEqualTo: false)
                  .orderBy('createdAt', descending: true)
                  .limit(1)
                  .get();

              if (photosSnapshot.docs.isNotEmpty) {
                categoryPhotoUrl =
                    photosSnapshot.docs.first.data()['imageUrl'] as String?;
              }
            }

            return CategoryDataModel.fromFirestore(
              data,
              doc.id,
            ).copyWith(categoryPhotoUrl: categoryPhotoUrl);
          }).toList();

          // 모든 쿼리를 병렬로 실행
          return await Future.wait(categoryFutures);
        });
  }

  /// 단일 카테고리 실시간 스트림 (프로필 이미지 포함)
  Stream<CategoryDataModel?> getCategoryStream(String categoryId) {
    return _firestore
        .collection('categories')
        .doc(categoryId)
        .snapshots()
        .asyncMap((doc) async {
          // 조기 반환: 문서가 없으면 null
          if (!doc.exists) return null;

          final data = doc.data();
          if (data == null) return null;

          // 사용자가 설정한 커버 사진이 있는지 확인
          String? categoryPhotoUrl = data['categoryPhotoUrl'] as String?;

          // 커버 사진이 없다면 가장 최근 사진을 가져오기 (최적화: 조건 간소화)
          if (categoryPhotoUrl?.isEmpty ?? true) {
            final photosSnapshot = await _firestore
                .collection('categories')
                .doc(categoryId)
                .collection('photos')
                .where('unactive', isEqualTo: false) // 비활성화된 사진 제외
                .orderBy('createdAt', descending: true)
                .limit(1)
                .get();

            if (photosSnapshot.docs.isNotEmpty) {
              categoryPhotoUrl =
                  photosSnapshot.docs.first.data()['imageUrl'] as String?;
            }
          }

          // mateProfileImages는 fromFirestore()에서 이미 파싱되므로
          // 별도의 Firestore 쿼리 없이 바로 사용
          return CategoryDataModel.fromFirestore(
            data,
            doc.id,
          ).copyWith(categoryPhotoUrl: categoryPhotoUrl);
        })
        .distinct(); // 중복 이벤트 필터링으로 불필요한 재렌더링 방지
  }

  /// 사용자의 카테고리 목록을 한 번만 가져오기 (병렬 처리 최적화)
  Future<List<CategoryDataModel>> getUserCategories(String userId) async {
    // Firebase Auth UID로 카테고리 검색
    var querySnapshot = await _firestore
        .collection('categories')
        .where('mates', arrayContains: userId)
        .get();

    // 병렬로 모든 카테고리의 커버 사진을 가져오기
    final categoryFutures = querySnapshot.docs.map((doc) async {
      final data = doc.data();
      String? categoryPhotoUrl = data['categoryPhotoUrl'] as String?;

      // 커버 사진이 없는 경우에만 최신 사진 쿼리
      if (categoryPhotoUrl == null || categoryPhotoUrl.isEmpty) {
        final photosSnapshot = await _firestore
            .collection('categories')
            .doc(doc.id)
            .collection('photos')
            .where('unactive', isEqualTo: false)
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

        if (photosSnapshot.docs.isNotEmpty) {
          categoryPhotoUrl =
              photosSnapshot.docs.first.data()['imageUrl'] as String?;
        }
      }

      return CategoryDataModel.fromFirestore(
        data,
        doc.id,
      ).copyWith(categoryPhotoUrl: categoryPhotoUrl);
    }).toList();

    // 모든 쿼리를 병렬로 실행 (N개 카테고리 → 1번의 병렬 호출)
    return await Future.wait(categoryFutures);
  }

  /// 카테고리 생성
  Future<String> createCategory(CategoryDataModel category) async {
    final docRef = await _firestore
        .collection('categories')
        .add(category.toFirestore());
    return docRef.id;
  }

  /// 카테고리 업데이트
  Future<void> updateCategory(
    String categoryId,
    Map<String, dynamic> data,
  ) async {
    if (data.isEmpty) return;

    // 값이 null이거나 빈 문자열인 항목은 제외
    // sanitizedEntries란, null 또는 빈 문자열이 아닌 항목들의 Iterable<MapEntry<String, dynamic>>
    // 이를 통해 Firestore에 불필요한 빈 값이 저장되는 것을 방지
    final sanitizedEntries = data.entries.where((entry) {
      final value = entry.value;
      if (value is String) {
        return value.trim().isNotEmpty;
      }
      return value != null;
    });

    if (sanitizedEntries.isEmpty) return;

    final docRef = _firestore.collection('categories').doc(categoryId);
    await docRef.update(Map<String, dynamic>.fromEntries(sanitizedEntries));
  }

  /// 사용자별 커스텀 이름 업데이트
  Future<void> updateCustomName({
    required String categoryId,
    required String userId,
    required String customName,
  }) async {
    await _firestore.collection('categories').doc(categoryId).update({
      'customNames.$userId': customName,
    });
  }

  /// 사용자별 고정 상태 업데이트
  Future<void> updateUserPinStatus({
    required String categoryId,
    required String userId,
    required bool isPinned,
  }) async {
    await _firestore.collection('categories').doc(categoryId).update({
      'userPinnedStatus.$userId': isPinned,
    });
  }

  /// 카테고리 삭제
  Future<void> deleteCategory(String categoryId) async {
    final categoryRef = _firestore.collection('categories').doc(categoryId);
    const int batchSize = 300; // Firestore batch limit은 500 (docs)

    // 사진들을 배치로 삭제
    // 배치로 삭제한다는 것은 한 번에 여러 문서를 모아서 삭제하는 것을 의미
    Future<int> deletePhotosBatch() async {
      final photosSnapshot = await categoryRef
          .collection('photos')
          .limit(batchSize)
          .get();

      if (photosSnapshot.docs.isEmpty) {
        return 0;
      }
      // Batch 삭제 수행
      // Firestore의 batch 기능을 사용하여 여러 문서를 한 번에 삭제
      // 이렇게 하면 네트워크 호출 횟수를 줄이고 성능을 향상시킬 수 있음
      final batch = _firestore.batch();
      for (final doc in photosSnapshot.docs) {
        batch.delete(doc.reference);
      }
      // batch.commit()를 호출하여 실제로 삭제 작업을 수행
      await batch.commit();
      return photosSnapshot.docs.length;
    }

    int deleted;
    do {
      deleted = await deletePhotosBatch();
    } while (deleted == batchSize);

    await categoryRef.delete();
  }

  /// 특정 카테고리 정보 가져오기 (최적화: 커버 사진 있으면 추가 쿼리 스킵)
  Future<CategoryDataModel?> getCategory(String categoryId) async {
    final docRef = _firestore.collection('categories').doc(categoryId);
    final doc = await docRef.get();

    if (!doc.exists || doc.data() == null) return null;

    final data = doc.data()!;
    String? categoryPhotoUrl = data['categoryPhotoUrl'] as String?;

    if (categoryPhotoUrl != null && categoryPhotoUrl.isNotEmpty) {
      _categoryCoverCache[categoryId] = categoryPhotoUrl;
    } else {
      if (_categoryCoverCache.containsKey(categoryId)) {
        categoryPhotoUrl = _categoryCoverCache[categoryId];
      } else {
        final photosSnapshot = await docRef
            .collection('photos')
            .where('unactive', isEqualTo: false)
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

        if (photosSnapshot.docs.isNotEmpty) {
          categoryPhotoUrl =
              photosSnapshot.docs.first.data()['imageUrl'] as String?;
        }
        _categoryCoverCache[categoryId] = categoryPhotoUrl;
      }
    }

    return CategoryDataModel.fromFirestore(
      data,
      doc.id,
    ).copyWith(categoryPhotoUrl: categoryPhotoUrl);
  }

  // ==================== 기존 호환성 메서드 ====================

  /// 카테고리 표지사진 업데이트
  Future<void> updateCategoryPhoto({
    required String categoryId,
    required String photoUrl,
  }) async {
    await _firestore.collection('categories').doc(categoryId).update({
      'categoryPhotoUrl': photoUrl,
    });
  }

  /// 카테고리 표지사진 삭제
  Future<void> deleteCategoryPhoto(String categoryId) async {
    await _firestore.collection('categories').doc(categoryId).update({
      'categoryPhotoUrl': FieldValue.delete(),
    });
  }

  /// 표지사진용 이미지 업로드
  Future<String> uploadCoverImage(String categoryId, File imageFile) async {
    final supabase = Supabase.instance.client;
    final fileName =
        'cover_${categoryId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    // supabase storage에 커버 이미지 업로드
    await supabase.storage.from('covers').upload(fileName, imageFile);

    // 즉시 공개 URL 생성 (다운로드 API 호출 없음)
    final publicUrl = supabase.storage.from('covers').getPublicUrl(fileName);

    return publicUrl;
  }

  /// 카테고리에 사용자 추가 (UID로)
  Future<void> addUidToCategory({
    required String categoryId,
    required String uid,
  }) async {
    try {
      // 먼저 카테고리가 존재하는지 확인
      final categoryDoc = await _firestore
          .collection('categories')
          .doc(categoryId)
          .get();
      if (!categoryDoc.exists) {
        throw Exception('카테고리가 존재하지 않습니다: $categoryId');
      }

      // 현재 mates 목록 확인
      final data = categoryDoc.data();
      final currentMates = (data?['mates'] as List?)?.cast<String>() ?? [];

      if (currentMates.contains(uid)) {
        return; // 이미 포함되어 있으면 아무 작업하지 않음
      }

      // arrayUnion을 사용하여 중복 없이 추가
      await _firestore.collection('categories').doc(categoryId).update({
        'mates': FieldValue.arrayUnion([uid]),
      });
    } catch (e) {
      debugPrint('Firestore 업데이트 실패: $e');
      rethrow;
    }
  }

  /// 카테고리에서 사용자 제거 (UID로)
  Future<void> removeUidFromCategory({
    required String categoryId,
    required String uid,
  }) async {
    try {
      // 카테고리가 존재하는지 확인
      final categoryDoc = await _firestore
          .collection('categories')
          .doc(categoryId)
          .get();
      if (!categoryDoc.exists) {
        throw Exception('카테고리가 존재하지 않습니다: $categoryId');
      }

      // arrayRemove를 사용하여 제거
      await _firestore.collection('categories').doc(categoryId).update({
        'mates': FieldValue.arrayRemove([uid]),
      });
    } catch (e) {
      debugPrint('카테고리에서 사용자 제거 실패: $e');
      rethrow;
    }
  }

  /// 사용자의 프로필 이미지가 변경될 때, 해당 사용자가 속한 모든 카테고리의 mateProfileImages 업데이트
  Future<void> updateUserProfileImageInCategories({
    required String userId,
    required String newProfileImageUrl,
  }) async {
    try {
      // 사용자가 속한 모든 카테고리 조회
      final querySnapshot = await _firestore
          .collection('categories')
          .where('mates', arrayContains: userId)
          .get();

      if (querySnapshot.docs.isEmpty) {
        debugPrint('프로필 이미지 업데이트: 사용자가 속한 카테고리가 없습니다.');
        return;
      }

      // Batch를 사용하여 여러 카테고리를 한 번에 업데이트
      final batch = _firestore.batch();

      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {
          'mateProfileImages.$userId': newProfileImageUrl,
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('카테고리 프로필 이미지 업데이트 실패: $e');
      // 실패해도 프로필 업데이트 자체는 성공했으므로 rethrow하지 않음
    }
  }
}
