import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../api_firebase/controllers/auth_controller.dart';
import '../../../api_firebase/controllers/category_controller.dart';
import '../../../api_firebase/controllers/media_controller.dart';
import '../../../api_firebase/models/photo_data_model.dart';

class FeedDataManager {
  // 데이터 관리
  List<Map<String, dynamic>> _allPhotos = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  // Getters
  List<Map<String, dynamic>> get allPhotos => _allPhotos;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreData => _hasMoreData;

  // 콜백 함수들
  VoidCallback? _onStateChanged;
  Function(List<Map<String, dynamic>>)? _onPhotosLoaded;

  void setOnStateChanged(VoidCallback? callback) {
    _onStateChanged = callback;
  }

  void setOnPhotosLoaded(Function(List<Map<String, dynamic>>)? callback) {
    _onPhotosLoaded = callback;
  }

  void _notifyStateChanged() {
    _onStateChanged?.call();
  }

  /// 사용자가 속한 카테고리들과 해당 사진들을 모두 로드 (초기 로드)
  Future<void> loadUserCategoriesAndPhotos(BuildContext context) async {
    try {
      _isLoading = true;
      _allPhotos.clear();
      _hasMoreData = true;
      _notifyStateChanged();

      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final categoryController = Provider.of<CategoryController>(
        context,
        listen: false,
      );
      final photoController = Provider.of<PhotoController>(
        context,
        listen: false,
      );

      final currentUserId = authController.getUserId;

      if (currentUserId == null || currentUserId.isEmpty) {
        throw Exception('로그인된 사용자를 찾을 수 없습니다.');
      }

      // 사용자가 속한 카테고리들 가져오기
      await categoryController.loadUserCategories(
        currentUserId,
        forceReload: true,
      );

      final userCategories = categoryController.userCategories;

      if (userCategories.isEmpty) {
        _isLoading = false;
        _hasMoreData = false;
        _notifyStateChanged();
        return;
      }

      // PhotoController의 무한 스크롤 초기 로드 사용 (5개)
      final categoryIds = userCategories.map((c) => c.id).toList();

      await photoController.loadPhotosFromAllCategoriesInitial(categoryIds);

      // PhotoController의 데이터를 UI용 형태로 변환
      final List<Map<String, dynamic>> photoDataList = [];
      for (MediaDataModel photo in photoController.photos) {
        final category = userCategories.firstWhere(
          (c) => c.id == photo.categoryId,
          orElse: () => userCategories.first,
        );
        photoDataList.add({
          'photo': photo,
          'categoryName': category.name,
          'categoryId': category.id,
        });
      }

      _allPhotos = photoDataList;
      _hasMoreData = photoController.hasMore;
      _isLoading = false;
      _notifyStateChanged();

      // 새로 로드된 사진들에 대한 콜백 호출
      _onPhotosLoaded?.call(photoDataList);
    } catch (e) {
      _isLoading = false;
      _hasMoreData = false;
      _notifyStateChanged();
    }
  }

  /// 더 많은 사진 로드 (무한 스크롤링)
  Future<void> loadMorePhotos(BuildContext context) async {
    if (_isLoadingMore || !_hasMoreData) return;

    try {
      _isLoadingMore = true;
      _notifyStateChanged();

      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final categoryController = Provider.of<CategoryController>(
        context,
        listen: false,
      );
      final photoController = Provider.of<PhotoController>(
        context,
        listen: false,
      );

      final currentUserId = authController.getUserId;
      if (currentUserId == null || currentUserId.isEmpty) {
        _isLoadingMore = false;
        _notifyStateChanged();
        return;
      }

      // 사용자가 속한 카테고리들 가져오기
      final userCategories = categoryController.userCategories;
      if (userCategories.isEmpty) {
        _isLoadingMore = false;
        _hasMoreData = false;
        _notifyStateChanged();
        return;
      }

      // PhotoController의 무한 스크롤 추가 로드 사용 (10개)
      final categoryIds = userCategories.map((c) => c.id).toList();

      // 로드 전 현재 사진 개수 저장
      final previousPhotoCount = photoController.photos.length;

      await photoController.loadMorePhotos(categoryIds);

      // 로드 후 새로 추가된 사진만 가져오기
      final allPhotos = photoController.photos;
      final newPhotos = allPhotos.sublist(previousPhotoCount);

      // 새로 로드된 사진들을 UI용 형태로 변환
      final List<Map<String, dynamic>> newPhotoDataList = [];
      for (MediaDataModel photo in newPhotos) {
        final category = userCategories.firstWhere(
          (c) => c.id == photo.categoryId,
          orElse: () => userCategories.first,
        );
        newPhotoDataList.add({
          'photo': photo,
          'categoryName': category.name,
          'categoryId': category.id,
        });
      }

      _allPhotos.addAll(newPhotoDataList);
      _hasMoreData = photoController.hasMore;
      _isLoadingMore = false;
      _notifyStateChanged();

      // 새로 로드된 사진들에 대한 콜백 호출
      _onPhotosLoaded?.call(newPhotoDataList);
    } catch (e) {
      debugPrint('❌ 추가 사진 로드 실패: $e');
      _isLoadingMore = false;
      _notifyStateChanged();
    }
  }

  /// 사진 삭제
  void removePhoto(int index) {
    if (index >= 0 && index < _allPhotos.length) {
      _allPhotos.removeAt(index);
      _notifyStateChanged();
    }
  }

  /// 특정 사진 데이터 가져오기
  Map<String, dynamic>? getPhotoData(int index) {
    if (index >= 0 && index < _allPhotos.length) {
      return _allPhotos[index];
    }
    return null;
  }

  /// 리소스 정리
  void dispose() {
    _allPhotos.clear();
  }
}
