import 'dart:io';
import 'package:flutter/material.dart';
import '../models/photo_data_model.dart';
import '../repositories/media_repository.dart';
import '../repositories/audio_repository.dart';
import '../repositories/friend_repository.dart';
import '../repositories/user_search_repository.dart';
import 'audio_service.dart';
import 'category_service.dart';
import 'notification_service.dart';
import 'friend_service.dart';

/// Photo Service - 사진 관련 비즈니스 로직을 처리
/// Repository를 사용해서 실제 비즈니스 규칙을 적용
class PhotoService {
  // Singleton pattern
  static final PhotoService _instance = PhotoService._internal();
  factory PhotoService() => _instance;
  PhotoService._internal();

  final MediaRepository _photoRepository = MediaRepository();
  final AudioRepository _audioRepository = AudioRepository();
  final AudioService _audioService = AudioService();

  // Lazy initialization으로 순환 의존성 방지
  CategoryService? _categoryService;
  CategoryService get categoryService {
    _categoryService ??= CategoryService();
    return _categoryService!;
  }

  NotificationService? _notificationService;
  NotificationService get notificationService {
    _notificationService ??= NotificationService();
    return _notificationService!;
  }

  FriendService? _friendService;
  FriendService get friendService {
    _friendService ??= FriendService(
      friendRepository: FriendRepository(),
      userSearchRepository: UserSearchRepository(),
    );
    return _friendService!;
  }

  // ==================== 사진 업로드 비즈니스 로직 ====================

  /// 사진 업로드 (이미지 + 오디오)
  Future<PhotoUploadResult> uploadPhoto({
    required File imageFile,
    File? audioFile,
    required String categoryId,
    required String userId,
    required List<String> userIds,
    String? caption,
  }) async {
    try {
      // 입력 검증
      final validationResult = _validatePhotoUpload(
        imageFile: imageFile,
        categoryId: categoryId,
        userId: userId,
        userIds: userIds,
      );

      if (!validationResult.isValid) {
        return PhotoUploadResult.failure(validationResult.error!);
      }

      // 1. 이미지 파일 업로드
      final imageUrl = await _photoRepository.uploadImageToStorage(
        imageFile: imageFile,
        categoryId: categoryId,
        userId: userId,
      );

      if (imageUrl == null) {
        return PhotoUploadResult.failure('이미지 업로드에 실패했습니다.');
      }

      // 2. 오디오 파일 업로드 (있는 경우)
      String? audioUrl;
      if (audioFile != null) {
        audioUrl = await _audioRepository.uploadAudioToSupabaseStorage(
          audioFile: audioFile,
          categoryId: categoryId,
          userId: userId,
        );

        if (audioUrl == null) {
          return PhotoUploadResult.failure('오디오 업로드에 실패했습니다.');
        }
      }

      // 3. 사진 데이터 모델 생성
      final photoData = MediaDataModel(
        id: '', // Firestore에서 자동 생성
        imageUrl: imageUrl,
        audioUrl: audioUrl ?? '',
        userID: userId,
        userIds: userIds,
        categoryId: categoryId,
        createdAt: DateTime.now(),
        unactive: false, // 사진 생성 시 기본값으로 false 설정
        caption: caption, // 게시글 추가
      );

      // 4. Firestore에 메타데이터 저장
      final photoId = await _photoRepository.savePhotoToFirestore(
        photo: photoData,
        categoryId: categoryId,
      );

      if (photoId == null) {
        return PhotoUploadResult.failure('사진 정보 저장에 실패했습니다.');
      }

      // 5. 카테고리의 최신 사진 정보 업데이트
      await categoryService.updateLastPhotoInfo(
        categoryId: categoryId,
        uploadedBy: userId,
      );

      // 6. 카테고리 대표 사진 자동 업데이트 로직
      // 직접 설정하지 않은 경우에는 항상 최신 사진이 대표사진이 되도록 함
      final categories = await categoryService.getUserCategories(userId);
      final category = categories.firstWhere(
        (cat) => cat.id == categoryId,
        orElse: () => throw Exception('카테고리를 찾을 수 없습니다: $categoryId'),
      );

      bool shouldUpdateCoverPhoto = false;

      // 대표사진이 없는 경우 (첫 번째 사진)
      if (category.categoryPhotoUrl?.isEmpty ?? true) {
        shouldUpdateCoverPhoto = true;
      } else {
        // 이미 대표사진이 있는 경우, 직접 설정한 것인지 확인
        // 직접 설정하지 않은 경우에는 항상 최신 사진으로 업데이트
        shouldUpdateCoverPhoto = await _isAutomaticallySetCoverPhoto(
          categoryId,
          category.categoryPhotoUrl!,
        );
      }

      if (shouldUpdateCoverPhoto) {
        await categoryService.updateCoverPhotoFromCategory(
          categoryId: categoryId,
          photoUrl: imageUrl,
        );

        // 7. 카테고리 대표사진이 업데이트된 경우 관련 알림들의 썸네일 업데이트
        try {
          await notificationService.updateCategoryThumbnailInNotifications(
            categoryId: categoryId,
            newThumbnailUrl: imageUrl,
          );
        } catch (e) {
          debugPrint('⚠️ 알림 썸네일 업데이트 실패: $e');
        }
      }

      // 8. 사진 추가 알림 생성
      try {
        // Firestore 저장 완료를 위한 짧은 지연
        await Future.delayed(Duration(milliseconds: 100));

        await notificationService.createPhotoAddedNotification(
          categoryId: categoryId,
          photoId: photoId,
          actorUserId: userId,
          photoUrl: imageUrl, // 이미지 URL 직접 전달
        );
      } catch (e) {
        // 알림 생성 실패는 전체 업로드를 실패시키지 않음
        debugPrint('⚠️ 알림 생성 실패 (업로드는 성공): $e');
      }

      return PhotoUploadResult.success(
        photoId: photoId,
        imageUrl: imageUrl,
        audioUrl: audioUrl,
      );
    } catch (e) {
      debugPrint('사진 업로드 서비스 오류: $e');
      return PhotoUploadResult.failure('사진 업로드 중 오류가 발생했습니다.');
    }
  }

  /// 비디오 업로드 (비디오 + 썸네일)
  Future<PhotoUploadResult> uploadVideo({
    required File videoFile,
    File? thumbnailFile,
    required String categoryId,
    required String userId,
    required List<String> userIds,
    Duration? duration,
    String? caption,
    bool isFromCamera = false, // 카메라 촬영 여부 (기본값: 갤러리)
  }) async {
    try {
      final validationResult = _validateVideoUpload(
        videoFile: videoFile,
        categoryId: categoryId,
        userId: userId,
        userIds: userIds,
      );

      if (!validationResult.isValid) {
        return PhotoUploadResult.failure(validationResult.error!);
      }

      final videoUrl = await _photoRepository.uploadVideoToStorage(
        videoFile: videoFile,
        categoryId: categoryId,
        userId: userId,
      );

      if (videoUrl == null) {
        return PhotoUploadResult.failure('비디오 업로드에 실패했습니다.');
      }

      String? thumbnailUrl;
      if (thumbnailFile != null) {
        thumbnailUrl = await _photoRepository.uploadImageToStorage(
          imageFile: thumbnailFile,
          categoryId: categoryId,
          userId: userId,
        );
      }

      // 썸네일이 없으면 비디오 URL을 대신 사용 (UI에서 처리)
      final fallbackThumbnailUrl = thumbnailUrl ?? videoUrl;

      final videoData = MediaDataModel(
        id: '',
        imageUrl: fallbackThumbnailUrl, // 카테고리 표지에 사용될 URL
        audioUrl: '',
        userID: userId,
        userIds: userIds,
        categoryId: categoryId,
        createdAt: DateTime.now(),
        duration: duration ?? Duration.zero,
        caption: caption,
        isVideo: true,
        videoUrl: videoUrl,
        thumbnailUrl: fallbackThumbnailUrl, // 썸네일 URL (없으면 비디오 URL)
        isFromCamera: isFromCamera, // 카메라 촬영 여부
      );

      final videoId = await _photoRepository.saveVideoToFirestore(
        video: videoData,
        categoryId: categoryId,
      );

      if (videoId == null) {
        return PhotoUploadResult.failure('비디오 정보 저장에 실패했습니다.');
      }

      await categoryService.updateLastPhotoInfo(
        categoryId: categoryId,
        uploadedBy: userId,
      );

      final categories = await categoryService.getUserCategories(userId);
      final category = categories.firstWhere(
        (cat) => cat.id == categoryId,
        orElse: () => throw Exception('카테고리를 찾을 수 없습니다: $categoryId'),
      );

      bool shouldUpdateCoverPhoto = false;
      if (category.categoryPhotoUrl?.isEmpty ?? true) {
        shouldUpdateCoverPhoto = true;
      } else {
        shouldUpdateCoverPhoto = await _isAutomaticallySetCoverPhoto(
          categoryId,
          category.categoryPhotoUrl!,
        );
      }

      if (shouldUpdateCoverPhoto) {
        await categoryService.updateCoverPhotoFromCategory(
          categoryId: categoryId,
          photoUrl: fallbackThumbnailUrl,
        );

        try {
          await notificationService.updateCategoryThumbnailInNotifications(
            categoryId: categoryId,
            newThumbnailUrl: fallbackThumbnailUrl,
          );
        } catch (e) {
          debugPrint('비디오 썸네일 알림 업데이트 실패: $e');
        }
      }

      try {
        await Future.delayed(const Duration(milliseconds: 100));
        await notificationService.createPhotoAddedNotification(
          categoryId: categoryId,
          photoId: videoId,
          actorUserId: userId,
          photoUrl: fallbackThumbnailUrl,
        );
      } catch (e) {
        debugPrint('비디오 업로드 알림 생성 실패: $e');
      }

      return PhotoUploadResult.success(
        photoId: videoId,
        imageUrl: fallbackThumbnailUrl,
      );
    } catch (e) {
      debugPrint('비디오 업로드 서비스 오류: $e');
      return PhotoUploadResult.failure('비디오 업로드 중 오류가 발생했습니다.');
    }
  }

  /// 사진과 오디오를 파형 데이터와 함께 저장
  Future<String> savePhotoWithAudio({
    required String imageFilePath,
    required String audioFilePath,
    required String userID,
    required List<String> userIds,
    required String categoryId,
    List<double>? waveformData,
    Duration? duration,
    String? caption,
  }) async {
    try {
      // 1. 이미지 업로드
      final imageFile = File(imageFilePath);
      final imageUrl = await _photoRepository.uploadImageToStorage(
        imageFile: imageFile,
        categoryId: categoryId,
        userId: userID,
      );

      if (imageUrl == null) {
        throw Exception('이미지 업로드에 실패했습니다.');
      }

      // 2. 오디오 업로드
      final audioFile = File(audioFilePath);
      final audioUrl = await _audioRepository.uploadAudioToSupabaseStorage(
        audioFile: audioFile,
        categoryId: categoryId,
        userId: userID,
      );

      if (audioUrl == null) {
        throw Exception('오디오 업로드에 실패했습니다.');
      }

      // 3. 파형 데이터 처리 (제공된 데이터 우선 사용)
      List<double> finalWaveformData;

      if (waveformData != null && waveformData.isNotEmpty) {
        finalWaveformData = waveformData;
      } else {
        finalWaveformData = await _audioService.extractWaveformData(
          audioFilePath,
        );
      }

      final photoId = await _photoRepository.savePhotoWithWaveform(
        imageUrl: imageUrl,
        audioUrl: audioUrl,
        userID: userID,
        userIds: userIds,
        categoryId: categoryId,
        waveformData: finalWaveformData, // 파형 데이터 전달
        duration: duration, // 음성 길이 전달
        caption: caption, // 게시글 전달
      );

      // 카테고리의 최신 사진 정보 업데이트
      await categoryService.updateLastPhotoInfo(
        categoryId: categoryId,
        uploadedBy: userID,
      );

      // 카테고리 대표 사진 자동 업데이트 로직
      // 직접 설정하지 않은 경우에는 항상 최신 사진이 대표사진이 되도록 함
      final categories = await categoryService.getUserCategories(userID);
      final category = categories.firstWhere(
        (cat) => cat.id == categoryId,
        orElse: () => throw Exception('카테고리를 찾을 수 없습니다: $categoryId'),
      );

      bool shouldUpdateCoverPhoto = false;

      // 대표사진이 없는 경우 (첫 번째 사진)
      if (category.categoryPhotoUrl?.isEmpty ?? true) {
        shouldUpdateCoverPhoto = true;
      } else {
        // 이미 대표사진이 있는 경우, 직접 설정한 것인지 확인
        // 직접 설정하지 않은 경우에는 항상 최신 사진으로 업데이트
        shouldUpdateCoverPhoto = await _isAutomaticallySetCoverPhoto(
          categoryId,
          category.categoryPhotoUrl!,
        );
      }

      if (shouldUpdateCoverPhoto) {
        await categoryService.updateCoverPhotoFromCategory(
          categoryId: categoryId,
          photoUrl: imageUrl,
        );

        // 카테고리 대표사진이 업데이트된 경우 관련 알림들의 썸네일 업데이트
        try {
          await notificationService.updateCategoryThumbnailInNotifications(
            categoryId: categoryId,
            newThumbnailUrl: imageUrl,
          );
        } catch (e) {
          debugPrint('⚠️ 알림 썸네일 업데이트 실패: $e');
        }
      }

      // 사진 추가 알림 생성
      try {
        // Firestore 저장 완료를 위한 짧은 지연
        await Future.delayed(Duration(milliseconds: 100));

        await notificationService.createPhotoAddedNotification(
          categoryId: categoryId,
          photoId: photoId,
          actorUserId: userID,
          photoUrl: imageUrl, // 이미지 URL 직접 전달
        );
      } catch (e) {
        // 알림 생성 실패는 전체 업로드를 실패시키지 않음
        debugPrint('⚠️ 알림 생성 실패 (업로드는 성공): $e');
      }

      return photoId;
    } catch (e) {
      debugPrint('사진 저장 실패: $e');
      rethrow;
    }
  }

  // ==================== 사진 조회 비즈니스 로직 ====================

  /// 모든 카테고리에서 사진을 페이지네이션으로 조회 (무한 스크롤용)
  Future<({List<MediaDataModel> photos, String? lastPhotoId, bool hasMore})>
  getPhotosFromAllCategoriesPaginated({
    required List<String> categoryIds,
    int limit = 20,
    String? startAfterPhotoId,
  }) async {
    try {
      // 입력 검증
      if (categoryIds.isEmpty) {
        throw ArgumentError('카테고리 ID 목록이 필요합니다.');
      }

      if (limit <= 0 || limit > 100) {
        throw ArgumentError('제한값은 1과 100 사이여야 합니다.');
      }

      final result = await _photoRepository.getPhotosFromAllCategoriesPaginated(
        categoryIds: categoryIds,
        limit: limit,
        startAfterPhotoId: startAfterPhotoId,
      );

      // 차단된 사용자 필터링
      final blockedFilteredPhotos = await _filterPhotosWithBlockedUsers(
        result.photos,
      );

      // 비즈니스 로직: 사진 필터링 및 검증
      final filteredPhotos = _applyPhotoBusinessRules(blockedFilteredPhotos);

      return (
        photos: filteredPhotos,
        lastPhotoId: result.lastPhotoId,
        hasMore: result.hasMore,
      );
    } catch (e) {
      return (photos: <MediaDataModel>[], lastPhotoId: null, hasMore: false);
    }
  }

  /// 카테고리별 사진 목록 조회 (차단된 사용자 필터링 포함)
  Future<List<MediaDataModel>> getPhotosByCategory(String categoryId) async {
    try {
      if (categoryId.isEmpty) {
        throw ArgumentError('카테고리 ID가 필요합니다.');
      }

      final photos = await _photoRepository.getPhotosByCategory(categoryId);

      // 차단된 사용자 필터링
      final filteredPhotos = await _filterPhotosWithBlockedUsers(photos);

      // 비즈니스 로직: 최신순 정렬 및 필터링
      return _applyPhotoBusinessRules(filteredPhotos);
    } catch (e) {
      return [];
    }
  }

  /// 카테고리별 사진 스트림 (차단된 사용자 필터링 포함)
  Stream<List<MediaDataModel>> getPhotosByCategoryStream(String categoryId) {
    if (categoryId.isEmpty) {
      return Stream.value([]);
    }

    return _photoRepository.getPhotosByCategoryStream(categoryId).asyncMap((
      photos,
    ) async {
      // 차단된 사용자 필터링
      final filteredPhotos = await _filterPhotosWithBlockedUsers(photos);
      return _applyPhotoBusinessRules(filteredPhotos);
    });
  }

  /// 특정 사진을 ID로 조회
  Future<MediaDataModel?> getPhotoById({
    required String categoryId,
    required String photoId,
  }) async {
    try {
      if (categoryId.isEmpty || photoId.isEmpty) {
        throw ArgumentError('카테고리 ID와 사진 ID가 필요합니다.');
      }

      return await _photoRepository.getPhotoById(
        categoryId: categoryId,
        photoId: photoId,
      );
    } catch (e) {
      debugPrint('PhotoService: getPhotoById 오류 - $e');
      return null;
    }
  }

  /// 사용자별 사진 목록 조회 (차단된 사용자 필터링 포함)
  Future<List<MediaDataModel>> getPhotosByUser(String userId) async {
    try {
      if (userId.isEmpty) {
        throw ArgumentError('사용자 ID가 필요합니다.');
      }

      final photos = await _photoRepository.getPhotosByUser(userId);

      // 차단된 사용자 필터링
      final filteredPhotos = await _filterPhotosWithBlockedUsers(photos);

      return _applyPhotoBusinessRules(filteredPhotos);
    } catch (e) {
      return [];
    }
  }

  /// 특정 사진 상세 조회
  Future<MediaDataModel?> getPhotoDetails({
    required String categoryId,
    required String photoId,
    String? viewerUserId,
  }) async {
    try {
      if (categoryId.isEmpty || photoId.isEmpty) {
        throw ArgumentError('카테고리 ID와 사진 ID가 필요합니다.');
      }

      final photo = await _photoRepository.getPhotoById(
        categoryId: categoryId,
        photoId: photoId,
      );

      return photo;
    } catch (e) {
      return null;
    }
  }

  // ==================== 사진 업데이트 비즈니스 로직 ====================

  /// 사진 정보 업데이트
  Future<bool> updatePhoto({
    required String categoryId,
    required String photoId,
    required String userId,
  }) async {
    try {
      // 권한 검증
      final photo = await _photoRepository.getPhotoById(
        categoryId: categoryId,
        photoId: photoId,
      );

      if (photo == null) {
        throw Exception('사진을 찾을 수 없습니다.');
      }

      if (photo.userID != userId) {
        throw Exception('사진을 수정할 권한이 없습니다.');
      }

      // PhotoDataModel의 기본 속성들은 대부분 수정 불가능한 속성들이므로
      // 현재는 간단한 검증만 수행하고 성공으로 반환
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== 사진 삭제 비즈니스 로직 ====================

  /// 사진 삭제
  Future<bool> deletePhoto({
    required String categoryId,
    required String photoId,
    required String userId,
    bool permanentDelete = false,
  }) async {
    try {
      // 권한 검증
      final photo = await _photoRepository.getPhotoById(
        categoryId: categoryId,
        photoId: photoId,
      );

      if (photo == null) {
        throw Exception('사진을 찾을 수 없습니다.');
      }

      if (photo.userID != userId) {
        throw Exception('사진을 삭제할 권한이 없습니다.');
      }

      // 삭제하기 전에 현재 카테고리 정보 확인
      final categories = await categoryService.getUserCategories(userId);
      final category = categories.firstWhere(
        (cat) => cat.id == categoryId,
        orElse: () => throw Exception('카테고리를 찾을 수 없습니다: $categoryId'),
      );

      // 삭제될 사진이 현재 대표사진인지 확인
      final isCurrentCoverPhoto = category.categoryPhotoUrl == photo.imageUrl;

      bool deleteResult;
      if (permanentDelete) {
        // 완전 삭제
        deleteResult = await _photoRepository.permanentDeletePhoto(
          categoryId: categoryId,
          photoId: photoId,
          imageUrl: photo.imageUrl,
          audioUrl: photo.audioUrl.isNotEmpty ? photo.audioUrl : null,
        );
      } else {
        // 소프트 삭제
        deleteResult = await _photoRepository.deletePhoto(
          categoryId: categoryId,
          photoId: photoId,
        );
      }

      // 삭제 성공하고, 삭제된 사진이 대표사진이었다면 새로운 대표사진으로 업데이트
      if (deleteResult && isCurrentCoverPhoto) {
        try {
          await categoryService.updateCoverPhotoToLatestAfterDeletion(
            categoryId,
          );
        } catch (e) {
          debugPrint('⚠️ 삭제 후 대표사진 업데이트 실패: $e');
          // 사진 삭제는 성공했으므로 계속 진행
        }
      }

      return deleteResult;
    } catch (e) {
      return false;
    }
  }

  // ==================== 통계 및 유틸리티 ====================

  /// 사진 통계 조회
  Future<Map<String, int>> getPhotoStats(String categoryId) async {
    return await _photoRepository.getPhotoStats(categoryId);
  }

  // ==================== 비즈니스 규칙 검증 ====================

  /// 사진 업로드 검증
  PhotoValidationResult _validatePhotoUpload({
    required File imageFile,
    required String categoryId,
    required String userId,
    required List<String> userIds,
  }) {
    // 필수 필드 검증
    if (categoryId.isEmpty) {
      return PhotoValidationResult.invalid('카테고리 ID가 필요합니다.');
    }

    if (userId.isEmpty) {
      return PhotoValidationResult.invalid('사용자 ID가 필요합니다.');
    }

    if (userIds.isEmpty || !userIds.contains(userId)) {
      return PhotoValidationResult.invalid('올바른 사용자 목록이 필요합니다.');
    }

    // 파일 크기 검증 (10MB 제한)
    if (imageFile.lengthSync() > 10 * 1024 * 1024) {
      return PhotoValidationResult.invalid('이미지 파일 크기는 10MB를 초과할 수 없습니다.');
    }

    return PhotoValidationResult.valid();
  }

  PhotoValidationResult _validateVideoUpload({
    required File videoFile,
    required String categoryId,
    required String userId,
    required List<String> userIds,
  }) {
    if (categoryId.isEmpty) {
      return PhotoValidationResult.invalid('카테고리 ID가 필요합니다.');
    }

    if (userId.isEmpty) {
      return PhotoValidationResult.invalid('사용자 ID가 필요합니다.');
    }

    if (userIds.isEmpty || !userIds.contains(userId)) {
      return PhotoValidationResult.invalid('올바른 사용자 목록이 필요합니다.');
    }

    if (!videoFile.existsSync()) {
      return PhotoValidationResult.invalid('비디오 파일이 존재하지 않습니다.');
    }

    final supportedExtensions = ['.mp4', '.mov', '.m4v', '.avi', '.mkv'];
    final lowerPath = videoFile.path.toLowerCase();
    final hasSupportedExtension = supportedExtensions.any(
      (ext) => lowerPath.endsWith(ext),
    );

    if (!hasSupportedExtension) {
      return PhotoValidationResult.invalid('지원하지 않는 비디오 형식입니다.');
    }

    const maxVideoSizeInBytes = 200 * 1024 * 1024; // 200MB
    if (videoFile.lengthSync() > maxVideoSizeInBytes) {
      return PhotoValidationResult.invalid('비디오 파일 크기는 200MB를 초과할 수 없습니다.');
    }

    return PhotoValidationResult.valid();
  }

  /// 사진 비즈니스 규칙 적용
  List<MediaDataModel> _applyPhotoBusinessRules(List<MediaDataModel> photos) {
    // 활성 상태만 필터링
    final activePhotos = photos
        .where((photo) => photo.status == PhotoStatus.active)
        .toList();

    // 최신순 정렬
    activePhotos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return activePhotos;
  }

  // ==================== 파형 데이터 유틸리티 ====================

  /// 특정 사진에 파형 데이터 추가
  Future<bool> addWaveformDataToPhoto({
    required String categoryId,
    required String photoId,
    required String audioFilePath,
  }) async {
    try {
      // 오디오 파일에서 파형 데이터 추출
      final waveformData = await _audioService.extractWaveformData(
        audioFilePath,
      );
      final audioDuration = await _audioService.getAudioDuration(audioFilePath);

      return await _photoRepository.addWaveformDataToPhoto(
        categoryId: categoryId,
        photoId: photoId,
        waveformData: waveformData,
        audioDuration: audioDuration,
      );
    } catch (e) {
      return false;
    }
  }

  /// 현재 카테고리 대표사진이 자동으로 설정된 것인지 확인
  /// (카테고리의 기존 사진 중 하나라면 자동 설정된 것으로 간주)
  Future<bool> _isAutomaticallySetCoverPhoto(
    String categoryId,
    String currentCoverPhotoUrl,
  ) async {
    try {
      // 카테고리의 모든 사진을 조회
      final photos = await _photoRepository.getPhotosByCategory(categoryId);

      // 현재 대표사진이 카테고리의 사진 중 하나인지 확인
      final isFromCategoryPhoto = photos.any(
        (photo) => photo.imageUrl == currentCoverPhotoUrl,
      );

      // 카테고리의 사진 중 하나라면 자동 설정된 것으로 간주
      return isFromCategoryPhoto;
    } catch (e) {
      debugPrint('❌ 대표사진 자동 설정 여부 확인 실패: $e');
      // 오류 발생 시 안전하게 false 반환 (업데이트하지 않음)
      return false;
    }
  }

  /// 차단된 사용자의 사진을 필터링하는 메서드
  Future<List<MediaDataModel>> _filterPhotosWithBlockedUsers(
    List<MediaDataModel> photos,
  ) async {
    try {
      // 내가 차단한 사용자 목록만 조회 (단방향 필터링)
      final blockedByMe = await friendService.getBlockedUsers();

      if (blockedByMe.isEmpty) {
        return photos; // 차단한 사용자가 없으면 필터링 불필요
      }

      // 내가 차단한 사용자들의 사진만 필터링
      return photos.where((photo) {
        return !blockedByMe.contains(photo.userID);
      }).toList();
    } catch (e) {
      debugPrint('사진 차단 필터링 중 오류 발생: $e');
      return photos; // 오류 발생 시 원본 반환
    }
  }

  // ==================== 삭제된 사진 관리 ====================

  /// 사용자의 삭제된 사진 목록 조회
  Future<List<MediaDataModel>> getDeletedPhotosByUser(String userId) async {
    try {
      // 입력 검증
      if (userId.isEmpty) {
        throw Exception('사용자 ID가 필요합니다.');
      }

      // Repository에서 삭제된 사진 목록 조회
      final deletedPhotos = await _photoRepository.getDeletedPhotosByUser(
        userId,
      );

      return deletedPhotos;
    } catch (e) {
      debugPrint('PhotoService: 삭제된 사진 조회 실패 - $e');
      throw Exception('삭제된 사진을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  /// 사진 복원
  Future<bool> restorePhoto({
    required String categoryId,
    required String photoId,
    required String userId,
  }) async {
    try {
      // 입력 검증
      if (categoryId.isEmpty || photoId.isEmpty || userId.isEmpty) {
        throw Exception('필수 매개변수가 누락되었습니다.');
      }

      // 1. 사진이 존재하고 삭제된 상태인지 확인
      final photo = await _photoRepository.getPhotoById(
        categoryId: categoryId,
        photoId: photoId,
      );

      if (photo == null) {
        throw Exception('사진을 찾을 수 없습니다.');
      }

      if (photo.status != PhotoStatus.deleted) {
        throw Exception('삭제된 사진만 복원할 수 있습니다.');
      }

      // 2. 사용자 권한 확인 (사진 소유자 또는 카테고리 멤버인지)
      final hasPermission = await _checkUserPermissionForPhoto(
        categoryId: categoryId,
        photoUserId: photo.userID,
        requestUserId: userId,
      );

      if (!hasPermission) {
        throw Exception('사진을 복원할 권한이 없습니다.');
      }

      // 3. 사진 복원 실행
      final success = await _photoRepository.restorePhoto(
        categoryId: categoryId,
        photoId: photoId,
      );

      if (success) {
        return true;
      } else {
        throw Exception('사진 복원에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('PhotoService: 사진 복원 실패 - $e');
      return false;
    }
  }

  /// 사진에 대한 사용자 권한 확인
  Future<bool> _checkUserPermissionForPhoto({
    required String categoryId,
    required String photoUserId,
    required String requestUserId,
  }) async {
    try {
      // 1. 사진 소유자인 경우 권한 있음
      if (photoUserId == requestUserId) {
        return true;
      }

      // 2. 카테고리 멤버인지 확인
      final category = await categoryService.getCategory(categoryId);
      if (category != null && category.mates.contains(requestUserId)) {
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('사용자 권한 확인 실패: $e');
      return false;
    }
  }
}

/// 사진 검증 결과
class PhotoValidationResult {
  final bool isValid;
  final String? error;

  PhotoValidationResult._({required this.isValid, this.error});

  factory PhotoValidationResult.valid() {
    return PhotoValidationResult._(isValid: true);
  }

  factory PhotoValidationResult.invalid(String error) {
    return PhotoValidationResult._(isValid: false, error: error);
  }
}
