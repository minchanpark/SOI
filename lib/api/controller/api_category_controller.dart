import 'package:flutter/foundation.dart';
import 'package:soi/api/controller/category_controller.dart';
import 'package:soi/api/models/category.dart' as model;
import 'package:soi/api/services/category_service.dart';

/// REST API 기반 카테고리 컨트롤러 구현체
class ApiCategoryController extends CategoryController {
  final CategoryService _categoryService;

  // 카테고리 캐시 (filter별로 관리)
  final Map<model.CategoryFilter, List<model.Category>> _categoriesCache = {};
  int? _lastLoadedUserId;
  model.CategoryFilter? _lastLoadedFilter;
  DateTime? _lastLoadTime;
  static const Duration _cacheTimeout = Duration(seconds: 30);

  // 현재 표시 중인 카테고리 (마지막으로 로드한 filter의 데이터)
  List<model.Category> _currentCategories = [];

  // 로딩 상태
  bool _isLoading = false;

  // 에러 메시지
  String? _errorMessage;

  ApiCategoryController({CategoryService? categoryService})
    : _categoryService = categoryService ?? CategoryService();

  @override
  bool get isLoading => _isLoading;

  @override
  String? get errorMessage => _errorMessage;

  /// 캐시된 카테고리 목록 (현재 filter 기준)
  List<model.Category> get categories => List.unmodifiable(_currentCategories);

  /// filter별 캐시된 카테고리 목록 조회
  List<model.Category> getCategoriesByFilter(model.CategoryFilter filter) {
    return List.unmodifiable(_categoriesCache[filter] ?? []);
  }

  /// 전체 카테고리 (ALL filter)
  List<model.Category> get allCategories =>
      getCategoriesByFilter(model.CategoryFilter.all);

  /// 공개 카테고리 (PUBLIC filter)
  List<model.Category> get publicCategories =>
      getCategoriesByFilter(model.CategoryFilter.public_);

  /// 비공개 카테고리 (PRIVATE filter)
  List<model.Category> get privateCategories =>
      getCategoriesByFilter(model.CategoryFilter.private_);

  /// 카테고리 목록 로드 및 캐시
  ///
  /// [forceReload]가 true이면 캐시를 무시하고 새로 로드합니다.
  Future<List<model.Category>> loadCategories(
    int userId, {
    model.CategoryFilter filter = model.CategoryFilter.all,
    bool forceReload = false,
  }) async {
    final now = DateTime.now();
    final isCacheValid =
        _lastLoadTime != null && now.difference(_lastLoadTime!) < _cacheTimeout;

    // 캐시가 유효하고 같은 userId + filter면 캐시된 데이터 반환
    if (!forceReload &&
        _lastLoadedUserId == userId &&
        _lastLoadedFilter == filter &&
        isCacheValid &&
        _categoriesCache.containsKey(filter) &&
        _categoriesCache[filter]!.isNotEmpty) {
      _currentCategories = _categoriesCache[filter]!;
      debugPrint(
        '[ApiCategoryController] 캐시된 카테고리 반환 (filter: ${filter.value}): ${_currentCategories.length}개',
      );
      notifyListeners();
      return _currentCategories;
    }

    _setLoading(true);
    _clearError();

    try {
      final categories = await _categoryService.getCategories(
        userId: userId,
        filter: filter,
      );

      // filter별 캐시 저장
      _categoriesCache[filter] = categories;
      _currentCategories = categories;
      _lastLoadedUserId = userId;
      _lastLoadedFilter = filter;
      _lastLoadTime = DateTime.now();

      debugPrint(
        '[ApiCategoryController] 카테고리 로드 완료 (filter: ${filter.value}): ${categories.length}개',
      );
      _setLoading(false);
      return categories;
    } catch (e) {
      _setError('카테고리 조회 실패: $e');
      debugPrint('[ApiCategoryController] 카테고리 로드 실패: $e');
      _setLoading(false);
      return [];
    }
  }

  /// 캐시 무효화
  void invalidateCache() {
    _categoriesCache.clear();
    _currentCategories = [];
    _lastLoadedUserId = null;
    _lastLoadedFilter = null;
    _lastLoadTime = null;
    debugPrint('🗑️ [ApiCategoryController] 캐시 무효화');
    notifyListeners();
  }

  /// ID로 캐시된 카테고리 조회
  model.Category? getCategoryById(int categoryId) {
    try {
      return _currentCategories.firstWhere((c) => c.id == categoryId);
    } catch (_) {
      return null;
    }
  }

  // 카테고리 생성
  @override
  Future<int?> createCategory({
    required int requesterId,
    required String name,
    List<int> receiverIds = const [],
    bool isPublic = true,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final id = await _categoryService.createCategory(
        requesterId: requesterId,
        name: name,
        receiverIds: receiverIds,
        isPublic: isPublic,
      );
      _setLoading(false);
      return id;
    } catch (e) {
      _setError('카테고리 생성 실패: $e');
      _setLoading(false);
      return null;
    }
  }

  // 카테고리 조회
  @override
  Future<List<model.Category>> getCategories({
    required int userId,
    model.CategoryFilter filter = model.CategoryFilter.all,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final categories = await _categoryService.getCategories(
        userId: userId,
        filter: filter,
      );
      _setLoading(false);
      return categories;
    } catch (e) {
      _setError('카테고리 조회 실패: $e');
      _setLoading(false);
      return [];
    }
  }

  // 모든 카테고리 조회
  @override
  Future<List<model.Category>> getAllCategories(int userId) =>
      getCategories(userId: userId, filter: model.CategoryFilter.all);

  // 공개 카테고리 조회
  @override
  Future<List<model.Category>> getPublicCategories(int userId) =>
      getCategories(userId: userId, filter: model.CategoryFilter.public_);

  // 비공개 카테고리 조회
  @override
  Future<List<model.Category>> getPrivateCategories(int userId) =>
      getCategories(userId: userId, filter: model.CategoryFilter.private_);

  // 카테고리 고정
  @override
  Future<bool> toggleCategoryPin({
    required int categoryId,
    required int userId,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final result = await _categoryService.toggleCategoryPin(
        categoryId: categoryId,
        userId: userId,
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('카테고리 고정 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  // 카테고리 초대
  @override
  Future<bool> inviteUsersToCategory({
    required int categoryId,
    required int requesterId,
    required List<int> receiverIds,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final result = await _categoryService.inviteUsersToCategory(
        categoryId: categoryId,
        requesterId: requesterId,
        receiverIds: receiverIds,
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('사용자 초대 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  // 카테고리 초대 수락
  @override
  Future<bool> acceptInvite({
    required int categoryId,
    required int userId,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final result = await _categoryService.acceptInvite(
        categoryId: categoryId,
        userId: userId,
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('초대 수락 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  // 카테고리 초대 거절
  @override
  Future<bool> declineInvite({
    required int categoryId,
    required int userId,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final result = await _categoryService.declineInvite(
        categoryId: categoryId,
        userId: userId,
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('초대 거절 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  @override
  void clearError() {
    _clearError();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}
