import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category_data_model.dart';

/// Firebase에서 category 관련 데이터를 가져오고, 저장하고, 업데이트하고 삭제하는 등의 로직들
class CategoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ==================== Firestore 관련 ====================

  /// 사용자의 카테고리 목록을 스트림으로 가져오기
  Stream<List<CategoryDataModel>> getUserCategoriesStream(String userId) {
    return _firestore
        .collection('categories')
        .where('mates', arrayContains: userId)
        .snapshots()
        .asyncMap((querySnapshot) async {
          final categories = <CategoryDataModel>[];

          for (final doc in querySnapshot.docs) {
            final data = doc.data();

            // 사용자가 설정한 커버 사진이 있는지 확인
            String? categoryPhotoUrl = data['categoryPhotoUrl'] as String?;

            // 커버 사진이 없다면 가장 최근 사진을 가져오기
            if (categoryPhotoUrl == null || categoryPhotoUrl.isEmpty) {
              final photosSnapshot =
                  await _firestore
                      .collection('categories')
                      .doc(doc.id)
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

            final category = CategoryDataModel.fromFirestore(
              data,
              doc.id,
            ).copyWith(categoryPhotoUrl: categoryPhotoUrl);

            categories.add(category);
          }

          return categories;
        });
  }

  /// 단일 카테고리 실시간 스트림
  Stream<CategoryDataModel?> getCategoryStream(String categoryId) {
    return _firestore
        .collection('categories')
        .doc(categoryId)
        .snapshots()
        .asyncMap((doc) async {
          if (!doc.exists || doc.data() == null) return null;

          final data = doc.data()!;

          // 사용자가 설정한 커버 사진이 있는지 확인
          String? categoryPhotoUrl = data['categoryPhotoUrl'] as String?;

          // 커버 사진이 없다면 가장 최근 사진을 가져오기
          if (categoryPhotoUrl == null || categoryPhotoUrl.isEmpty) {
            final photosSnapshot =
                await _firestore
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
            } else {}
          }

          final result = CategoryDataModel.fromFirestore(
            data,
            doc.id,
          ).copyWith(categoryPhotoUrl: categoryPhotoUrl);

          return result;
        });
  }

  /// 사용자의 카테고리 목록을 한 번만 가져오기
  Future<List<CategoryDataModel>> getUserCategories(String userId) async {
    // Firebase Auth UID로 카테고리 검색
    var querySnapshot =
        await _firestore
            .collection('categories')
            .where('mates', arrayContains: userId)
            .get();

    // 쿼리 결과가 있으면 각 문서의 mates 배열을 확인
    if (querySnapshot.docs.isNotEmpty) {
      // 문서의 mates 배열 확인 완료
    }

    // 만약 UID로 찾은 결과가 없다면, 사용자 닉네임으로도 검색해보기
    if (querySnapshot.docs.isEmpty) {
      try {
        // 사용자 문서에서 닉네임 가져오기
        final userDoc = await _firestore.collection('users').doc(userId).get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          // 사용자 문서 데이터 확인
          final nickName = userData['id'] as String?; // 'id' 필드에 닉네임이 저장됨

          if (nickName != null && nickName.isNotEmpty) {
            querySnapshot =
                await _firestore
                    .collection('categories')
                    .where('mates', arrayContains: nickName)
                    .get();

            // 닉네임 검색 결과도 확인
            if (querySnapshot.docs.isNotEmpty) {
              // 문서의 mates 배열 확인 완료
            }
          } else {
            // 닉네임이 없거나 비어있는 경우
            debugPrint('사용자 닉네임이 없습니다.');
          }
        }
      } catch (e) {
        // 사용자 문서가 없거나 닉네임을 찾을 수 없는 경우
        debugPrint('사용자 닉네임을 가져오는 중 오류 발생: $e');
      }
    }

    final categories = <CategoryDataModel>[];

    for (final doc in querySnapshot.docs) {
      final data = doc.data();

      // 사용자가 설정한 커버 사진이 있는지 확인
      String? categoryPhotoUrl = data['categoryPhotoUrl'] as String?;

      // 커버 사진이 없다면 가장 최근 사진을 가져오기
      if (categoryPhotoUrl == null || categoryPhotoUrl.isEmpty) {
        final photosSnapshot =
            await _firestore
                .collection('categories')
                .doc(doc.id)
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

      final category = CategoryDataModel.fromFirestore(
        data,
        doc.id,
      ).copyWith(categoryPhotoUrl: categoryPhotoUrl);

      categories.add(category);
    }

    return categories;
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
    await _firestore.collection('categories').doc(categoryId).update(data);
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
    // 카테고리와 관련된 모든 사진도 삭제
    final photosSnapshot =
        await _firestore
            .collection('categories')
            .doc(categoryId)
            .collection('photos')
            .get();

    final batch = _firestore.batch();

    // 사진 문서들 삭제
    for (final doc in photosSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // 카테고리 문서 삭제
    batch.delete(_firestore.collection('categories').doc(categoryId));

    await batch.commit();
  }

  /// 특정 카테고리 정보 가져오기
  Future<CategoryDataModel?> getCategory(String categoryId) async {
    final doc = await _firestore.collection('categories').doc(categoryId).get();

    if (!doc.exists || doc.data() == null) return null;

    // 첫 번째 사진 URL과 사진 개수를 가져오기
    final photosSnapshot =
        await _firestore
            .collection('categories')
            .doc(categoryId)
            .collection('photos')
            .where('unactive', isEqualTo: false) // 비활성화된 사진 제외
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

    String? categoryPhotoUrl;
    if (photosSnapshot.docs.isNotEmpty) {
      categoryPhotoUrl =
          photosSnapshot.docs.first.data()['imageUrl'] as String?;
    }

    return CategoryDataModel.fromFirestore(
      doc.data()!,
      doc.id,
    ).copyWith(categoryPhotoUrl: categoryPhotoUrl);
  }

  /// 카테고리에게 사진 추가
  Future<String> addPhotoToCategory(
    String categoryId,
    Map<String, dynamic> photoData,
  ) async {
    final docRef = await _firestore
        .collection('categories')
        .doc(categoryId)
        .collection('photos')
        .add(photoData);
    return docRef.id;
  }

  /// 카테고리에서 사진 삭제
  Future<void> removePhotoFromCategory(
    String categoryId,
    String photoId,
  ) async {
    await _firestore
        .collection('categories')
        .doc(categoryId)
        .collection('photos')
        .doc(photoId)
        .delete();
  }

  /// 카테고리의 사진들 가져오기
  Future<List<Map<String, dynamic>>> getCategoryPhotos(
    String categoryId,
  ) async {
    final querySnapshot =
        await _firestore
            .collection('categories')
            .doc(categoryId)
            .collection('photos')
            .orderBy('createdAt', descending: true)
            .get();

    return querySnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
  }

  // ==================== Storage 관련 ====================

  /// 이미지 업로드
  Future<String> uploadImage(String categoryId, File imageFile) async {
    final fileName =
        'category_${categoryId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage
        .ref()
        .child('categories')
        .child(categoryId)
        .child(fileName);

    final uploadTask = ref.putFile(imageFile);
    final snapshot = await uploadTask.whenComplete(() => null);

    return await snapshot.ref.getDownloadURL();
  }

  /// 이미지 삭제
  Future<void> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      throw Exception('이미지 삭제에 실패했습니다.');
    }
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

  /// 카테고리 사진 스트림 (Map 형태로 반환)
  Stream<List<Map<String, dynamic>>> getCategoryPhotosStream(
    String categoryId,
  ) {
    return _firestore
        .collection('categories')
        .doc(categoryId)
        .collection('photos')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return data;
              }).toList(),
        );
  }

  /// 카테고리에 사용자 추가 (닉네임으로)
  Future<void> addUserToCategory({
    required String categoryId,
    required String nickName,
  }) async {
    await _firestore.collection('categories').doc(categoryId).update({
      'mates': FieldValue.arrayUnion([nickName]),
    });
  }

  /// 카테고리에 사용자 추가 (UID로)
  /// 카테고리에 사용자 추가 (UID로)
  Future<void> addUidToCategory({
    required String categoryId,
    required String uid,
  }) async {
    try {
      // 먼저 카테고리가 존재하는지 확인
      final categoryDoc =
          await _firestore.collection('categories').doc(categoryId).get();
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
      final categoryDoc =
          await _firestore.collection('categories').doc(categoryId).get();
      if (!categoryDoc.exists) {
        throw Exception('카테고리가 존재하지 않습니다: $categoryId');
      }

      // arrayRemove를 사용하여 제거
      await _firestore.collection('categories').doc(categoryId).update({
        'mates': FieldValue.arrayRemove([uid]),
      });
    } catch (e) {
      debugPrint('❌ 카테고리에서 사용자 제거 실패: $e');
      rethrow;
    }
  }
}
