import 'package:flutter/material.dart';
import 'package:flutter_contacts/contact.dart';
import '../repositories/user_search_repository.dart';
import '../repositories/friend_repository.dart';
import '../repositories/friend_request_repository.dart';
import '../models/user_search_model.dart';

/// 연락처-사용자 매칭 Service 클래스
/// 연락처 정보를 Firebase 사용자와 매칭하고 친구 추천 기능 제공
class UserMatchingService {
  final UserSearchRepository _userSearchRepository;
  final FriendRepository _friendRepository;
  final FriendRequestRepository _friendRequestRepository;

  UserMatchingService({
    required UserSearchRepository userSearchRepository,
    required FriendRepository friendRepository,
    required FriendRequestRepository friendRequestRepository,
  }) : _userSearchRepository = userSearchRepository,
       _friendRepository = friendRepository,
       _friendRequestRepository = friendRequestRepository;

  /// 연락처를 Firebase 사용자와 매칭
  ///
  /// [contacts] 매칭할 연락처 목록
  Future<List<ContactMatchResult>> matchContactsWithUsers(
    List<Contact> contacts,
  ) async {
    try {
      // 1. 연락처에서 전화번호 추출
      final phoneNumbers = <String>[];
      final contactPhoneMap = <String, Contact>{};

      for (final contact in contacts) {
        for (final phone in contact.phones) {
          if (phone.number.isNotEmpty) {
            final cleanNumber = _cleanPhoneNumber(phone.number);
            phoneNumbers.add(cleanNumber);
            contactPhoneMap[cleanNumber] = contact;
          }
        }
      }

      if (phoneNumbers.isEmpty) {
        return [];
      }

      // 2. 전화번호로 Firebase 사용자 검색
      final foundUsers = await _userSearchRepository.searchUsersByPhoneNumbers(
        phoneNumbers,
      );

      // 3. 이미 친구인 사용자들 필터링
      final friendUserIds = await _getFriendUserIds();
      final filteredUsers =
          foundUsers.where((user) {
            return !friendUserIds.contains(user.uid);
          }).toList();

      // 4. 이미 요청을 보낸 사용자들 필터링
      final requestedUserIds = await _getRequestedUserIds();
      final finalUsers =
          filteredUsers.where((user) {
            return !requestedUserIds.contains(user.uid);
          }).toList();

      // 5. 결과 매핑
      final results = <ContactMatchResult>[];
      for (final user in finalUsers) {
        // 해당 사용자와 연결된 연락처 찾기 (전화번호 기반)
        Contact? matchedContact;
        for (final contact in contacts) {
          for (final phone in contact.phones) {
            final cleanNumber = _cleanPhoneNumber(phone.number);
            // 실제로는 해시 비교를 해야 하지만, 여기서는 간단히 처리
            if (contactPhoneMap.containsKey(cleanNumber)) {
              matchedContact = contact;
              break;
            }
          }
          if (matchedContact != null) break;
        }

        if (matchedContact != null) {
          results.add(
            ContactMatchResult(
              contact: matchedContact,
              user: user,
              matchType: MatchType.phoneNumber,
            ),
          );
        }
      }

      return results;
    } catch (e) {
      throw Exception('연락처 매칭 실패: $e');
    }
  }

  /// 친구 추천 목록 생성
  ///
  /// [contacts] 연락처 목록
  /// [limit] 최대 추천 수
  Future<List<UserSearchModel>> getSuggestedFriends(
    List<Contact> contacts, {
    int limit = 20,
  }) async {
    try {
      final matchResults = await matchContactsWithUsers(contacts);

      // 우선순위에 따라 정렬
      matchResults.sort((a, b) {
        // 1. 이름이 있는 연락처 우선
        if (a.contact.displayName.isNotEmpty && b.contact.displayName.isEmpty) {
          return -1;
        }
        if (a.contact.displayName.isEmpty && b.contact.displayName.isNotEmpty) {
          return 1;
        }

        // 2. 사용자 생성일 순 (최근 가입자 우선)
        return b.user.createdAt.compareTo(a.user.createdAt);
      });

      return matchResults.take(limit).map((result) => result.user).toList();
    } catch (e) {
      throw Exception('친구 추천 생성 실패: $e');
    }
  }

  /// 특정 연락처와 매칭되는 사용자 찾기
  ///
  /// [contact] 검색할 연락처
  Future<UserSearchModel?> findUserForContact(Contact contact) async {
    try {
      for (final phone in contact.phones) {
        if (phone.number.isNotEmpty) {
          final user = await _userSearchRepository.searchUserByPhoneNumber(
            phone.number,
          );
          if (user != null) {
            return user;
          }
        }
      }
      debugPrint('매칭되는 사용자 없음');
      return null;
    } catch (e) {
      debugPrint('연락처 매칭 중 오류: $e');
      return null;
    }
  }

  /// 매칭 통계 정보
  ///
  /// [contacts] 분석할 연락처 목록
  Future<MatchingStats> getMatchingStats(List<Contact> contacts) async {
    try {
      final totalContacts = contacts.length;
      final matchResults = await matchContactsWithUsers(contacts);
      final matchedContacts = matchResults.length;

      final phoneContacts =
          contacts.where((contact) => contact.phones.isNotEmpty).length;
      final namedContacts =
          contacts.where((contact) => contact.displayName.isNotEmpty).length;

      return MatchingStats(
        totalContacts: totalContacts,
        contactsWithPhone: phoneContacts,
        contactsWithName: namedContacts,
        matchedUsers: matchedContacts,
        matchRate: totalContacts > 0 ? (matchedContacts / totalContacts) : 0.0,
      );
    } catch (e) {
      return MatchingStats(
        totalContacts: contacts.length,
        contactsWithPhone: 0,
        contactsWithName: 0,
        matchedUsers: 0,
        matchRate: 0.0,
      );
    }
  }

  /// 현재 사용자의 친구 UID 목록 조회
  Future<Set<String>> _getFriendUserIds() async {
    try {
      final friends = await _friendRepository.getFriendsList().first;
      return friends.map((friend) => friend.userId).toSet();
    } catch (e) {
      return {};
    }
  }

  /// 이미 요청을 보낸 사용자 UID 목록 조회
  Future<Set<String>> _getRequestedUserIds() async {
    try {
      final sentRequests =
          await _friendRequestRepository.getSentRequests().first;
      return sentRequests.map((request) => request.receiverUid).toSet();
    } catch (e) {
      return {};
    }
  }

  /// 전화번호 정리 (숫자만 추출)
  String _cleanPhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
  }

  /// 연락처 검색 상태 확인
  ///
  /// [contact] 확인할 연락처
  Future<ContactSearchStatus> getContactSearchStatus(Contact contact) async {
    try {
      final user = await findUserForContact(contact);
      if (user == null) {
        return ContactSearchStatus.notFound;
      }

      final isFriend = await _friendRepository.isFriend(user.uid);
      if (isFriend) {
        return ContactSearchStatus.alreadyFriend;
      }

      final requestStatus = await _friendRequestRepository
          .getFriendRequestStatus(user.uid);
      switch (requestStatus) {
        case 'sent':
          return ContactSearchStatus.requestSent;
        case 'received':
          return ContactSearchStatus.requestReceived;
        default:
          return ContactSearchStatus.canSendRequest;
      }
    } catch (e) {
      return ContactSearchStatus.error;
    }
  }

  /// ID로 사용자 검색
  ///
  /// [userId] 검색할 사용자 ID
  /// Returns: UserSearchModel 또는 null
  Future<List<UserSearchModel>> searchUserById(String userId) async {
    try {
      // debugPrint('UserMatchingService: ID로 사용자 검색 시작 - $userId');
      final result = await _userSearchRepository.searchUsersById(userId);
      // debugPrint('UserMatchingService: ID 검색 결과 - $result');
      return result;
    } catch (e) {
      // debugPrint('UserMatchingService: ID로 사용자 검색 실패 - $e');
      rethrow; // Controller에서 에러 처리하도록 전달
    }
  }
}

/// 연락처 매칭 결과
class ContactMatchResult {
  final Contact contact;
  final UserSearchModel user;
  final MatchType matchType;

  ContactMatchResult({
    required this.contact,
    required this.user,
    required this.matchType,
  });
}

/// 매칭 타입
enum MatchType { phoneNumber, email, name }

/// 매칭 통계
class MatchingStats {
  final int totalContacts;
  final int contactsWithPhone;
  final int contactsWithName;
  final int matchedUsers;
  final double matchRate;

  MatchingStats({
    required this.totalContacts,
    required this.contactsWithPhone,
    required this.contactsWithName,
    required this.matchedUsers,
    required this.matchRate,
  });
}

/// 연락처 검색 상태
enum ContactSearchStatus {
  notFound, // SOI 사용자 아님
  canSendRequest, // 친구 요청 가능
  requestSent, // 이미 요청 보냄
  requestReceived, // 상대방이 요청 보냄
  alreadyFriend, // 이미 친구
  error, // 오류 발생
}
