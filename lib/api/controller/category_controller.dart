import 'package:flutter/material.dart';
import 'package:soi/api/models/category.dart';

/// 카테고리 컨트롤러 추상 클래스
///
/// 카테고리 관련 기능을 정의하는 인터페이스입니다.
abstract class CategoryController extends ChangeNotifier {
  bool get isLoading;
  String? get errorMessage;

  // 카테고리 생성
  Future<int?> createCategory({
    required int requesterId,
    required String name,
    List<int> receiverIds = const [],
    bool isPublic = true,
  });

  // 카테고리 조회
  Future<List<Category>> getCategories({
    required int userId,
    CategoryFilter filter = CategoryFilter.all,
  });

  // 모든 카테고리 조회
  Future<List<Category>> getAllCategories(int userId);

  // 공개 카테고리 조회
  Future<List<Category>> getPublicCategories(int userId);

  // 비공개 카테고리 조회
  Future<List<Category>> getPrivateCategories(int userId);

  // 카테고리 고정
  Future<bool> toggleCategoryPin({
    required int categoryId,
    required int userId,
  });

  // 카테고리 초대
  Future<bool> inviteUsersToCategory({
    required int categoryId,
    required int requesterId,
    required List<int> receiverIds,
  });

  // 카테고리 초대 수락
  Future<bool> acceptInvite({required int categoryId, required int userId});
  // 초대 거절
  Future<bool> declineInvite({required int categoryId, required int userId});

  void clearError();
}
