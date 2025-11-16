import 'package:soi/api_firebase/controllers/auth_controller.dart';
import '../repositories/friend_request_repository.dart';
import '../repositories/friend_repository.dart';
import '../repositories/user_search_repository.dart';
import '../models/friend_request_model.dart';
import '../models/user_search_model.dart';

/// 친구 요청 Service 클래스
/// Repository들을 조합하여 친구 요청 관련 비즈니스 로직 처리
class FriendRequestService {
  final FriendRequestRepository _friendRequestRepository;
  final FriendRepository _friendRepository;
  final UserSearchRepository _userSearchRepository;
  final AuthController _authController = AuthController();

  FriendRequestService({
    required FriendRequestRepository friendRequestRepository,
    required FriendRepository friendRepository,
    required UserSearchRepository userSearchRepository,
  }) : _friendRequestRepository = friendRequestRepository,
       _friendRepository = friendRepository,
       _userSearchRepository = userSearchRepository;

  /// 친구 요청 전송 (전체 검증 포함)
  ///
  /// [receiverUid] 요청을 받을 사용자 UID
  /// [message] 선택적 메시지
  Future<String> sendFriendRequest({
    required String receiverUid,
    String? message,
  }) async {
    try {
      // 1. 상대방 사용자 정보 조회
      final receiverInfo = await _userSearchRepository.searchUserById(
        receiverUid,
      );
      if (receiverInfo == null) {
        throw Exception('존재하지 않는 사용자입니다');
      }

      // 2. 이미 친구인지 확인
      final isAlreadyFriend = await _friendRepository.isFriend(receiverUid);
      if (isAlreadyFriend) {
        throw Exception('이미 친구입니다');
      }

      // 3. 기존 요청 상태 확인
      final requestStatus = await _friendRequestRepository
          .getFriendRequestStatus(receiverUid);
      if (requestStatus == 'sent') {
        throw Exception('이미 친구 요청을 보냈습니다');
      }
      if (requestStatus == 'received') {
        throw Exception('상대방이 이미 친구 요청을 보냈습니다. 받은 요청을 확인해주세요');
      }

      // 4. 현재 사용자 정보 조회 (닉네임 가져오기 위해)
      // AuthController에서 현재 사용자 정보 가져오기

      // 현재 사용자가 로그인되어 있는지 확인
      if (_authController.currentUser == null) {
        throw Exception('로그인이 필요합니다. 다시 로그인해주세요.');
      }

      final currentUser = _authController.currentUser!;
      final currentUserId = await _authController.getUserID();
      final currentUserProfileImageUrl = await _authController
          .getUserProfileImageUrl();
      // 빈 문자열이면 null 처리 (Firestore 저장/표시 시 오류 방지)
      final sanitizedProfileImageUrl =
          (currentUserProfileImageUrl.isNotEmpty &&
              (currentUserProfileImageUrl.startsWith('http://') ||
                  currentUserProfileImageUrl.startsWith('https://')))
          ? currentUserProfileImageUrl
          : null;

      // displayName이 null인 경우 기본값 사용
      final displayName = currentUser.displayName ?? '사용자';

      final currentUserInfo = UserSearchModel(
        uid: currentUser.uid,
        id: currentUserId,
        name: displayName,
        allowPhoneSearch: true, // 기본값 설정
        createdAt: DateTime.now(), // 현재 시간으로 설정
      );

      // 5. 친구 요청 전송
      final requestId = await _friendRequestRepository.sendFriendRequest(
        receiverUid: receiverUid,
        receiverId: receiverInfo.id,
        senderid: currentUserInfo.id,
        senderProfileImageUrl: sanitizedProfileImageUrl,
        message: message,
      );

      return requestId;
    } catch (e) {
      throw Exception('친구 요청 전송 실패: $e');
    }
  }

  /// 친구 요청 수락 (완전한 친구 관계 설정)
  ///
  /// [requestId] 친구 요청 ID
  Future<void> acceptFriendRequest(String requestId) async {
    try {
      // 1. 친구 요청 정보 가져오기
      final requests = await _friendRequestRepository
          .getReceivedRequests()
          .first;
      final request = requests.firstWhere(
        (req) => req.id == requestId,
        orElse: () => throw Exception('친구 요청을 찾을 수 없습니다'),
      );

      // 2. 현재 사용자 정보 가져오기 (실제 사용자 정보)
      if (_authController.currentUser == null) {
        throw Exception('로그인이 필요합니다. 다시 로그인해주세요.');
      }

      final currentUser = _authController.currentUser!;
      final currentUserId = await _authController.getUserID();
      final currentUserName = currentUser.displayName ?? currentUserId;
      final currentProfileImageUrl = await _authController
          .getUserProfileImageUrl();

      // 발신자(친구) 프로필 이미지 URL도 조회 (수락 후 상대 기기에서 현재 사용자 이미지 표시, 내 기기에서 친구 이미지 표시)
      final senderProfileImageUrl = await _authController
          .getUserProfileImageUrlById(request.senderUid);
      final sanitizedSenderProfileImageUrl =
          senderProfileImageUrl.isNotEmpty &&
              (senderProfileImageUrl.startsWith('http://') ||
                  senderProfileImageUrl.startsWith('https://'))
          ? senderProfileImageUrl
          : null;
      final sanitizedCurrentProfileImageUrl =
          currentProfileImageUrl.isNotEmpty &&
              (currentProfileImageUrl.startsWith('http://') ||
                  currentProfileImageUrl.startsWith('https://'))
          ? currentProfileImageUrl
          : null;

      // 3. 요청 발신자 정보 가져오기
      final senderInfo = await _userSearchRepository.searchUserById(
        request.senderUid,
      );
      final senderName = senderInfo?.name ?? request.senderid;

      // 4. 친구 요청 수락 처리
      await _friendRequestRepository.acceptFriendRequest(requestId);

      // 5. 양방향 친구 관계 생성
      await _friendRepository.addFriend(
        friendUid: request.senderUid,
        friendid: request.senderid,
        friendName: senderName, // 실제 발신자 이름 사용
        currentUserid: currentUserId,
        currentUserName: currentUserName, // 실제 현재 사용자 이름 사용
        friendProfileImageUrl: sanitizedSenderProfileImageUrl,
        currentUserProfileImageUrl: sanitizedCurrentProfileImageUrl,
      );

      // 6. 처리 완료된 친구 요청 삭제 (선택적)
      await _friendRequestRepository.deleteFriendRequest(requestId);
    } catch (e) {
      throw Exception('친구 요청 수락 실패: $e');
    }
  }

  /// 친구 요청 거절
  ///
  /// [requestId] 친구 요청 ID
  Future<void> rejectFriendRequest(String requestId) async {
    try {
      await _friendRequestRepository.rejectFriendRequest(requestId);

      // 거절된 요청은 일정 시간 후 자동 삭제하거나 바로 삭제
      await _friendRequestRepository.deleteFriendRequest(requestId);
    } catch (e) {
      throw Exception('친구 요청 거절 실패: $e');
    }
  }

  /// 친구 요청 취소
  ///
  /// [requestId] 친구 요청 ID
  Future<void> cancelFriendRequest(String requestId) async {
    try {
      await _friendRequestRepository.cancelFriendRequest(requestId);
    } catch (e) {
      throw Exception('친구 요청 취소 실패: $e');
    }
  }

  /// 받은 친구 요청 목록 조회
  Stream<List<FriendRequestModel>> getReceivedRequests() {
    return _friendRequestRepository.getReceivedRequests();
  }

  /// 보낸 친구 요청 목록 조회
  Stream<List<FriendRequestModel>> getSentRequests() {
    return _friendRequestRepository.getSentRequests();
  }

  /// 특정 사용자와의 친구 요청 상태 확인
  ///
  /// [userId] 확인할 사용자 ID
  /// Returns: 'none' | 'sent' | 'received' | 'friends'
  Future<String> getFriendshipStatus(String userId) async {
    try {
      // 1. 이미 친구인지 확인
      final isFriend = await _friendRepository.isFriend(userId);
      if (isFriend) {
        return 'friends';
      }

      // 2. 친구 요청 상태 확인
      final requestStatus = await _friendRequestRepository
          .getFriendRequestStatus(userId);
      return requestStatus;
    } catch (e) {
      return 'none';
    }
  }

  /// 대량 사용자들과의 친구 관계 상태 확인
  ///
  /// [userIds] 확인할 사용자 ID 목록
  /// Returns: Map<userId, status>
  Future<Map<String, String>> getBatchFriendshipStatus(
    List<String> userIds,
  ) async {
    final Map<String, String> statusMap = {};

    for (final userId in userIds) {
      try {
        final status = await getFriendshipStatus(userId);
        statusMap[userId] = status;
      } catch (e) {
        statusMap[userId] = 'none';
      }
    }

    return statusMap;
  }

  /// 친구 요청 통계 정보
  ///
  /// Returns: Map with 'received', 'sent' counts
  Future<Map<String, int>> getFriendRequestStats() async {
    try {
      final receivedRequests = await _friendRequestRepository
          .getReceivedRequests()
          .first;
      final sentRequests = await _friendRequestRepository
          .getSentRequests()
          .first;

      return {'received': receivedRequests.length, 'sent': sentRequests.length};
    } catch (e) {
      return {'received': 0, 'sent': 0};
    }
  }
}
