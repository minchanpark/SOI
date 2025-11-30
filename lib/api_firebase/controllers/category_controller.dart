import 'dart:async';

import 'package:flutter/material.dart';
import '../services/category_service.dart';
import '../models/category_data_model.dart';

/// 카테고리 핵심 CRUD 및 상태 관리를 담당하는 컨트롤러
class CategoryController extends ChangeNotifier {
  // 상태 변수들
  final List<String> _selectedNames = [];
  List<CategoryDataModel> _userCategories = [];
  bool _isLoading = false;
  String? _error;
  String? _lastLoadedUserId;
  DateTime? _lastLoadTime;
  static const Duration _cacheTimeout = Duration(seconds: 30);

  final CategoryService _categoryService = CategoryService();

  // Getters
  List<String> get selectedNames => _selectedNames;
  List<CategoryDataModel> get userCategories => _userCategories;

  // 레거시 호환
  List<CategoryDataModel> get userCategoryList => _userCategories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ==================== 카테고리 로드 및 스트림 ====================

  /// 사용자의 카테고리 목록 로드
  Future<void> loadUserCategories(
    String userId, {
    bool forceReload = false,
  }) async {
    if (userId.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final isCacheValid =
        _lastLoadTime != null && now.difference(_lastLoadTime!) < _cacheTimeout;

    if (!forceReload && _lastLoadedUserId == userId && isCacheValid) {
      return;
    }

    await _executeWithLoading(() async {
      final categories = await _categoryService.getUserCategories(userId);
      _userCategories = categories;
      _sortCategoriesForUser(userId);
      _lastLoadedUserId = userId;
      _lastLoadTime = DateTime.now();
    });
  }

  /// 카테고리 스트림
  Stream<List<CategoryDataModel>> streamUserCategories(String userId) {
    return _categoryService.getUserCategoriesStream(userId).map((categories) {
      _sortCategoriesOptimized(categories, userId);
      return categories;
    });
  }

  /// 단일 카테고리 스트림
  Stream<CategoryDataModel?> streamSingleCategory(String categoryId) {
    return _categoryService.getCategoryStream(categoryId);
  }

  // ==================== 카테고리 CRUD ====================

  /// 카테고리 생성
  Future<void> createCategory({
    required String name,
    required List<String> mates,
    Map<String, String>? mateProfileImages,
  }) async {
    await _executeWithLoading(() async {
      final result = await _categoryService.createCategory(
        name: name,
        mates: mates,
        mateProfileImages: mateProfileImages,
      );
      if (result.isSuccess) {
        invalidateCache();
        // 백그라운드에서 캐시 갱신 (UI 차단 없음, 스트림이 자동 업데이트)
        if (mates.isNotEmpty) {
          unawaited(loadUserCategories(mates.first, forceReload: true));
        }
      } else {
        _error = result.error;
      }
    });
  }

  /// 카테고리 수정
  Future<void> updateCategory({
    required String categoryId,
    String? name,
    List<String>? mates,
    bool? isPinned,
  }) async {
    await _executeWithLoading(() async {
      final result = await _categoryService.updateCategory(
        categoryId: categoryId,
        name: name,
        mates: mates,
        isPinned: isPinned,
      );
      if (result.isSuccess) {
        if (_userCategories.isNotEmpty) {
          await loadUserCategories(_userCategories.first.mates.first);
        }
      } else {
        _error = result.error;
      }
    });
  }

  /// 카테고리 이름 업데이트
  Future<void> updateCategoryName(String categoryId, String newName) async {
    await updateCategory(categoryId: categoryId, name: newName);
  }

  /// 사용자별 커스텀 이름 업데이트
  Future<void> updateCustomCategoryName({
    required String categoryId,
    required String userId,
    required String customName,
  }) async {
    await _executeWithLoading(() async {
      final result = await _categoryService.updateCustomCategoryName(
        categoryId: categoryId,
        userId: userId,
        customName: customName,
      );
      if (result.isSuccess) {
        await loadUserCategories(userId, forceReload: true);
      } else {
        _error = result.error;
      }
    });
  }

  /// 카테고리 삭제
  Future<void> deleteCategory(String categoryId, String userId) async {
    await _executeWithLoading(() async {
      final result = await _categoryService.deleteCategory(categoryId);
      if (result.isSuccess) {
        await loadUserCategories(userId);
      } else {
        _error = result.error;
      }
    });
  }

  /// 특정 카테고리 조회
  Future<CategoryDataModel?> getCategory(String categoryId) async {
    return await _categoryService.getCategory(categoryId);
  }

  // ==================== 카테고리 고정 ====================

  /// 카테고리 고정/해제 토글
  Future<void> togglePinCategory(
    String categoryId,
    String userId,
    bool currentPinStatus,
  ) async {
    final newPinStatus = !currentPinStatus;
    final categoryIndex = _userCategories.indexWhere(
      (cat) => cat.id == categoryId,
    );

    if (categoryIndex != -1) {
      _updateLocalPinStatus(categoryIndex, userId, newPinStatus);
      notifyListeners();
    }

    _isLoading = true;
    final result = await _categoryService.updateUserPinStatus(
      categoryId: categoryId,
      userId: userId,
      isPinned: newPinStatus,
    );
    _isLoading = false;

    if (!result.isSuccess && categoryIndex != -1) {
      _updateLocalPinStatus(categoryIndex, userId, currentPinStatus);
      notifyListeners();
    }
  }

  // 로컬 상태에서 카테고리 고정 상태 업데이트
  void _updateLocalPinStatus(int index, String userId, bool isPinned) {
    final currentStatus = Map<String, bool>.from(
      _userCategories[index].userPinnedStatus ?? {},
    );
    currentStatus[userId] = isPinned;
    _userCategories[index] = _userCategories[index].copyWith(
      userPinnedStatus: currentStatus,
    );
    // 최적화된 정렬 메소드 사용
    _sortCategoriesOptimized(_userCategories, userId);
  }

  // ==================== UI 상태 관리 ====================

  void addSelectedName(String name) {
    if (!_selectedNames.contains(name)) {
      _selectedNames.add(name);
      notifyListeners();
    }
  }

  void removeSelectedName(String name) {
    _selectedNames.remove(name);
    notifyListeners();
  }

  void toggleSelectedName(String name) {
    if (_selectedNames.contains(name)) {
      _selectedNames.remove(name);
    } else {
      _selectedNames.add(name);
    }
    notifyListeners();
  }

  void clearSelectedNames() {
    _selectedNames.clear();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void invalidateCache() {
    _lastLoadTime = null;
    _lastLoadedUserId = null;
  }

  // ==================== 유틸리티 ====================

  /// 카테고리 표시 이름
  String getCategoryDisplayName(CategoryDataModel category, String userId) {
    return category.getDisplayName(userId);
  }

  /// 카테고리 이름 조회 (레거시)
  Future<String> getCategoryName(String categoryId) async {
    try {
      final category = await getCategory(categoryId);
      return category?.name ?? '알 수 없는 카테고리';
    } catch (e) {
      return '오류 발생';
    }
  }

  /// 카테고리 프로필 이미지 조회 (병렬 처리 최적화)
  Future<List<String>> getCategoryProfileImages(
    List<String> mates,
    dynamic authController,
  ) async {
    try {
      // 병렬로 모든 프로필 이미지 조회
      final results = await Future.wait(
        mates.map((mateUid) async {
          try {
            return await authController.getUserProfileImageUrlById(mateUid);
          } catch (e) {
            debugPrint('사용자 $mateUid의 프로필 이미지 로딩 실패: $e');
            return null;
          }
        }),
      );

      return results
          .where((url) => url != null && url.isNotEmpty)
          .cast<String>()
          .toList();
    } catch (e) {
      debugPrint('카테고리 프로필 이미지 로딩 전체 실패: $e');
      return [];
    }
  }

  /// 사용자 조회 시간 업데이트
  Future<void> updateUserViewTime({
    required String categoryId,
    required String userId,
  }) async {
    try {
      await _categoryService.updateUserViewTime(
        categoryId: categoryId,
        userId: userId,
      );
    } catch (e) {
      debugPrint('[CategoryController] updateUserViewTime 오류: $e');
    }
  }

  // ==================== Private 메서드 ====================

  /// 로딩 상태와 함께 작업 실행
  Future<void> _executeWithLoading(Future<void> Function() action) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      await action();
    } catch (e) {
      debugPrint('[CategoryController] 오류: $e');
      _error = '작업 중 오류가 발생했습니다.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 사용자별 카테고리 정렬 (레거시 호환)
  void _sortCategoriesForUser(String userId) {
    _sortCategoriesOptimized(_userCategories, userId);
  }

  /// 최적화된 카테고리 정렬 (Schwartzian Transform)
  /// 정렬 키를 사전 계산하여 각 카테고리당 O(1) 비교 보장
  void _sortCategoriesOptimized(
    List<CategoryDataModel> categories,
    String userId,
  ) {
    if (categories.length <= 1) return;

    // 1단계: 정렬 키 사전 계산 - O(n)
    // 각 카테고리당 isPinnedForUser, hasNewPhotoForUser를 정확히 1번만 호출
    final sortKeys =
        <
          String,
          ({bool isPinned, bool hasNew, DateTime? lastUpload, DateTime created})
        >{};
    for (final cat in categories) {
      sortKeys[cat.id] = (
        isPinned: cat.isPinnedForUser(userId),
        hasNew: cat.hasNewPhotoForUser(userId),
        lastUpload: cat.lastPhotoUploadedAt,
        created: cat.createdAt,
      );
    }

    // 2단계: 캐시된 키로 정렬 - O(n log n), 각 비교는 O(1)
    categories.sort((a, b) {
      final keyA = sortKeys[a.id]!;
      final keyB = sortKeys[b.id]!;

      // 1순위: 고정
      if (keyA.isPinned && !keyB.isPinned) return -1;
      if (!keyA.isPinned && keyB.isPinned) return 1;

      // 2순위: 새 사진
      if (keyA.isPinned == keyB.isPinned) {
        if (keyA.hasNew && !keyB.hasNew) return -1;
        if (!keyA.hasNew && keyB.hasNew) return 1;
      }

      // 3순위: 최신 사진 업로드 시간
      if (keyA.isPinned == keyB.isPinned && keyA.hasNew == keyB.hasNew) {
        if (keyA.lastUpload != null && keyB.lastUpload != null) {
          return keyB.lastUpload!.compareTo(keyA.lastUpload!);
        } else if (keyA.lastUpload != null) {
          return -1;
        } else if (keyB.lastUpload != null) {
          return 1;
        } else {
          return keyB.created.compareTo(keyA.created);
        }
      }

      return 0;
    });
  }
}
