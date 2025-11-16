import 'package:flutter/material.dart';

import '../repositories/friend_repository.dart';
import '../repositories/user_search_repository.dart';
import '../models/friend_model.dart';
import '../models/friendship_relation.dart';

/// 친구 관리 Service 클래스
/// Repository들을 조합하여 친구 관련 고급 기능 제공
class FriendService {
  final FriendRepository _friendRepository;
  final UserSearchRepository _userSearchRepository;

  FriendService({
    required FriendRepository friendRepository,
    required UserSearchRepository userSearchRepository,
  }) : _friendRepository = friendRepository,
       _userSearchRepository = userSearchRepository;

  /// 카테고리 추가 가능 여부 확인 (비즈니스 로직 래퍼)
  Future<bool> canAddToCategory(String requesterId, String targetId) async {
    try {
      if (requesterId.isEmpty || targetId.isEmpty) {
        return false;
      }

      if (requesterId == targetId) {
        return false; // 자기 자신 추가 불가
      }

      return await _friendRepository.canAddToCategory(requesterId, targetId);
    } catch (e) {
      debugPrint('FriendService.canAddToCategory 에러: $e');
      return false;
    }
  }

  /// 카테고리 추가 불가 이유 반환
  Future<String?> getCannotAddReason(
    String requesterId,
    String targetId,
  ) async {
    try {
      if (requesterId == targetId) {
        return '자기 자신은 이미 카테고리 멤버입니다.';
      }

      return await _friendRepository.getCannotAddReason(requesterId, targetId);
    } catch (e) {
      return '확인 중 오류가 발생했습니다.';
    }
  }

  /// 친구 관계 상태 확인
  Future<FriendshipRelation> getFriendshipRelation(
    String currentUserId,
    String targetUserId,
  ) async {
    try {
      final myFriend = await _friendRepository.getFriend(targetUserId);
      final theirFriend = await _friendRepository.getTargetUserFriend(
        currentUserId,
        targetUserId,
      );

      // 내가 상대를 어떻게 보는지
      if (myFriend == null) {
        // 상대가 나를 어떻게 보는지
        if (theirFriend?.status == FriendStatus.blocked) {
          return FriendshipRelation.blockedByOther;
        }
        return FriendshipRelation.notFriends;
      }

      if (myFriend.status == FriendStatus.blocked) {
        return FriendshipRelation.blockedByMe;
      }

      if (theirFriend?.status == FriendStatus.blocked) {
        return FriendshipRelation.blockedByOther;
      }

      return FriendshipRelation.friends;
    } catch (e) {
      return FriendshipRelation.unknown;
    }
  }

  Future<bool> areUsersMutualFriends(String userA, String userB) async {
    if (userA.isEmpty || userB.isEmpty) return false;
    return _friendRepository.areUsersMutualFriends(userA, userB);
  }

  /// 여러 사용자와 기준 사용자 간의 친구 관계를 배치로 확인 (병렬 처리)
  Future<Map<String, bool>> areBatchMutualFriends(
    String baseUserId,
    List<String> targetUserIds,
  ) async {
    if (baseUserId.isEmpty || targetUserIds.isEmpty) {
      return {};
    }

    // 자기 자신 제거
    final filteredIds = targetUserIds.where((id) => id != baseUserId).toList();
    if (filteredIds.isEmpty) {
      return {};
    }

    return await _friendRepository.areBatchMutualFriends(
      baseUserId,
      filteredIds,
    );
  }

  /// 특정 사용자의 친구 ID 목록을 반환
  Future<Set<String>> getFriendIdsForUser(String userId) async {
    try {
      return await _friendRepository.getFriendIdsForUser(userId);
    } catch (e) {
      debugPrint('FriendService.getFriendIdsForUser 에러: $e');
      return {};
    }
  }

  /// 친구 목록 조회 (실시간)
  Stream<List<FriendModel>> getFriendsList() {
    return _friendRepository.getFriendsList();
  }

  /// 즐겨찾기 친구 목록 조회 (실시간)
  Stream<List<FriendModel>> getFavoriteFriendsList() {
    return _friendRepository.getFavoriteFriendsList();
  }

  /// 친구 삭제 (확인 절차 포함)
  Future<void> removeFriend(String friendUid) async {
    try {
      // 1. 친구 관계 확인
      final friend = await _friendRepository.getFriend(friendUid);
      if (friend == null) {
        throw Exception('친구 관계가 존재하지 않습니다');
      }

      if (friend.status == FriendStatus.blocked) {
        throw Exception('차단된 사용자입니다');
      }

      // 2. 친구 삭제 실행
      await _friendRepository.removeFriend(friendUid);
    } catch (e) {
      throw Exception('친구 삭제 실패: $e');
    }
  }

  /// 친구 차단
  Future<void> blockFriend(String friendUid) async {
    try {
      // 1. 친구 관계 확인
      final friend = await _friendRepository.getFriend(friendUid);
      if (friend == null) {
        throw Exception('친구 관계가 존재하지 않습니다');
      }

      if (friend.status == FriendStatus.blocked) {
        throw Exception('이미 차단된 사용자입니다');
      }

      // 2. 친구 차단 실행
      await _friendRepository.blockFriend(friendUid);
    } catch (e) {
      throw Exception('친구 차단 실패: $e');
    }
  }

  /// 친구 차단 해제
  Future<void> unblockFriend(String friendUid) async {
    try {
      // 1. 친구 관계 확인
      final friend = await _friendRepository.getFriend(friendUid);
      if (friend == null) {
        throw Exception('친구 관계가 존재하지 않습니다');
      }

      if (friend.status != FriendStatus.blocked) {
        throw Exception('차단된 사용자가 아닙니다');
      }

      // 2. 친구 차단 해제 실행
      await _friendRepository.unblockFriend(friendUid);
    } catch (e) {
      throw Exception('친구 차단 해제 실패: $e');
    }
  }

  /// 친구 즐겨찾기 토글
  Future<void> toggleFriendFavorite(String friendUid) async {
    try {
      // 1. 현재 즐겨찾기 상태 확인
      final friend = await _friendRepository.getFriend(friendUid);
      if (friend == null) {
        throw Exception('친구 관계가 존재하지 않습니다');
      }

      if (friend.status != FriendStatus.active) {
        throw Exception('활성 상태가 아닌 친구입니다');
      }

      // 2. 즐겨찾기 상태 토글
      await _friendRepository.setFriendFavorite(friendUid, !friend.isFavorite);
    } catch (e) {
      throw Exception('즐겨찾기 설정 실패: $e');
    }
  }

  /// 친구 검색 (고급)
  Future<List<FriendModel>> searchFriends(
    String query, {
    bool includeBlocked = false,
  }) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      final results = await _friendRepository.searchFriends(query);

      // 차단된 친구 필터링
      if (!includeBlocked) {
        return results
            .where((friend) => friend.status == FriendStatus.active)
            .toList();
      }

      return results;
    } catch (e) {
      throw Exception('친구 검색 실패: $e');
    }
  }

  /// 친구 정보 동기화 (프로필 변경사항 반영)
  Future<void> syncFriendInfo(String friendUid) async {
    try {
      // 1. 최신 사용자 정보 조회
      final userInfo = await _userSearchRepository.searchUserById(friendUid);
      if (userInfo == null) {
        throw Exception('사용자 정보를 찾을 수 없습니다');
      }

      // 2. 친구 정보 업데이트
      await _friendRepository.updateFriend(friendUid, {
        'nickname': userInfo.id,
        'name': userInfo.name,
        'profileImageUrl': userInfo.profileImageUrl,
      });
    } catch (e) {
      throw Exception('친구 정보 동기화 실패: $e');
    }
  }

  /// 모든 친구 정보 일괄 동기화
  Future<void> syncAllFriendsInfo() async {
    try {
      final friends = await _friendRepository.getFriendsList().first;

      for (final friend in friends) {
        try {
          await syncFriendInfo(friend.userId);

          // API 요청 제한을 피하기 위한 지연
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          // 개별 친구 동기화 실패는 무시하고 계속 진행
          debugPrint('친구 ${friend.id} 정보 동기화 실패: $e');
        }
      }
    } catch (e) {
      throw Exception('전체 친구 정보 동기화 실패: $e');
    }
  }

  /// 친구 활동 기록 업데이트
  Future<void> recordFriendInteraction(String friendUid) async {
    try {
      await _friendRepository.updateLastInteraction(friendUid);
    } catch (e) {
      // 상호작용 기록 실패는 중요하지 않으므로 로그만 출력
      debugPrint('친구 상호작용 기록 실패: $e');
    }
  }

  /// 친구 통계 정보
  Future<Map<String, dynamic>> getFriendStats() async {
    try {
      final totalFriends = await _friendRepository.getFriendsCount();
      final favoriteFriends =
          await _friendRepository.getFavoriteFriendsList().first;
      final allFriends = await _friendRepository.getFriendsList().first;

      final blockedFriends =
          allFriends
              .where((friend) => friend.status == FriendStatus.blocked)
              .length;

      final activeFriends = totalFriends - blockedFriends;

      // 최근 추가된 친구 (7일 이내)
      final recentlyAdded =
          allFriends.where((friend) {
            final daysDiff = DateTime.now().difference(friend.addedAt).inDays;
            return daysDiff <= 7;
          }).length;

      return {
        'total': totalFriends,
        'active': activeFriends,
        'blocked': blockedFriends,
        'favorite': favoriteFriends.length,
        'recentlyAdded': recentlyAdded,
      };
    } catch (e) {
      return {
        'total': 0,
        'active': 0,
        'blocked': 0,
        'favorite': 0,
        'recentlyAdded': 0,
      };
    }
  }

  /// 친구 그룹 분류
  Future<Map<String, List<FriendModel>>> getCategorizedFriends() async {
    try {
      final allFriends = await _friendRepository.getFriendsList().first;

      final Map<String, List<FriendModel>> categories = {
        'favorites': [],
        'recent': [],
        'frequent': [],
        'others': [],
      };

      final now = DateTime.now();

      for (final friend in allFriends) {
        if (friend.status != FriendStatus.active) continue;

        // 즐겨찾기
        if (friend.isFavorite) {
          categories['favorites']!.add(friend);
          continue;
        }

        // 최근 추가 (7일 이내)
        final daysSinceAdded = now.difference(friend.addedAt).inDays;
        if (daysSinceAdded <= 7) {
          categories['recent']!.add(friend);
          continue;
        }

        // 자주 상호작용 (30일 이내)
        if (friend.lastInteraction != null) {
          final daysSinceInteraction =
              now.difference(friend.lastInteraction!).inDays;
          if (daysSinceInteraction <= 30) {
            categories['frequent']!.add(friend);
            continue;
          }
        }

        // 기타
        categories['others']!.add(friend);
      }

      return categories;
    } catch (e) {
      return {'favorites': [], 'recent': [], 'frequent': [], 'others': []};
    }
  }

  /// 차단한 사용자 목록 조회
  Future<List<String>> getBlockedUsers() async {
    try {
      return await _friendRepository.getBlockedUsers();
    } catch (e) {
      throw Exception('차단 목록 조회 실패: $e');
    }
  }

  /// 특정 사용자가 나를 차단했는지 확인
  Future<bool> amIBlockedBy(String userId) async {
    try {
      return await _friendRepository.amIBlockedBy(userId);
    } catch (e) {
      throw Exception('차단 상태 확인 실패: $e');
    }
  }

  /// 나를 차단한 사용자 목록 조회
  Future<List<String>> getUsersWhoBlockedMe() async {
    try {
      return await _friendRepository.getUsersWhoBlockedMe();
    } catch (e) {
      throw Exception('차단한 사용자 목록 조회 실패: $e');
    }
  }
}
