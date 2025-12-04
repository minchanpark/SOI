import 'package:flutter/material.dart';
import 'package:soi/api/models/category.dart';

/// 카테고리 컨트롤러 추상 클래스
///
/// 카테고리 관련 기능을 정의하는 인터페이스입니다.
/// 각 구현체는 이 클래스를 상속받아 구체적인 동작을 구현해야 합니다.
///
/// 의존성 주입 및 테스트 용이성을 위해 추상 클래스로 정의됩니다.
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

  // 카테고리 커스텀 이름 수정
  Future<bool> updateCustomName({
    required int categoryId,
    required int userId,
    String? name,
  });

  // 카테고리 커스텀 프로필 이미지 수정
  Future<bool> updateCustomProfile({
    required int categoryId,
    required int userId,
    String? profileImageKey,
  });

  // 카테고리 나가기 (삭제)
  Future<bool> leaveCategory({required int userId, required int categoryId});

  // 카테고리 삭제 (leaveCategory의 별칭)
  Future<bool> deleteCategory({required int userId, required int categoryId});

  void clearError();
}
