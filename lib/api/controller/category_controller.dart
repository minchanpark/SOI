import 'package:flutter/foundation.dart';
import 'package:soi/api/models/category.dart' as model;
import 'package:soi/api/services/category_service.dart';

/// 카테고리 컨트롤러
///
/// 카테고리 관련 UI 상태 관리 및 비즈니스 로직을 담당합니다.
/// CategoryService를 내부적으로 사용하며, API 변경 시 Service만 수정하면 됩니다.
class CategoryController extends ChangeNotifier {
  final CategoryService _categoryService;

  // 카테고리 캐시 (filter별로 관리)
  final Map<model.CategoryFilter, List<model.Category>> _categoriesCache = {};
  int? _lastLoadedUserId;
  DateTime? _lastLoadTime;
  static const Duration _cacheTimeout = Duration(seconds: 30);

  // 현재 표시 중인 카테고리 (마지막으로 로드한 filter의 데이터)
  List<model.Category> _currentCategories = [];

  // 로딩 상태
  bool _isLoading = false;

  // 에러 메시지
  String? _errorMessage;

  /// 생성자
  ///
  /// [categoryService]를 주입받아 사용합니다. 테스트 시 MockCategoryService를 주입할 수 있습니다.
  CategoryController({CategoryService? categoryService})
    : _categoryService = categoryService ?? CategoryService();

  /// 로딩 상태
  bool get isLoading => _isLoading;

  /// 에러 메시지
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
  ///
  /// **로드 전략:**
  /// - ALL: PUBLIC, PRIVATE, ALL 모두 로드 (병렬 처리)
  /// - PUBLIC: PUBLIC만 로드
  /// - PRIVATE: PRIVATE만 로드
  Future<List<model.Category>> loadCategories(
    int userId, {
    model.CategoryFilter filter = model.CategoryFilter.all,
    bool forceReload = true,
    int page = 0,
    bool fetchAllPages = true,
    int maxPages = 50,
  }) async {
    final now = DateTime.now();
    final isCacheValid =
        _lastLoadTime != null && now.difference(_lastLoadTime!) < _cacheTimeout;

    // 캐시가 유효하고 같은 userId면 캐시된 데이터 반환
    if (!forceReload && _lastLoadedUserId == userId && isCacheValid) {
      // ALL 필터인 경우: ALL, PUBLIC, PRIVATE 모두 캐시되어 있어야 함
      // ALL 필터라는 것은: 사용자가 전체 카테고리를 보고자 하는 것
      if (filter == model.CategoryFilter.all) {
        final hasAllCaches =
            _categoriesCache.containsKey(model.CategoryFilter.all) &&
            _categoriesCache.containsKey(model.CategoryFilter.public_) &&
            _categoriesCache.containsKey(model.CategoryFilter.private_);

        if (hasAllCaches) {
          _currentCategories = _categoriesCache[filter]!;

          notifyListeners();
          return _currentCategories;
        }
      }
      // 그 외 필터인 경우: PUBLIC 또는 PRIVATE
      else {
        // PUBLIC 또는 PRIVATE 필터: 해당 필터만 캐시되어 있으면 됨
        if (_categoriesCache.containsKey(filter) &&
            _categoriesCache[filter]!.isNotEmpty) {
          _currentCategories = _categoriesCache[filter]!;
          notifyListeners();
          return _currentCategories;
        }
      }
    }
    _setLoading(true);
    _clearError();

    try {
      if (filter == model.CategoryFilter.all) {
        // ALL 필터: PUBLIC, PRIVATE, ALL 모두 병렬로 로드
        final results = await Future.wait([
          // 전체 카테고리를 먼저 로드
          _categoryService.getCategories(
            userId: userId,
            filter: model.CategoryFilter.all,
            page: page,
            fetchAllPages: fetchAllPages,
            maxPages: maxPages,
          ),
          // PUBLIC 카테고리를 병렬로 로드
          _categoryService.getCategories(
            userId: userId,
            filter: model.CategoryFilter.public_,
            page: page,
            fetchAllPages: fetchAllPages,
            maxPages: maxPages,
          ),
          // PRIVATE 카테고리를 병렬로 로드
          _categoryService.getCategories(
            userId: userId,
            filter: model.CategoryFilter.private_,
            page: page,
            fetchAllPages: fetchAllPages,
            maxPages: maxPages,
          ),
        ]);

        // 각 filter별 캐시 저장
        _categoriesCache[model.CategoryFilter.all] =
            results[0]; // 전체 카테고리 목록 캐시를 저장
        _categoriesCache[model.CategoryFilter.public_] =
            results[1]; // 공개 카테고리 목록 캐시를 저장
        _categoriesCache[model.CategoryFilter.private_] =
            results[2]; // 비공개 카테고리 목록 캐시를 저장
        _currentCategories = results[0]; // ALL을 현재 카테고리로 설정
      } else {
        // PUBLIC 또는 PRIVATE 필터: 해당 필터만 로드
        final categories = await _categoryService.getCategories(
          userId: userId,
          filter: filter,
          page: page,
          fetchAllPages: fetchAllPages,
          maxPages: maxPages,
        );

        _categoriesCache[filter] = categories;
        _currentCategories = categories;
      }

      _lastLoadedUserId = userId;
      _lastLoadTime = DateTime.now();

      _setLoading(false);
      return _currentCategories;
    } catch (e) {
      _setError('카테고리 조회 실패: $e');
      debugPrint('[CategoryController] 카테고리 로드 실패: $e');
      _setLoading(false);
      return [];
    }
  }

  /// 캐시 무효화
  void invalidateCache() {
    _categoriesCache.clear();
    _currentCategories = [];
    _lastLoadedUserId = null;
    _lastLoadTime = null;
    notifyListeners();
  }

  /// 특정 카테고리를 읽음 상태로 표시
  ///
  /// 서버에서 isNew 값이 false로 내려오더라도 캐시가 남아 있으면
  /// UI에 즉시 반영되지 않을 수 있으므로, 사용자가 카테고리를 열었을 때
  /// 로컬 캐시의 isNew를 false로 갱신한다.
  void markCategoryAsViewed(int categoryId) {
    bool updated = false;

    bool updateList(List<model.Category>? categories) {
      if (categories == null) return false;
      final index = categories.indexWhere((c) => c.id == categoryId);
      if (index == -1) return false;
      final target = categories[index];
      if (!target.isNew) return false;
      categories[index] = target.copyWith(isNew: false);
      return true;
    }

    // 현재 목록 갱신
    updated = updateList(_currentCategories) || updated;

    // 필터별 캐시 갱신
    _categoriesCache.updateAll((key, value) {
      final list = List<model.Category>.from(value);
      if (updateList(list)) {
        updated = true;
        return list;
      }
      return value;
    });

    if (updated) {
      notifyListeners();
    }
  }

  /// 특정 카테고리 캐시 갱신 헬퍼
  /// 카테고리 이름을 수정하고 나서 UI에 바로 반영되지 않는 문제를 해결하기 위해서 사용
  ///
  /// Parameters:
  ///   - [categoryId]: 카테고리 ID
  ///   - [update]: 카테고리 객체를 받아 수정된 객체를 반환하는 함수
  void _updateCachedCategory(
    int categoryId,
    model.Category Function(model.Category category) update,
  ) {
    bool updated = false;

    // 특정 카테고리만 갱신하는 내부 함수
    List<model.Category> updateList(List<model.Category> categories) {
      final index = categories.indexWhere((c) => c.id == categoryId);
      if (index == -1) return categories;

      final newList = List<model.Category>.from(categories);
      newList[index] = update(newList[index]);
      updated = true;
      return newList;
    }

    // 현재 목록 갱신
    _currentCategories = updateList(_currentCategories);

    // 필터별 캐시 갱신
    _categoriesCache.updateAll((key, value) => updateList(value));

    if (updated) {
      notifyListeners();
    }
  }

  void _updateCategoryNameInCache(int categoryId, String? newName) {
    if (newName == null) return;
    _updateCachedCategory(
      categoryId,
      (category) => category.copyWith(name: newName),
    );
  }

  /// ID로 캐시된 카테고리 조회
  model.Category? getCategoryById(int categoryId) {
    // 1) 현재 표시 중인 목록에서 우선 검색
    for (final c in _currentCategories) {
      if (c.id == categoryId) return c;
    }

    // 2) ALL 캐시(전체 목록)에서 검색 (화면/필터가 바뀐 경우를 대비)
    final allCache = _categoriesCache[model.CategoryFilter.all];
    if (allCache != null) {
      for (final c in allCache) {
        if (c.id == categoryId) return c;
      }
    }

    // 3) 기타 필터 캐시에서 검색
    for (final list in _categoriesCache.values) {
      for (final c in list) {
        if (c.id == categoryId) return c;
      }
    }

    return null;
  }

  /// 카테고리 생성
  /// Parameters:
  ///   - [requesterId]: 요청자 사용자 ID
  ///   - [name]: 카테고리 이름
  ///   - [receiverIds]: 초대할 사용자 ID 목록
  ///   - [isPublic]: 공개 여부
  ///
  /// Returns:
  ///   - [int]: 생성된 카테고리 ID (실패 시 null)
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

  /// 카테고리 조회
  /// Parameters:
  /// - [userId]: 사용자 ID
  /// - [filter]: 카테고리 필터 (기본값: all)
  Future<List<model.Category>> getCategories({
    required int userId,
    model.CategoryFilter filter = model.CategoryFilter.all,
    int page = 0,
    bool fetchAllPages = false,
    int maxPages = 50,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final categories = await _categoryService.getCategories(
        userId: userId,
        filter: filter,
        page: page,
        fetchAllPages: fetchAllPages,
        maxPages: maxPages,
      );
      _setLoading(false);
      return categories;
    } catch (e) {
      _setError('카테고리 조회 실패: $e');
      _setLoading(false);
      return [];
    }
  }

  /// 모든 카테고리 조회
  /// Parameters:
  /// - [userId]: 사용자 ID
  ///
  /// Returns:
  /// - [List<model.Category>]: 모든 카테고리 목록
  Future<List<model.Category>> getAllCategories(int userId) =>
      getCategories(userId: userId, filter: model.CategoryFilter.all);

  // 공개 카테고리 조회
  Future<List<model.Category>> getPublicCategories(int userId) =>
      getCategories(userId: userId, filter: model.CategoryFilter.public_);

  // 비공개 카테고리 조회
  Future<List<model.Category>> getPrivateCategories(int userId) =>
      getCategories(userId: userId, filter: model.CategoryFilter.private_);

  /// 카테고리 고정
  /// Parameters:
  /// - [categoryId]: 카테고리 ID
  /// - [userId]: 사용자 ID
  ///
  /// Returns:
  /// - [bool]: 고정 성공 여부
  ///   - true: 고정됨
  ///   - false: 고정 해제됨
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

  /// 카테고리 알림 설정
  ///
  /// Parameters:
  /// - [categoryId]: 카테고리 ID
  /// - [userId]: 사용자 ID
  ///
  /// Returns:
  /// - [bool]: 알림 설정 여부
  Future<bool> setCategoryAlert({
    required int categoryId,
    required int userId,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final result = await _categoryService.setCategoryAlert(
        categoryId: categoryId,
        userId: userId,
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('카테고리 알림 설정 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  /// 카테고리 초대
  /// Parameters:
  /// - [categoryId]: 카테고리 ID
  /// - [requesterId]: 요청자 사용자 ID
  /// - [receiverIds]: 초대할 사용자 ID 목록
  ///
  /// Returns:
  /// - [bool]: 초대 성공 여부
  ///   - true: 초대 성공
  ///   - false: 초대 실패
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

  /// 카테고리 초대 수락
  ///
  /// Parameters:
  /// - [categoryId]: 카테고리 ID
  /// - [userId]: 사용자 ID
  ///
  /// Returns:
  /// - [bool]: 수락 성공 여부
  ///   - true: 수락 성공
  ///   - false: 수락 실패
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

  /// 카테고리 초대 거절
  ///
  /// Parameters:
  /// - [categoryId]: 카테고리 ID
  /// - [userId]: 사용자 ID
  ///
  /// Returns:
  /// - [bool]: 거절 성공 여부
  ///   - true: 거절 성공
  ///   - false: 거절 실패
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

  // ============================================
  // 카테고리 설정 (이름, 프로필)
  // ============================================

  /// 카테고리 커스텀 이름 수정
  ///
  /// Parameters:
  /// - [categoryId]: 카테고리 ID
  /// - [userId]: 사용자 ID
  /// - [name]: 새 이름
  ///
  /// Returns:
  /// - [bool]: 수정 성공 여부
  ///   - true: 수정 성공
  ///   - false: 수정 실패
  Future<bool> updateCustomName({
    required int categoryId,
    required int userId,
    String? name,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      // 카테고리 이름을 수정
      final result = await _categoryService.updateCustomName(
        categoryId: categoryId,
        userId: userId,
        name: name,
      );
      // 수정이 성공하면 캐시를 갱신하고 변경사항을 바로 UI에 반영
      if (result) {
        _updateCategoryNameInCache(categoryId, name);
      }

      _setLoading(false);
      return result;
    } catch (e) {
      _setError('카테고리 이름 수정 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  /// 카테고리 커스텀 프로필 이미지 수정
  ///
  /// Parameters:
  /// - [categoryId]: 카테고리 ID
  /// - [userId]: 사용자 ID
  /// - [profileImageKey]: 새 프로필 이미지 키 (null이면 기본 이미지로 설정)
  ///
  /// Returns:
  /// - [bool]: 수정 성공 여부
  ///   - true: 수정 성공
  ///   - false: 수정 실패
  Future<bool> updateCustomProfile({
    required int categoryId,
    required int userId,
    String? profileImageKey,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final result = await _categoryService.updateCustomProfile(
        categoryId: categoryId,
        userId: userId,
        profileImageKey: profileImageKey,
      );

      // 서버에는 반영되지만 UI가 바로 갱신되지 않는 경우가 있어,
      // 성공 시 로컬 캐시도 즉시 갱신하여 화면에 바로 반영한다.
      if (result) {
        // 프로필 이미지 키가 null이거나 빈 문자열인 경우 null로 정규화
        final normalized =
            (profileImageKey == null || profileImageKey.trim().isEmpty)
            ? null
            : profileImageKey.trim();

        // 카테고리 캐시 갱신
        _updateCachedCategory(
          categoryId,
          (category) => category.copyWith(photoUrl: normalized),
        );
      }

      _setLoading(false);
      return result;
    } catch (e) {
      _setError('카테고리 프로필 수정 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  // ============================================
  // 카테고리 삭제 (나가기)
  // ============================================

  /// 카테고리 나가기 (삭제)
  ///
  /// Parameters:
  ///   - [userId]: 사용자 ID
  ///   - [categoryId]: 카테고리 ID
  ///
  /// Returns:
  ///   - [bool]: 나가기 성공 여부
  ///     - true: 나가기 성공
  ///     - false: 나가기 실패
  Future<bool> leaveCategory({
    required int userId,
    required int categoryId,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      // API 호출 - 카테고리 나가기
      final result = await _categoryService.leaveCategory(
        userId: userId,
        categoryId: categoryId,
      );

      // 성공 시 캐시 무효화
      if (result) {
        invalidateCache();
      }

      _setLoading(false);
      return result;
    } catch (e) {
      _setError('카테고리 나가기 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  /// 카테고리 삭제 (leaveCategory의 별칭)
  ///
  /// Parameters:
  ///   - [userId]: 사용자 ID
  ///   - [categoryId]: 카테고리 ID
  ///
  /// Returns:
  ///   - [bool]: 삭제 성공 여부
  ///     - true: 삭제 성공
  ///     - false: 삭제 실패
  Future<bool> deleteCategory({
    required int userId,
    required int categoryId,
  }) async {
    return leaveCategory(userId: userId, categoryId: categoryId);
  }

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
