import 'dart:collection';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:soi/api_firebase/services/auth_service.dart';
import '../repositories/category_repository.dart';
import '../repositories/category_invite_repository.dart';
import '../models/category_data_model.dart';
import '../models/auth_result.dart';
import 'friend_service.dart';
import 'category_invite_service.dart';
import 'category_photo_service.dart';
import 'category_member_service.dart';
import '../repositories/friend_repository.dart';
import '../repositories/user_search_repository.dart';

/// 카테고리 핵심 비즈니스 로직을 처리하는 Service
class CategoryService {
  // Singleton pattern
  static final CategoryService _instance = CategoryService._internal();
  factory CategoryService() => _instance;
  CategoryService._internal();

  final CategoryRepository _repository = CategoryRepository();

  // 다른 서비스들 (Lazy initialization)
  CategoryInviteRepository? _categoryInviteRepository;
  CategoryInviteRepository get categoryInviteRepository {
    _categoryInviteRepository ??= CategoryInviteRepository();
    return _categoryInviteRepository!;
  }

  FriendService? _friendService;
  FriendService get friendService {
    _friendService ??= FriendService(
      friendRepository: FriendRepository(),
      userSearchRepository: UserSearchRepository(),
    );
    return _friendService!;
  }

  CategoryInviteService? _inviteService;
  CategoryInviteService get inviteService {
    _inviteService ??= CategoryInviteService();
    return _inviteService!;
  }

  CategoryPhotoService? _photoService;
  CategoryPhotoService get photoService {
    _photoService ??= CategoryPhotoService();
    return _photoService!;
  }

  CategoryMemberService? _memberService;
  CategoryMemberService get memberService {
    _memberService ??= CategoryMemberService();
    return _memberService!;
  }

  AuthService? _authService;
  AuthService get authService {
    _authService ??= AuthService();
    return _authService!;
  }

  // ==================== 비즈니스 로직 ====================

  String? _validateCategoryName(String name) {
    if (name.trim().isEmpty) {
      return '카테고리 이름을 입력해주세요.';
    }
    if (name.trim().length > 20) {
      return '카테고리 이름은 20글자 이하여야 합니다.';
    }
    return null;
  }

  String _normalizeCategoryName(String name) => name.trim();

  // ==================== 카테고리 관리 ====================

  /// 카테고리 목록 스트림 (차단 및 pending 필터링)
  Stream<List<CategoryDataModel>> getUserCategoriesStream(String userId) {
    if (userId.isEmpty) return Stream.value([]);

    return _repository.getUserCategoriesStream(userId).asyncMap((
      categories,
    ) async {
      final filteredCategories = await _filterCategoriesWithBlockedUsers(
        categories,
      );

      final activeCategoriesWithPending = <CategoryDataModel>[];

      for (final category in filteredCategories) {
        final pendingInvite = await categoryInviteRepository
            .getPendingInviteForCategory(
              categoryId: category.id,
              invitedUserId: userId,
            );

        if (pendingInvite == null) {
          activeCategoriesWithPending.add(category);
        }
      }

      return activeCategoriesWithPending;
    });
  }

  /// 단일 카테고리 스트림
  Stream<CategoryDataModel?> getCategoryStream(String categoryId) {
    if (categoryId.isEmpty) return Stream.value(null);
    return _repository.getCategoryStream(categoryId);
  }

  /// 카테고리 목록 조회 (차단 및 pending 필터링)
  Future<List<CategoryDataModel>> getUserCategories(String userId) async {
    if (userId.isEmpty) return [];

    try {
      final categories = await _repository.getUserCategories(userId);
      final filteredCategories = await _filterCategoriesWithBlockedUsers(
        categories,
      );

      final activeCategoriesWithPending = <CategoryDataModel>[];

      for (final category in filteredCategories) {
        final pendingInvite = await categoryInviteRepository
            .getPendingInviteForCategory(
              categoryId: category.id,
              invitedUserId: userId,
            );

        if (pendingInvite != null) {
          continue;
        }

        activeCategoriesWithPending.add(category);
      }

      return activeCategoriesWithPending;
    } catch (e) {
      return [];
    }
  }

  /// 카테고리 생성
  /// 카테고리를 추가하는데, 친구가 아닌 멤버가 있으면 초대를 생성하고 그 멤버는 바로 추가하지 않고,
  /// 알림을 보내서 수락하도록 한다.
  Future<AuthResult> createCategory({
    required String name,
    required List<String> mates,
    Map<String, String>? mateProfileImages,
  }) async {
    try {
      final validationError = _validateCategoryName(name);
      if (validationError != null) {
        return AuthResult.failure(validationError);
      }

      final normalizedName = _normalizeCategoryName(name);
      final uniqueMates = LinkedHashSet<String>.from(mates);

      if (uniqueMates.isEmpty) {
        return AuthResult.failure('최소 1명의 멤버가 필요합니다.');
      }

      final currentUserId = authService.currentUser?.uid;
      if (currentUserId == null || currentUserId.isEmpty) {
        return AuthResult.failure('로그인이 필요합니다.');
      }

      final sanitizedMates = uniqueMates.toList();

      if (!sanitizedMates.contains(currentUserId)) {
        return AuthResult.failure('카테고리 생성자가 멤버에 포함되어야 합니다.');
      }

      // 생성자와 멤버 간 친구 관계 확인 (병렬 처리)
      final otherMates =
          sanitizedMates.where((m) => m != currentUserId).toList();
      final pendingMateFutures = <String, Future<List<String>>>{};

      if (otherMates.isEmpty) {
        debugPrint('생성자만 있는 카테고리 - 친구 확인 생략');
      } else {
        // 배치로 모든 친구 관계를 한 번에 확인
        final friendshipResults = await friendService.areBatchMutualFriends(
          currentUserId,
          otherMates,
        );

        final nonFriendMates = <String>[];
        for (final mateId in otherMates) {
          final isFriend = friendshipResults[mateId] ?? false;

          if (!isFriend) {
            nonFriendMates.add(mateId);
          }
        }

        if (nonFriendMates.isNotEmpty) {
          debugPrint('카테고리 생성 불가: 생성자와 친구가 아닌 멤버 ${nonFriendMates.length}명');
          return AuthResult.failure('카테고리는 친구들과만 만들 수 있습니다. 먼저 친구를 추가해주세요.');
        }

        // 멤버별 친구 검증을 미리 시작해서 카테고리 생성과 병렬 처리
        for (final mateId in otherMates) {
          pendingMateFutures[mateId] = inviteService.getPendingMateIdsForUser(
            allMates: sanitizedMates,
            targetUserId: mateId,
          );
        }
      }

      // 카테고리 생성
      final category = CategoryDataModel(
        id: '',
        name: normalizedName,
        mates: sanitizedMates,
        createdAt: DateTime.now(),
        mateProfileImages: mateProfileImages,
      );

      final categoryId = await _repository.createCategory(category);
      final categoryWithId = category.copyWith(id: categoryId);

      // 각 멤버별 초대 처리 (병렬 처리로 최적화)
      await Future.wait(
        otherMates.map((mateId) async {
          try {
            // 친구가 아닌 멤버 가지고 오기
            final pendingFuture = pendingMateFutures[mateId];
            final nonFriendMateIds = pendingFuture == null
                ? <String>[]
                : await pendingFuture;

            if (nonFriendMateIds.isNotEmpty) {
              // 친구가 아닌 멤버가 있으면 초대 생성
              final inviteId = await inviteService.createOrUpdateInvite(
                category: categoryWithId,
                invitedUserId: mateId,
                inviterUserId: currentUserId,
                blockedMateIds: nonFriendMateIds,
              );

              // 카테고리 초대 알림을 만든다.
              await inviteService.notificationService
                  .createCategoryInviteNotification(
                    categoryId: categoryId,
                    actorUserId: currentUserId,
                    recipientUserIds: [mateId],
                    requiresAcceptance: true,
                    categoryInviteId: inviteId,
                    pendingMemberIds: nonFriendMateIds,
                  );
            } else {
              // 친구가 아닌 멤버가 없는 경우, 바로 추가하고 알림 보냄
              await inviteService.notificationService
                  .createCategoryInviteNotification(
                    categoryId: categoryId,
                    actorUserId: currentUserId,
                    recipientUserIds: [mateId],
                    requiresAcceptance: false,
                  );
            }
          } catch (e) {
            debugPrint('$mateId 초대 처리 실패: $e');
          }
        }),
      );

      return AuthResult.success(categoryId);
    } catch (e) {
      debugPrint('카테고리 생성 실패: $e');
      return AuthResult.failure('카테고리 생성 중 오류가 발생했습니다.');
    }
  }

  /// 커스텀 이름 업데이트
  Future<AuthResult> updateCustomCategoryName({
    required String categoryId,
    required String userId,
    required String customName,
  }) async {
    try {
      final validationError = _validateCategoryName(customName);
      if (validationError != null) {
        return AuthResult.failure(validationError);
      }

      final normalizedName = _normalizeCategoryName(customName);

      await _repository.updateCustomName(
        categoryId: categoryId,
        userId: userId,
        customName: normalizedName,
      );

      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure('커스텀 이름 설정 중 오류가 발생했습니다.');
    }
  }

  /// 카테고리 수정
  Future<AuthResult> updateCategory({
    required String categoryId,
    String? name,
    List<String>? mates,
    bool? isPinned,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (name != null) {
        final validationError = _validateCategoryName(name);
        if (validationError != null) {
          return AuthResult.failure(validationError);
        }
        updateData['name'] = _normalizeCategoryName(name);
      }

      if (mates != null) {
        if (mates.isEmpty) {
          return AuthResult.failure('최소 1명의 멤버가 필요합니다.');
        }
        updateData['mates'] = mates;
      }

      if (isPinned != null) {
        updateData['isPinned'] = isPinned;
      }

      if (updateData.isEmpty) {
        return AuthResult.failure('업데이트할 내용이 없습니다.');
      }

      await _repository.updateCategory(categoryId, updateData);
      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure('카테고리 수정 중 오류가 발생했습니다.');
    }
  }

  /// 고정 상태 업데이트
  Future<AuthResult> updateUserPinStatus({
    required String categoryId,
    required String userId,
    required bool isPinned,
  }) async {
    try {
      if (categoryId.isEmpty || userId.isEmpty) {
        return AuthResult.failure('유효하지 않은 카테고리 또는 사용자입니다.');
      }

      await _repository.updateUserPinStatus(
        categoryId: categoryId,
        userId: userId,
        isPinned: isPinned,
      );

      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure('고정 상태 업데이트 중 오류가 발생했습니다.');
    }
  }

  /// 카테고리 삭제
  Future<AuthResult> deleteCategory(String categoryId) async {
    try {
      if (categoryId.isEmpty) {
        return AuthResult.failure('유효하지 않은 카테고리입니다.');
      }

      await _repository.deleteCategory(categoryId);
      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure('카테고리 삭제 중 오류가 발생했습니다.');
    }
  }

  /// 카테고리 정보 가져오기
  Future<CategoryDataModel?> getCategory(String categoryId) async {
    try {
      if (categoryId.isEmpty) return null;
      return await _repository.getCategory(categoryId);
    } catch (e) {
      return null;
    }
  }

  // ==================== 위임 메서드들 ====================

  // 초대 관련
  Future<AuthResult> acceptPendingInvite({
    required String inviteId,
    required String userId,
  }) => inviteService.acceptInvite(inviteId: inviteId, userId: userId);

  Future<AuthResult> declinePendingInvite({
    required String inviteId,
    required String userId,
  }) => inviteService.declineInvite(inviteId: inviteId, userId: userId);

  // 사진 관련
  Future<AuthResult> addPhotoToCategory({
    required String categoryId,
    required File imageFile,
    String? description,
  }) => photoService.addPhoto(
    categoryId: categoryId,
    imageFile: imageFile,
    description: description,
  );

  Future<AuthResult> removePhotoFromCategory({
    required String categoryId,
    required String photoId,
    required String imageUrl,
  }) => photoService.removePhoto(
    categoryId: categoryId,
    photoId: photoId,
    imageUrl: imageUrl,
  );

  Stream<List<Map<String, dynamic>>> getCategoryPhotosStream(
    String categoryId,
  ) => photoService.getPhotosStream(categoryId);

  Future<AuthResult> updateCoverPhotoFromGallery({
    required String categoryId,
    required File imageFile,
  }) => photoService.updateCoverPhotoFromGallery(
    categoryId: categoryId,
    imageFile: imageFile,
  );

  Future<AuthResult> updateCoverPhotoFromCategory({
    required String categoryId,
    required String photoUrl,
  }) => photoService.updateCoverPhotoFromCategory(
    categoryId: categoryId,
    photoUrl: photoUrl,
  );

  Future<AuthResult> deleteCoverPhoto(String categoryId) =>
      photoService.deleteCoverPhoto(categoryId);

  Future<void> updateCoverPhotoToLatestAfterDeletion(String categoryId) =>
      photoService.updateCoverPhotoToLatestAfterDeletion(categoryId);

  Future<void> updateLastPhotoInfo({
    required String categoryId,
    required String uploadedBy,
  }) => photoService.updateLastPhotoInfo(
    categoryId: categoryId,
    uploadedBy: uploadedBy,
  );

  Future<void> updateUserViewTime({
    required String categoryId,
    required String userId,
  }) => photoService.updateUserViewTime(categoryId: categoryId, userId: userId);

  // 멤버 관련
  Future<AuthResult> addUserToCategory({
    required String categoryId,
    required String nickName,
  }) => memberService.addUserByNickname(
    categoryId: categoryId,
    nickName: nickName,
  );

  Future<AuthResult> addUidToCategory({
    required String categoryId,
    required String uid,
  }) => memberService.addUserByUid(categoryId: categoryId, uid: uid);

  Future<AuthResult> removeUidFromCategory({
    required String categoryId,
    required String uid,
  }) => memberService.removeUser(categoryId: categoryId, uid: uid);

  bool isUserMemberOfCategory(CategoryDataModel category, String userId) =>
      memberService.isUserMember(category, userId);

  // ==================== 내부 헬퍼 ====================

  Future<List<CategoryDataModel>> _filterCategoriesWithBlockedUsers(
    List<CategoryDataModel> categories,
  ) async {
    try {
      final blockedByMe = await friendService.getBlockedUsers();

      if (blockedByMe.isEmpty) {
        return categories;
      }

      final filteredCategories = <CategoryDataModel>[];
      final currentUserId = authService.currentUser?.uid;

      for (final category in categories) {
        if (category.mates.length == 2) {
          final otherUser = category.mates.firstWhere(
            (uid) => uid != currentUserId,
            orElse: () => '',
          );

          if (otherUser.isNotEmpty && blockedByMe.contains(otherUser)) {
            continue;
          }
        }

        filteredCategories.add(category);
      }

      return filteredCategories;
    } catch (e) {
      debugPrint('카테고리 필터링 중 오류 발생: $e');
      return categories;
    }
  }
}
