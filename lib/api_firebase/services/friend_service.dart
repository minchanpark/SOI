import 'package:flutter/material.dart';

import '../repositories/friend_repository.dart';
import '../repositories/user_search_repository.dart';
import '../models/friend_model.dart';
import '../models/friendship_relation.dart';

/// 친구 관리 Service 클래스
/// Repository들을 조합하여 친구 관련 고급 기능 제공
class FriendService {
  final FriendRepository _friendRepository;

  FriendService({
    required FriendRepository friendRepository,
    required UserSearchRepository userSearchRepository,
  }) : _friendRepository = friendRepository;

  /// 친구 관계 상태 확인
  Future<FriendshipRelation> getFriendshipRelation(
    String currentUserId,
    String targetUserId,
  ) async {
    try {
      final myFriend = await _friendRepository.getFriend(targetUserId);

      // 내가 상대를 어떻게 보는지
      if (myFriend == null) {
        // 상대가 나를 어떻게 보는지

        return FriendshipRelation.notFriends;
      }

      if (myFriend.status == FriendStatus.blocked) {
        return FriendshipRelation.blockedByMe;
      }

      return FriendshipRelation.friends;
    } catch (e) {
      return FriendshipRelation.unknown;
    }
  }

  /// 여러 사용자와 기준 사용자 간의 친구 관계를 배치로 확인 (병렬 처리)
  Future<Map<String, bool>> areBatchMutualFriends(
    String baseUserId,
    List<String> targetUserIds,
  ) async {
    if (baseUserId.isEmpty || targetUserIds.isEmpty) {
      return {};
    }

    // 자기 자신 및 중복 제거 (LinkedHashSet 기반이라 입력 순서 유지)
    final sanitizedIds = {...targetUserIds}..remove(baseUserId);
    if (sanitizedIds.isEmpty) {
      return {};
    }

    return await _friendRepository.areBatchMutualFriends(
      baseUserId,
      sanitizedIds.toList(growable: false),
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

  /// 친구 통계 정보
  Future<Map<String, dynamic>> getFriendStats() async {
    try {
      final totalFriends = await _friendRepository.getFriendsCount();
      final favoriteFriends = await _friendRepository
          .getFavoriteFriendsList()
          .first;
      final allFriends = await _friendRepository.getFriendsList().first;

      final blockedFriends = allFriends
          .where((friend) => friend.status == FriendStatus.blocked)
          .length;

      final activeFriends = totalFriends - blockedFriends;

      // 최근 추가된 친구 (7일 이내)
      final recentlyAdded = allFriends.where((friend) {
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
          final daysSinceInteraction = now
              .difference(friend.lastInteraction!)
              .inDays;
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
}
