import 'package:flutter/material.dart';
import '../repositories/category_repository.dart';
import '../repositories/category_invite_repository.dart';
import '../repositories/friend_repository.dart';
import '../repositories/user_search_repository.dart';
import '../models/category_data_model.dart';
import '../models/category_invite_model.dart';
import '../models/auth_result.dart';
import 'notification_service.dart';
import 'friend_service.dart';

/// 카테고리 초대 관련 비즈니스 로직을 처리하는 Service
class CategoryInviteService {
  // Singleton pattern
  static final CategoryInviteService _instance =
      CategoryInviteService._internal();
  factory CategoryInviteService() => _instance;
  CategoryInviteService._internal();

  final CategoryRepository _repository = CategoryRepository();
  final CategoryInviteRepository _inviteRepository = CategoryInviteRepository();

  // Lazy initialization
  NotificationService? _notificationService;
  NotificationService get notificationService {
    _notificationService ??= NotificationService();
    return _notificationService!;
  }

  FriendService? _friendService;
  FriendService get friendService {
    _friendService ??= FriendService(
      friendRepository: FriendRepository(),
      userSearchRepository: UserSearchRepository(),
    );
    return _friendService!;
  }

  /// 초대 대상자와 기존 멤버 간 친구가 아닌 ID 목록 반환 (기존 카테고리에 사용자를 추가하는 경우)
  Future<List<String>> getPendingMateIdsForUser({
    required List<String> allMates,
    required String targetUserId,
  }) async {
    final otherMates = allMates.where((m) => m != targetUserId).toList();
    if (otherMates.isEmpty) {
      debugPrint('   비교할 멤버 없음');
      return [];
    }

    // 배치로 모든 친구 관계를 한 번에 확인 (병렬 처리)
    final friendshipResults = await friendService.areBatchMutualFriends(
      targetUserId,
      otherMates,
    );

    final nonFriendIds = <String>[];
    for (final mateId in otherMates) {
      final isFriend = friendshipResults[mateId] ?? false;

      if (!isFriend) {
        nonFriendIds.add(mateId);
      }
    }

    if (nonFriendIds.isNotEmpty) {
      debugPrint('친구 아닌 멤버: $nonFriendIds');
    }

    return nonFriendIds;
  }

  /// 초대 대상자와 기존 멤버 간 친구가 아닌 ID 목록 반환
  Future<List<String>> getPendingMateIds({
    required CategoryDataModel category,
    required String invitedUserId,
  }) async {
    if (category.mates.isEmpty) {
      debugPrint('카테고리에 멤버가 없음');
      return [];
    }

    final existingMateIds =
        category.mates.where((mateId) => mateId != invitedUserId).toSet();

    if (existingMateIds.isEmpty) {
      debugPrint('비교할 기존 멤버가 없음');
      return [];
    }

    // 배치로 모든 친구 관계를 한 번에 확인 (병렬 처리)
    final friendshipResults = await friendService.areBatchMutualFriends(
      invitedUserId,
      existingMateIds.toList(),
    );

    final nonFriendIds = <String>[];
    for (final mateId in existingMateIds) {
      final isFriend = friendshipResults[mateId] ?? false;

      if (!isFriend) {
        debugPrint('결과: $invitedUserId ←→ $mateId 상호 친구 아님');
        nonFriendIds.add(mateId);
      }
    }

    if (nonFriendIds.isEmpty) {
      return [];
    }

    debugPrint('친구 목록에 없는 멤버: ${nonFriendIds.length}명');
    return nonFriendIds;
  }

  /// 초대 생성 또는 업데이트
  Future<String> createOrUpdateInvite({
    required CategoryDataModel category,
    required String invitedUserId,
    required String inviterUserId,

    // 이 함수를 호출하는 쪽에서 친구가 아닌 멤버 IDs를 선별해서 전달
    // CategoryService.createCategory 또는 CategoryMemberService.addUserByUid에서 친구관계가 아닌 멤버 IDs를 선별해서 전달
    required List<String> blockedMateIds,
  }) async {
    final existingInvite = await _inviteRepository.getPendingInviteForCategory(
      categoryId: category.id,
      invitedUserId: invitedUserId,
    );
    debugPrint("기존 친구가 아닌 멤버 확인: ${existingInvite?.blockedMateIds}");
    debugPrint("친구가 아닌 멤버 IDs: $blockedMateIds");

    if (existingInvite != null) {
      final updatedBlockedMates =
          {...existingInvite.blockedMateIds, ...blockedMateIds}.toList();

      await _inviteRepository.updateInvite(existingInvite.id, {
        'blockedMateIds': updatedBlockedMates,
        'status': CategoryInviteStatus.pending.name,
      });

      return existingInvite.id;
    }

    final now = DateTime.now();
    final invite = CategoryInviteModel(
      id: '',
      categoryId: category.id,
      invitedUserId: invitedUserId,
      inviterUserId: inviterUserId,
      status: CategoryInviteStatus.pending,

      // 기존 카테고리에 있는 친구가 아닌 멤버의 ID 목록을 전달
      // 새로 만드는 카테고리에 있는 친구가 아닌 멤버의 ID 목록을 전달
      blockedMateIds: blockedMateIds,
      createdAt: now,
      updatedAt: now,
    );

    return await _inviteRepository.createInvite(invite);
  }

  /// 초대 수락
  Future<AuthResult> acceptInvite({
    required String inviteId,
    required String userId,
  }) async {
    try {
      if (inviteId.isEmpty || userId.isEmpty) {
        return AuthResult.failure('유효하지 않은 초대입니다.');
      }

      final invite = await _inviteRepository.getInvite(inviteId);
      if (invite == null) {
        return AuthResult.failure('초대를 찾을 수 없습니다.');
      }

      if (invite.invitedUserId != userId) {
        return AuthResult.failure('이 초대를 수락할 수 없습니다.');
      }

      if (invite.status == CategoryInviteStatus.accepted) {
        return AuthResult.success(invite.categoryId);
      }

      if (invite.status == CategoryInviteStatus.declined || invite.isExpired) {
        return AuthResult.failure('만료되었거나 거절된 초대입니다.');
      }

      final category = await _repository.getCategory(invite.categoryId);
      if (category == null) {
        return AuthResult.failure('카테고리를 찾을 수 없습니다.');
      }

      // mates에 없으면 추가 (일반적으로는 이미 있어야 함)
      if (!category.mates.contains(userId)) {
        debugPrint('⚠️ mates에 없어서 추가: $userId');
        await _repository.addUidToCategory(
          categoryId: invite.categoryId,
          uid: userId,
        );
      }

      await _inviteRepository.updateInviteStatus(
        invite.id,
        CategoryInviteStatus.accepted,
        respondedAt: DateTime.now(),
      );

      await _inviteRepository.deleteInvite(invite.id);

      return AuthResult.success(invite.categoryId);
    } catch (e) {
      debugPrint('카테고리 초대 수락 실패: $e');
      return AuthResult.failure('초대 수락 중 오류가 발생했습니다.');
    }
  }

  /// 초대 거절
  Future<AuthResult> declineInvite({
    required String inviteId,
    required String userId,
  }) async {
    try {
      if (inviteId.isEmpty || userId.isEmpty) {
        return AuthResult.failure('유효하지 않은 초대입니다.');
      }

      final invite = await _inviteRepository.getInvite(inviteId);
      if (invite == null) {
        return AuthResult.failure('초대를 찾을 수 없습니다.');
      }

      if (invite.invitedUserId != userId) {
        return AuthResult.failure('이 초대를 거절할 수 없습니다.');
      }

      await _repository.removeUidFromCategory(
        categoryId: invite.categoryId,
        uid: userId,
      );

      await _inviteRepository.updateInviteStatus(
        invite.id,
        CategoryInviteStatus.declined,
        respondedAt: DateTime.now(),
      );

      await _inviteRepository.deleteInvite(invite.id);

      return AuthResult.success();
    } catch (e) {
      debugPrint('카테고리 초대 거절 실패: $e');
      return AuthResult.failure('초대 거절 중 오류가 발생했습니다.');
    }
  }

  /// pending 초대 확인
  Future<CategoryInviteModel?> getPendingInvite({
    required String categoryId,
    required String userId,
  }) async {
    return await _inviteRepository.getPendingInviteForCategory(
      categoryId: categoryId,
      invitedUserId: userId,
    );
  }
}
