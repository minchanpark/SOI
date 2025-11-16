import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../repositories/category_repository.dart';
import '../models/auth_result.dart';
import 'notification_service.dart';
import 'media_service.dart';
import 'friend_service.dart';
import '../repositories/friend_repository.dart';
import '../repositories/user_search_repository.dart';

/// 카테고리 사진 및 표지사진 관리 Service
class CategoryPhotoService {
  // Singleton pattern
  static final CategoryPhotoService _instance =
      CategoryPhotoService._internal();
  factory CategoryPhotoService() => _instance;
  CategoryPhotoService._internal();

  final CategoryRepository _repository = CategoryRepository();

  // lazy 초기화
  NotificationService? _notificationService;
  NotificationService get notificationService {
    _notificationService ??= NotificationService();
    return _notificationService!;
  }

  PhotoService? _photoService;
  PhotoService get photoService {
    _photoService ??= PhotoService();
    return _photoService!;
  }

  FriendService? _friendService;
  FriendService get friendService {
    _friendService ??= FriendService(
      friendRepository: FriendRepository(),
      userSearchRepository: UserSearchRepository(),
    );
    return _friendService!;
  }

  /// 카테고리에 사진 추가
  Future<AuthResult> addPhoto({
    required String categoryId,
    required File imageFile,
    String? description,
  }) async {
    try {
      if (categoryId.isEmpty) {
        return AuthResult.failure('유효하지 않은 카테고리입니다.');
      }

      final imageUrl = await _repository.uploadImage(categoryId, imageFile);

      final photoData = {
        'url': imageUrl,
        'description': description ?? '',
        'createdAt': DateTime.now(),
      };

      final photoId = await _repository.addPhotoToCategory(
        categoryId,
        photoData,
      );

      return AuthResult.success(photoId);
    } catch (e) {
      return AuthResult.failure('사진 추가 중 오류가 발생했습니다.');
    }
  }

  /// 카테고리에서 사진 삭제
  Future<AuthResult> removePhoto({
    required String categoryId,
    required String photoId,
    required String imageUrl,
  }) async {
    try {
      if (categoryId.isEmpty || photoId.isEmpty) {
        return AuthResult.failure('유효하지 않은 정보입니다.');
      }

      await _repository.deleteImage(imageUrl);
      await _repository.removePhotoFromCategory(categoryId, photoId);

      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure('사진 삭제 중 오류가 발생했습니다.');
    }
  }

  /// 카테고리 사진 목록 가져오기 (차단 필터링 포함)
  Future<List<Map<String, dynamic>>> getPhotos(String categoryId) async {
    try {
      if (categoryId.isEmpty) return [];

      final allPhotos = await _repository.getCategoryPhotos(categoryId);
      final blockedByMe = await friendService.getBlockedUsers();

      return allPhotos.where((photo) {
        final photoUserId = photo['userId'] as String?;
        return photoUserId == null || !blockedByMe.contains(photoUserId);
      }).toList();
    } catch (e) {
      debugPrint('getPhotos 에러: $e');
      return [];
    }
  }

  /// 카테고리 사진 스트림 (차단 필터링 포함)
  Stream<List<Map<String, dynamic>>> getPhotosStream(String categoryId) {
    return _repository.getCategoryPhotosStream(categoryId).asyncMap((
      photos,
    ) async {
      final blockedByMe = await friendService.getBlockedUsers();

      return photos.where((photo) {
        final photoUserId = photo['userId'] as String?;
        return photoUserId == null || !blockedByMe.contains(photoUserId);
      }).toList();
    });
  }

  /// 갤러리에서 선택한 이미지로 표지사진 업데이트
  Future<AuthResult> updateCoverPhotoFromGallery({
    required String categoryId,
    required File imageFile,
  }) async {
    try {
      if (categoryId.isEmpty) {
        return AuthResult.failure('유효하지 않은 카테고리입니다.');
      }

      final photoUrl = await _repository.uploadCoverImage(
        categoryId,
        imageFile,
      );

      await _repository.updateCategoryPhoto(
        categoryId: categoryId,
        photoUrl: photoUrl,
      );

      try {
        await notificationService.updateCategoryThumbnailInNotifications(
          categoryId: categoryId,
          newThumbnailUrl: photoUrl,
        );
      } catch (e) {
        debugPrint('알림 썸네일 업데이트 실패: $e');
      }

      return AuthResult.success(photoUrl);
    } catch (e) {
      return AuthResult.failure('표지사진 업데이트 중 오류가 발생했습니다.');
    }
  }

  /// 카테고리 내 사진으로 표지사진 업데이트
  Future<AuthResult> updateCoverPhotoFromCategory({
    required String categoryId,
    required String photoUrl,
  }) async {
    try {
      if (categoryId.isEmpty || photoUrl.isEmpty) {
        return AuthResult.failure('유효하지 않은 정보입니다.');
      }

      await _repository.updateCategoryPhoto(
        categoryId: categoryId,
        photoUrl: photoUrl,
      );

      try {
        await notificationService.updateCategoryThumbnailInNotifications(
          categoryId: categoryId,
          newThumbnailUrl: photoUrl,
        );
      } catch (e) {
        debugPrint('알림 썸네일 업데이트 실패: $e');
      }

      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure('표지사진 업데이트 중 오류가 발생했습니다.');
    }
  }

  /// 표지사진 삭제
  Future<AuthResult> deleteCoverPhoto(String categoryId) async {
    try {
      if (categoryId.isEmpty) {
        return AuthResult.failure('유효하지 않은 카테고리입니다.');
      }

      await _repository.deleteCategoryPhoto(categoryId);

      try {
        await notificationService.updateCategoryThumbnailInNotifications(
          categoryId: categoryId,
          newThumbnailUrl: '',
        );
      } catch (e) {
        debugPrint('알림 썸네일 업데이트 실패: $e');
      }

      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure('표지사진 삭제 중 오류가 발생했습니다.');
    }
  }

  /// 사진 삭제 후 최신 사진으로 표지사진 자동 업데이트
  Future<void> updateCoverPhotoToLatestAfterDeletion(String categoryId) async {
    try {
      if (categoryId.isEmpty) {
        throw ArgumentError('카테고리 ID가 필요합니다.');
      }

      final photos = await photoService.getPhotosByCategory(categoryId);

      if (photos.isNotEmpty) {
        await _repository.updateCategoryPhoto(
          categoryId: categoryId,
          photoUrl: photos.first.imageUrl,
        );

        try {
          await notificationService.updateCategoryThumbnailInNotifications(
            categoryId: categoryId,
            newThumbnailUrl: photos.first.imageUrl,
          );
        } catch (e) {
          debugPrint('알림 썸네일 업데이트 실패: $e');
        }
      } else {
        await _repository.deleteCategoryPhoto(categoryId);

        try {
          await notificationService.updateCategoryThumbnailInNotifications(
            categoryId: categoryId,
            newThumbnailUrl: '',
          );
        } catch (e) {
          debugPrint('알림 썸네일 업데이트 실패: $e');
        }
      }
    } catch (e) {
      debugPrint('삭제 후 대표사진 자동 업데이트 실패: $e');
    }
  }

  /// 최신 사진 정보 업데이트
  Future<void> updateLastPhotoInfo({
    required String categoryId,
    required String uploadedBy,
  }) async {
    try {
      final now = Timestamp.now();

      await _repository.updateCategory(categoryId, {
        'lastPhotoUploadedBy': uploadedBy,
        'lastPhotoUploadedAt': now,
      });
    } catch (e) {
      debugPrint('카테고리 최신 사진 정보 업데이트 실패: $e');
    }
  }

  /// 사용자 확인 시간 업데이트
  Future<void> updateUserViewTime({
    required String categoryId,
    required String userId,
  }) async {
    try {
      final now = Timestamp.now();

      await _repository.updateCategory(categoryId, {
        'userLastViewedAt.$userId': now,
      });
    } catch (e) {
      debugPrint('사용자 확인 시간 업데이트 실패: $e');
    }
  }
}
