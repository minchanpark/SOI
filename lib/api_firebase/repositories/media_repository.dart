import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/photo_data_model.dart';

/// MediaRepository  - Firebase와 관련된 모든 데이터 액세스 로직을 담당
class MediaRepository {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // ==================== 사진 업로드 ====================

  // 이미지 파일을 supabase Storage에 업로드
  Future<String?> uploadImageToStorage({
    required File imageFile,
    required String categoryId,
    required String userId,
    String? customFileName,
  }) async {
    final supabase = Supabase.instance.client;
    try {
      final fileName =
          customFileName ??
          '${categoryId}_${userId}_${DateTime.now().millisecondsSinceEpoch}.png';

      // supabase storage에 사진 업로드 - 완료될 때까지 기다림
      await supabase.storage.from('photos').upload(fileName, imageFile);

      // 업로드 완료 후 공개 URL 생성
      final publicUrl = supabase.storage.from('photos').getPublicUrl(fileName);

      // 업로드 완료된 공개 URL 반환
      return publicUrl;
    } catch (e) {
      debugPrint('이미지 업로드 오류: $e');
      return null;
    }
  }

  /// 사진 메타데이터를 Firestore에 저장
  Future<String?> savePhotoToFirestore({
    required MediaDataModel photo,
    required String categoryId,
  }) async {
    try {
      // 1. 사진 저장
      final docRef = await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('photos')
          .add(photo.toFirestore());

      // 2. 카테고리에 사진이 처음 추가되는 경우, 자동으로 표지사진 설정
      final categoryDoc = await _firestore
          .collection('categories')
          .doc(categoryId)
          .get();
      if (categoryDoc.exists) {
        final categoryData = categoryDoc.data() as Map<String, dynamic>;
        if (categoryData['categoryPhotoUrl'] == null ||
            categoryData['categoryPhotoUrl'] == '') {
          await _firestore.collection('categories').doc(categoryId).update({
            'categoryPhotoUrl': photo.imageUrl,
          });
        }
      }

      return docRef.id;
    } catch (e) {
      return null;
    }
  }

  /// 사진 데이터와 파형 데이터 함께 저장
  Future<String> savePhotoWithWaveform({
    required String imageUrl,
    required String audioUrl,
    required String userID,
    required List<String> userIds,
    required String categoryId,
    List<double>? waveformData,
    Duration? duration,
    String? caption,
  }) async {
    try {
      // 기본 데이터 구성
      final Map<String, dynamic> photoData = {
        'imageUrl': imageUrl,
        'audioUrl': audioUrl,
        'userID': userID,
        'userIds': userIds,
        'categoryId': categoryId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': PhotoStatus.active.name,
        'duration': duration?.inSeconds ?? 0,
      };

      // caption이 있을 때만 추가
      if (caption != null && caption.isNotEmpty) {
        photoData['caption'] = caption;
      }

      // 파형 데이터 처리 및 상세 로그

      // 파형 데이터 처리 및 상세 로그
      if (waveformData != null && waveformData.isNotEmpty) {
        // 유효한 파형 데이터가 있는 경우
        photoData['waveformData'] = waveformData;
      } else {
        // 파형 데이터가 없는 경우 빈 배열로 저장
        photoData['waveformData'] = [];
      }

      final docRef = await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('photos')
          .add(photoData);

      // 카테고리의 firstPhotoUrl 업데이트
      try {
        await _firestore.collection('categories').doc(categoryId).update({
          'firstPhotoUrl': imageUrl,
        });
      } catch (e) {
        debugPrint('카테고리 firstPhotoUrl 업데이트 실패: $e');
      }

      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  // ==================== 비디오 관련 로직 ===============
  // 비디오 파일을 supabase Storage에 업로드
  Future<String?> uploadVideoToStorage({
    required File videoFile,
    required String categoryId,
    required String userId,
    String? customFileName,
  }) async {
    final supabase = Supabase.instance.client;
    try {
      final fileName =
          customFileName ??
          '${categoryId}_${userId}_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // supabase storage에 사진 업로드 - 완료될 때까지 기다림
      await supabase.storage.from('video').upload(fileName, videoFile);

      // 업로드 완료 후 공개 URL 생성
      final publicUrl = supabase.storage.from('video').getPublicUrl(fileName);

      // 업로드 완료된 공개 URL 반환
      return publicUrl;
    } catch (e) {
      debugPrint('비디오 업로드 오류: $e');
      return null;
    }
  }

  /// 비디오 메타데이터를 Firestore에 저장
  Future<String?> saveVideoToFirestore({
    required MediaDataModel video,
    required String categoryId,
  }) async {
    try {
      // 1. 비디오 저장
      final docRef = await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('photos')
          .add(video.toFirestore());

      // 2. 카테고리에 사진이 처음 추가되는 경우, 자동으로 표지사진 설정
      final categoryDoc = await _firestore
          .collection('categories')
          .doc(categoryId)
          .get();
      if (categoryDoc.exists) {
        final categoryData = categoryDoc.data() as Map<String, dynamic>;
        if (categoryData['categoryPhotoUrl'] == null ||
            categoryData['categoryPhotoUrl'] == '') {
          await _firestore.collection('categories').doc(categoryId).update({
            'categoryPhotoUrl': video.thumbnailUrl,
          });
        }
      }

      return docRef.id;
    } catch (e) {
      return null;
    }
  }

  // ==================== 사진 조회 ====================

  /// 카테고리별 사진 목록 조회
  Future<List<MediaDataModel>> getPhotosByCategory(String categoryId) async {
    try {
      final querySnapshot = await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('photos')
          .where('status', isEqualTo: PhotoStatus.active.name)
          .where('unactive', isEqualTo: false) // 비활성화된 사진 제외
          .orderBy('createdAt', descending: true)
          .get();

      final photos = querySnapshot.docs.map((doc) {
        final data = doc.data();

        return MediaDataModel.fromFirestore(data, doc.id);
      }).toList();

      return photos;
    } catch (e) {
      return [];
    }
  }

  /// 모든 카테고리에서 사진을 페이지네이션으로 조회 (무한 스크롤용)
  Future<({List<MediaDataModel> photos, String? lastPhotoId, bool hasMore})>
  getPhotosFromAllCategoriesPaginated({
    required List<String> categoryIds,
    int limit = 20,
    String? startAfterPhotoId,
  }) async {
    try {
      List<MediaDataModel> allPhotos = [];

      // 모든 카테고리에서 사진을 가져와서 합치기
      for (String categoryId in categoryIds) {
        final categoryPhotos = await _getSingleCategoryPhotos(categoryId);
        allPhotos.addAll(categoryPhotos);
      }

      // 최신순으로 정렬
      allPhotos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // startAfterPhotoId가 있다면 해당 위치 이후부터 가져오기
      int startIndex = 0;
      if (startAfterPhotoId != null) {
        startIndex =
            allPhotos.indexWhere((photo) => photo.id == startAfterPhotoId) + 1;
        if (startIndex <= 0) startIndex = 0;
      }

      // 페이지네이션 적용
      final endIndex = (startIndex + limit).clamp(0, allPhotos.length);
      final paginatedPhotos = allPhotos.sublist(startIndex, endIndex);

      // 마지막 사진 ID와 더 있는지 여부 확인
      String? lastPhotoId;
      bool hasMore = endIndex < allPhotos.length;

      if (paginatedPhotos.isNotEmpty) {
        lastPhotoId = paginatedPhotos.last.id;
      }

      return (
        photos: paginatedPhotos,
        lastPhotoId: lastPhotoId,
        hasMore: hasMore,
      );
    } catch (e) {
      return (photos: <MediaDataModel>[], lastPhotoId: null, hasMore: false);
    }
  }

  /// 단일 카테고리에서 사진 조회 (내부 헬퍼 메서드)
  Future<List<MediaDataModel>> _getSingleCategoryPhotos(
    String categoryId,
  ) async {
    try {
      // 먼저 가장 간단한 쿼리로 시도 (인덱스 문제 회피)
      final querySnapshot = await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('photos')
          .get();

      if (querySnapshot.docs.isEmpty) {
        return [];
      }

      // 문서를 PhotoDataModel로 변환하고 필터링/정렬
      final photos = querySnapshot.docs
          .map((doc) {
            final data = doc.data();

            return MediaDataModel.fromFirestore(data, doc.id);
          })
          .where(
            (photo) => photo.status == PhotoStatus.active && !photo.unactive,
          )
          .toList();

      // 메모리에서 정렬
      photos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return photos;
    } catch (e) {
      return [];
    }
  }

  /// 카테고리별 사진 목록 조회 (기존 호환성 유지)
  Future<List<MediaDataModel>> getPhotosByCategoryLegacy(
    String categoryId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('photos')
          .where('status', isEqualTo: PhotoStatus.active.name)
          .where('unactive', isEqualTo: false) // 비활성화된 사진 제외
          .orderBy('createdAt', descending: true)
          .get();

      final photos = querySnapshot.docs.map((doc) {
        final data = doc.data();

        return MediaDataModel.fromFirestore(data, doc.id);
      }).toList();

      return photos;
    } catch (e) {
      return [];
    }
  }

  /// 카테고리별 사진 목록 스트림
  Stream<List<MediaDataModel>> getPhotosByCategoryStream(String categoryId) {
    // 복합 쿼리 인덱스 없이도 작동하도록 수동 필터링 사용
    return _firestore
        .collection('categories')
        .doc(categoryId)
        .collection('photos')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final allPhotos = snapshot.docs.map((doc) {
            final data = doc.data();
            return MediaDataModel.fromFirestore(data, doc.id);
          }).toList();

          // 메모리에서 필터링 (status: active, unactive: false)
          return allPhotos.where((photo) {
            return photo.status == PhotoStatus.active &&
                photo.unactive == false;
          }).toList();
        });
  }

  /// 사용자별 사진 목록 조회
  Future<List<MediaDataModel>> getPhotosByUser(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collectionGroup('photos')
          .where('userID', isEqualTo: userId)
          .where('status', isEqualTo: PhotoStatus.active.name)
          .where('unactive', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => MediaDataModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 특정 사진 조회
  Future<MediaDataModel?> getPhotoById({
    required String categoryId,
    required String photoId,
  }) async {
    try {
      final doc = await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('photos')
          .doc(photoId)
          .get();

      if (doc.exists && doc.data() != null) {
        return MediaDataModel.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('사진 조회 오류: $e');
      return null;
    }
  }

  // ==================== 사진 삭제 ====================

  /// 사진 삭제 (soft delete)
  Future<bool> deletePhoto({
    required String categoryId,
    required String photoId,
  }) async {
    try {
      await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('photos')
          .doc(photoId)
          .update({
            'status': PhotoStatus.deleted.name,
            'deletedAt': Timestamp.now(), // 삭제 시간 기록
            'updatedAt': Timestamp.now(),
          });

      return true;
    } catch (e) {
      debugPrint('사진 삭제 오류: $e');
      return false;
    }
  }

  /// 삭제된 사진 목록 조회 (사용자별)
  Future<List<MediaDataModel>> getDeletedPhotosByUser(String userId) async {
    try {
      // 1. 사용자가 속한 모든 카테고리 조회
      final categorySnapshot = await _firestore
          .collection('categories')
          .where('mates', arrayContains: userId)
          .get();

      List<MediaDataModel> deletedPhotos = [];
      Set<String> seenPhotoIds = {}; // 중복 방지

      // 2. 각 카테고리에서 삭제된 사진들 조회
      for (final categoryDoc in categorySnapshot.docs) {
        try {
          final photosSnapshot = await categoryDoc.reference
              .collection('photos')
              .where('status', isEqualTo: PhotoStatus.deleted.name)
              .orderBy('deletedAt', descending: true)
              .get();

          for (final photoDoc in photosSnapshot.docs) {
            // 중복 방지 (같은 사진이 여러 카테고리에 있을 수 있음)
            if (!seenPhotoIds.add(photoDoc.id)) {
              continue;
            }

            final photoData = MediaDataModel.fromFirestore(
              photoDoc.data(),
              photoDoc.id,
            );

            deletedPhotos.add(photoData);
          }
        } catch (e) {
          debugPrint('카테고리 ${categoryDoc.id} 삭제된 사진 조회 오류: $e');
          continue; // 개별 카테고리 오류는 무시하고 계속 진행
        }
      }

      // 3. 삭제 시간 기준으로 정렬 (최신순)
      deletedPhotos.sort((a, b) {
        final aDeletedAt =
            a.deletedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDeletedAt =
            b.deletedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDeletedAt.compareTo(aDeletedAt);
      });

      return deletedPhotos;
    } catch (e) {
      debugPrint('삭제된 사진 조회 전체 오류: $e');
      return [];
    }
  }

  /// 사진 복원 (deleted -> active)
  Future<bool> restorePhoto({
    required String categoryId,
    required String photoId,
  }) async {
    try {
      await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('photos')
          .doc(photoId)
          .update({
            'status': PhotoStatus.active.name,
            'deletedAt': FieldValue.delete(), // 삭제 시간 필드 제거
            'updatedAt': Timestamp.now(),
          });

      return true;
    } catch (e) {
      debugPrint('사진 복원 오류: $e');
      return false;
    }
  }

  /// 사진 완전 삭제 (하드 삭제)
  Future<bool> permanentDeletePhoto({
    required String categoryId,
    required String photoId,
    String? imageUrl,
    String? audioUrl,
  }) async {
    try {
      // Firestore 문서 삭제
      await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('photos')
          .doc(photoId)
          .delete();

      // Storage 파일 삭제
      if (imageUrl != null) {
        await _deleteStorageFile(imageUrl);
      }
      if (audioUrl != null) {
        await _deleteStorageFile(audioUrl);
      }

      return true;
    } catch (e) {
      debugPrint('사진 완전 삭제 오류: $e');
      return false;
    }
  }

  // ==================== 기존 호환성 메서드 ====================

  /// 기존 PhotoModel과의 호환성을 위한 스트림
  Stream<List<Map<String, dynamic>>> getCategoryPhotosStreamAsMap(
    String categoryId,
  ) {
    return _firestore
        .collection('categories')
        .doc(categoryId)
        .collection('photos')
        .where('status', isEqualTo: PhotoStatus.active.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;

            return data;
          }).toList();
        });
  }

  // ==================== 유틸리티 메서드 ====================

  /// Storage 파일 삭제
  Future<void> _deleteStorageFile(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (e) {
      debugPrint('Storage 파일 삭제 오류: $e');
    }
  }

  /// 현재 사용자 ID 가져오기
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  /// 사진 통계 조회
  Future<Map<String, int>> getPhotoStats(String categoryId) async {
    try {
      final querySnapshot = await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('photos')
          .get();

      int totalPhotos = 0;
      int activePhotos = 0;
      int deletedPhotos = 0;

      for (final doc in querySnapshot.docs) {
        totalPhotos++;
        final status = doc.data()['status'] ?? PhotoStatus.active.name;
        if (status == PhotoStatus.active.name) {
          activePhotos++;
        } else if (status == PhotoStatus.deleted.name) {
          deletedPhotos++;
        }
      }

      return {
        'total': totalPhotos,
        'active': activePhotos,
        'deleted': deletedPhotos,
      };
    } catch (e) {
      debugPrint('사진 통계 조회 오류: $e');
      return {'total': 0, 'active': 0, 'deleted': 0};
    }
  }

  /// 기존 사진들에 파형 데이터 일괄 추가 (유틸리티)
  Future<void> addWaveformDataToExistingPhotos({
    required String categoryId,
    required Function(String audioUrl) extractWaveformData,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('photos')
          .where('status', isEqualTo: PhotoStatus.active.name)
          .where('audioUrl', isNotEqualTo: '')
          .get();

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final audioUrl = data['audioUrl'] as String?;
        final existingWaveform = data['waveformData'] as List?;

        // 이미 파형 데이터가 있으면 스킵
        if (existingWaveform != null && existingWaveform.isNotEmpty) {
          continue;
        }

        if (audioUrl != null && audioUrl.isNotEmpty) {
          try {
            // 파형 데이터 추출 (외부에서 전달받은 함수 사용)
            final waveformData = await extractWaveformData(audioUrl);

            if (waveformData.isNotEmpty) {
              // Firestore 업데이트
              await doc.reference.update({
                'waveformData': waveformData,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            } else {
              debugPrint('⚠️ 파형 데이터 추출 실패: ${doc.id}');
            }
          } catch (e) {
            debugPrint('❌ 파형 데이터 추출 오류 (${doc.id}): $e');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ 파형 데이터 일괄 추가 실패: $e');
      rethrow;
    }
  }

  /// 특정 사진에 파형 데이터 추가
  Future<bool> addWaveformDataToPhoto({
    required String categoryId,
    required String photoId,
    required List<double> waveformData,
    double? audioDuration,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'waveformData': waveformData,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (audioDuration != null) {
        updateData['audioDuration'] = audioDuration;
      }

      await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('photos')
          .doc(photoId)
          .update(updateData);

      return true;
    } catch (e) {
      debugPrint('❌ 파형 데이터 추가 실패: $e');
      return false;
    }
  }

  /// 파형 데이터 압축 (공개 메서드)
  List<double> compressWaveformData(
    List<double> data, {
    int targetLength = 100,
  }) {
    if (data.length <= targetLength) return data;

    final step = data.length / targetLength;
    final compressed = <double>[];

    for (int i = 0; i < targetLength; i++) {
      final startIndex = (i * step).floor();
      final endIndex = ((i + 1) * step).floor().clamp(0, data.length);

      // 구간 내 최대값 추출 (피크 보존)
      double maxValue = 0.0;
      for (int j = startIndex; j < endIndex; j++) {
        maxValue = math.max(maxValue, data[j].abs());
      }
      compressed.add(maxValue);
    }

    return compressed;
  }
}
