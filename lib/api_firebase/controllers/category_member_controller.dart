import 'package:flutter/material.dart';
import '../services/category_service.dart';

/// 카테고리 멤버 관리를 담당하는 컨트롤러
class CategoryMemberController extends ChangeNotifier {
  final CategoryService _categoryService = CategoryService();
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 카테고리에 사용자 추가 (닉네임)
  Future<void> addUserToCategory(String categoryId, String nickName) async {
    await _executeWithLoading(() async {
      final result = await _categoryService.addUserToCategory(
        categoryId: categoryId,
        nickName: nickName,
      );
      if (!result.isSuccess) {
        _error = result.error;
        throw Exception(result.error);
      }
    });
  }

  /// 카테고리에 사용자 추가 (UID)
  Future<void> addUidToCategory(String categoryId, String uid) async {
    await _executeWithLoading(() async {
      final result = await _categoryService.addUidToCategory(
        categoryId: categoryId,
        uid: uid,
      );
      if (!result.isSuccess) {
        _error = result.error;
        throw Exception(result.error);
      }
    });
  }

  /// 카테고리에서 나가기
  Future<void> leaveCategoryByUid(String categoryId, String userId) async {
    await _executeWithLoading(() async {
      final result = await _categoryService.removeUidFromCategory(
        categoryId: categoryId,
        uid: userId,
      );
      if (!result.isSuccess) {
        _error = result.error;
        throw Exception(result.error);
      }
    });
  }

  /// 카테고리 초대 수락
  Future<String?> acceptCategoryInvite({
    required String inviteId,
    required String userId,
  }) async {
    String? categoryId;
    await _executeWithLoading(() async {
      final result = await _categoryService.acceptPendingInvite(
        inviteId: inviteId,
        userId: userId,
      );
      if (!result.isSuccess) {
        _error = result.error;
      } else {
        categoryId = result.data as String?;
      }
    });
    return categoryId;
  }

  /// 카테고리 초대 거절
  Future<bool> declineCategoryInvite({
    required String inviteId,
    required String userId,
  }) async {
    bool success = false;
    await _executeWithLoading(() async {
      final result = await _categoryService.declinePendingInvite(
        inviteId: inviteId,
        userId: userId,
      );
      if (!result.isSuccess) {
        _error = result.error;
      } else {
        success = true;
      }
    });
    return success;
  }

  /// 에러 상태 초기화
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// 로딩 상태와 함께 작업 실행
  Future<void> _executeWithLoading(Future<void> Function() action) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      await action();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
