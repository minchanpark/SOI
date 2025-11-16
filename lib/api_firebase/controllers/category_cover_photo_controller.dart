import 'dart:io';
import 'package:flutter/material.dart';
import '../services/category_service.dart';

/// 카테고리 표지사진 관리를 담당하는 컨트롤러
class CategoryCoverPhotoController extends ChangeNotifier {
  final CategoryService _categoryService = CategoryService();
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 갤러리에서 선택한 이미지로 표지사진 업데이트
  Future<bool> updateCoverPhotoFromGallery({
    required String categoryId,
    required File imageFile,
  }) async {
    return await _executeWithLoading(() async {
      final result = await _categoryService.updateCoverPhotoFromGallery(
        categoryId: categoryId,
        imageFile: imageFile,
      );
      if (!result.isSuccess) {
        _error = result.error;
        return false;
      }
      return true;
    });
  }

  /// 카테고리 내 사진으로 표지사진 업데이트
  Future<bool> updateCoverPhotoFromCategory({
    required String categoryId,
    required String photoUrl,
  }) async {
    return await _executeWithLoading(() async {
      final result = await _categoryService.updateCoverPhotoFromCategory(
        categoryId: categoryId,
        photoUrl: photoUrl,
      );
      if (!result.isSuccess) {
        _error = result.error;
        return false;
      }
      return true;
    });
  }

  /// 표지사진 삭제
  Future<bool> deleteCoverPhoto(String categoryId) async {
    return await _executeWithLoading(() async {
      final result = await _categoryService.deleteCoverPhoto(categoryId);
      if (!result.isSuccess) {
        _error = result.error;
        return false;
      }
      return true;
    });
  }

  /// 에러 상태 초기화
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// 로딩 상태와 함께 작업 실행
  Future<T> _executeWithLoading<T>(Future<T> Function() action) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      return await action();
    } catch (e) {
      _error = '작업 중 오류가 발생했습니다.';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
