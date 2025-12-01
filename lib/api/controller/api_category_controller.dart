import 'package:soi/api/controller/category_controller.dart';
import 'package:soi/api/models/category.dart';
import 'package:soi/api/services/category_service.dart';

/// REST API 기반 카테고리 컨트롤러 구현체
class ApiCategoryController extends CategoryController {
  final CategoryService _categoryService;

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
  Future<List<Category>> getCategories({
    required int userId,
    CategoryFilter filter = CategoryFilter.all,
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
  Future<List<Category>> getAllCategories(int userId) =>
      getCategories(userId: userId, filter: CategoryFilter.all);

  // 공개 카테고리 조회
  @override
  Future<List<Category>> getPublicCategories(int userId) =>
      getCategories(userId: userId, filter: CategoryFilter.public_);

  // 비공개 카테고리 조회
  @override
  Future<List<Category>> getPrivateCategories(int userId) =>
      getCategories(userId: userId, filter: CategoryFilter.private_);

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
