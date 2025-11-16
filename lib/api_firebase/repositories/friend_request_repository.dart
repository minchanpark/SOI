import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/friend_request_model.dart';
import '../services/notification_service.dart';

/// 친구 요청 Repository 클래스
/// Firestore의 friend_requests 컬렉션과 상호작용
class FriendRequestRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  /// friend_requests 컬렉션 참조
  CollectionReference<Map<String, dynamic>> get _friendRequestsCollection =>
      _firestore.collection('friend_requests');

  /// 현재 사용자 UID 가져오기
  String? get _currentUserUid => _auth.currentUser?.uid;

  /// 친구 요청 전송
  ///
  /// [receiverUid] 요청을 받을 사용자 UID
  /// [receiverNickname] 요청을 받을 사용자 닉네임
  /// [senderNickname] 요청을 보내는 사용자 닉네임
  /// [message] 선택적 메시지
  Future<String> sendFriendRequest({
    required String receiverUid,
    required String receiverId,
    required String senderid,
    String? senderProfileImageUrl,
    String? message,
  }) async {
    final currentUid = _currentUserUid;
    if (currentUid == null) {
      throw Exception('사용자가 로그인되어 있지 않습니다');
    }

    if (currentUid == receiverUid) {
      throw Exception('자기 자신에게 친구 요청을 보낼 수 없습니다');
    }

    try {
      // 중복 요청 확인
      final existingRequest =
          await _friendRequestsCollection
              .where('senderUid', isEqualTo: currentUid)
              .where('receiverUid', isEqualTo: receiverUid)
              .where('status', isEqualTo: 'pending')
              .get();

      if (existingRequest.docs.isNotEmpty) {
        throw Exception('이미 친구 요청을 보냈습니다');
      }

      // 새로운 친구 요청 생성
      final friendRequest = FriendRequestModel(
        id: '', // Firestore에서 자동 생성
        senderUid: currentUid,
        receiverUid: receiverUid,
        senderid: senderid,
        senderProfileImageUrl: senderProfileImageUrl,
        receiverid: receiverId,
        status: FriendRequestStatus.pending,
        message: message,
        createdAt: DateTime.now(),
      );

      // Firestore에 추가
      final docRef = await _friendRequestsCollection.add(
        friendRequest.toJson(),
      );

      // 친구 요청 알림 생성
      await _notificationService.createFriendRequestNotification(
        actorUserId: currentUid,
        recipientUserId: receiverUid,
      );

      return docRef.id;
    } catch (e) {
      throw Exception('친구 요청 전송 실패: $e');
    }
  }

  /// 받은 친구 요청 목록 조회 (실시간)
  Stream<List<FriendRequestModel>> getReceivedRequests() {
    final currentUid = _currentUserUid;
    if (currentUid == null) {
      return Stream.value([]);
    }

    return _friendRequestsCollection
        .where('receiverUid', isEqualTo: currentUid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return FriendRequestModel.fromFirestore(doc);
          }).toList();
        });
  }

  /// 보낸 친구 요청 목록 조회 (실시간)
  Stream<List<FriendRequestModel>> getSentRequests() {
    final currentUid = _currentUserUid;
    if (currentUid == null) {
      return Stream.value([]);
    }

    return _friendRequestsCollection
        .where('senderUid', isEqualTo: currentUid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return FriendRequestModel.fromFirestore(doc);
          }).toList();
        });
  }

  /// 친구 요청 수락
  ///
  /// [requestId] 친구 요청 문서 ID
  Future<void> acceptFriendRequest(String requestId) async {
    final currentUid = _currentUserUid;
    if (currentUid == null) {
      throw Exception('사용자가 로그인되어 있지 않습니다');
    }

    try {
      await _firestore.runTransaction((transaction) async {
        // 1. 친구 요청 문서 가져오기
        final requestDoc = await transaction.get(
          _friendRequestsCollection.doc(requestId),
        );

        if (!requestDoc.exists) {
          throw Exception('친구 요청을 찾을 수 없습니다');
        }

        final request = FriendRequestModel.fromFirestore(requestDoc);

        // 2. 권한 확인
        if (request.receiverUid != currentUid) {
          throw Exception('이 친구 요청을 수락할 권한이 없습니다');
        }

        if (request.status != FriendRequestStatus.pending) {
          throw Exception('이미 처리된 친구 요청입니다');
        }

        // 3. 친구 요청 상태 업데이트
        transaction.update(_friendRequestsCollection.doc(requestId), {
          'status': FriendRequestStatus.accepted.value,
          'updatedAt': Timestamp.now(),
        });

        // 4. 양방향 친구 관계 생성은 FriendRepository에서 처리
      });
    } catch (e) {
      throw Exception('친구 요청 수락 실패: $e');
    }
  }

  /// 친구 요청 거절
  ///
  /// [requestId] 친구 요청 문서 ID
  Future<void> rejectFriendRequest(String requestId) async {
    final currentUid = _currentUserUid;
    if (currentUid == null) {
      throw Exception('사용자가 로그인되어 있지 않습니다');
    }

    try {
      await _firestore.runTransaction((transaction) async {
        // 1. 친구 요청 문서 가져오기
        final requestDoc = await transaction.get(
          _friendRequestsCollection.doc(requestId),
        );

        if (!requestDoc.exists) {
          throw Exception('친구 요청을 찾을 수 없습니다');
        }

        final request = FriendRequestModel.fromFirestore(requestDoc);

        // 2. 권한 확인
        if (request.receiverUid != currentUid) {
          throw Exception('이 친구 요청을 거절할 권한이 없습니다');
        }

        if (request.status != FriendRequestStatus.pending) {
          throw Exception('이미 처리된 친구 요청입니다');
        }

        // 3. 친구 요청 상태 업데이트
        transaction.update(_friendRequestsCollection.doc(requestId), {
          'status': FriendRequestStatus.rejected.value,
          'updatedAt': Timestamp.now(),
        });
      });
    } catch (e) {
      throw Exception('친구 요청 거절 실패: $e');
    }
  }

  /// 친구 요청 취소 (보낸 요청)
  ///
  /// [requestId] 친구 요청 문서 ID
  Future<void> cancelFriendRequest(String requestId) async {
    final currentUid = _currentUserUid;
    if (currentUid == null) {
      throw Exception('사용자가 로그인되어 있지 않습니다');
    }

    try {
      await _firestore.runTransaction((transaction) async {
        // 1. 친구 요청 문서 가져오기
        final requestDoc = await transaction.get(
          _friendRequestsCollection.doc(requestId),
        );

        if (!requestDoc.exists) {
          throw Exception('친구 요청을 찾을 수 없습니다');
        }

        final request = FriendRequestModel.fromFirestore(requestDoc);

        // 2. 권한 확인
        if (request.senderUid != currentUid) {
          throw Exception('이 친구 요청을 취소할 권한이 없습니다');
        }

        if (request.status != FriendRequestStatus.pending) {
          throw Exception('이미 처리된 친구 요청입니다');
        }

        // 3. 친구 요청 삭제
        transaction.delete(_friendRequestsCollection.doc(requestId));
      });
    } catch (e) {
      throw Exception('친구 요청 취소 실패: $e');
    }
  }

  /// 특정 사용자와의 친구 요청 상태 확인
  ///
  /// [otherUserId] 확인할 사용자 UID
  /// Returns: 'none' | 'sent' | 'received' | 'friends'
  Future<String> getFriendRequestStatus(String otherUserId) async {
    final currentUid = _currentUserUid;
    if (currentUid == null) {
      return 'none';
    }

    try {
      // 보낸 요청 확인
      final sentRequest =
          await _friendRequestsCollection
              .where('senderUid', isEqualTo: currentUid)
              .where('receiverUid', isEqualTo: otherUserId)
              .where('status', isEqualTo: 'pending')
              .get();

      if (sentRequest.docs.isNotEmpty) {
        return 'sent';
      }

      // 받은 요청 확인
      final receivedRequest =
          await _friendRequestsCollection
              .where('senderUid', isEqualTo: otherUserId)
              .where('receiverUid', isEqualTo: currentUid)
              .where('status', isEqualTo: 'pending')
              .get();

      if (receivedRequest.docs.isNotEmpty) {
        return 'received';
      }

      return 'none';
    } catch (e) {
      throw Exception('친구 요청 상태 확인 실패: $e');
    }
  }

  /// 친구 요청 삭제 (완료된 요청 정리용)
  ///
  /// [requestId] 친구 요청 문서 ID
  Future<void> deleteFriendRequest(String requestId) async {
    try {
      await _friendRequestsCollection.doc(requestId).delete();
    } catch (e) {
      throw Exception('친구 요청 삭제 실패: $e');
    }
  }
}
