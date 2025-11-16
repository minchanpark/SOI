import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/category_invite_model.dart';

/// categoryInvites 컬렉션 접근을 담당하는 Repository
class CategoryInviteRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'categoryInvites';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(_collectionPath);

  /// 초대 생성
  Future<String> createInvite(CategoryInviteModel invite) async {
    try {
      final docRef = await _collection.add(
        invite.toFirestoreWithServerTimestamps(),
      );
      return docRef.id;
    } catch (e) {
      debugPrint('❌ 카테고리 초대 생성 실패: $e');
      rethrow;
    }
  }

  /// 초대 조회
  Future<CategoryInviteModel?> getInvite(String inviteId) async {
    try {
      final doc = await _collection.doc(inviteId).get();
      if (!doc.exists || doc.data() == null) return null;
      return CategoryInviteModel.fromFirestore(doc.data()!, doc.id);
    } catch (e) {
      debugPrint('❌ 카테고리 초대 조회 실패 - ID: $inviteId, 오류: $e');
      rethrow;
    }
  }

  /// 사용자 기준 보류 초대 실시간 스트림
  Stream<List<CategoryInviteModel>> getPendingInvitesStream(
    String invitedUserId, {
    int limit = 50,
  }) {
    try {
      return _collection
          .where('invitedUserId', isEqualTo: invitedUserId)
          .where('status', isEqualTo: CategoryInviteStatus.pending.name)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs
                    .map(
                      (doc) =>
                          CategoryInviteModel.fromFirestore(doc.data(), doc.id),
                    )
                    .toList(),
          );
    } catch (e) {
      debugPrint('❌ 보류 초대 스트림 오류 - 사용자: $invitedUserId, 오류: $e');
      return Stream.error(e);
    }
  }

  /// 특정 카테고리와 사용자 조합의 보류 초대 조회
  Future<CategoryInviteModel?> getPendingInviteForCategory({
    required String categoryId,
    required String invitedUserId,
  }) async {
    try {
      final querySnapshot =
          await _collection
              .where('categoryId', isEqualTo: categoryId)
              .where('invitedUserId', isEqualTo: invitedUserId)
              .where('status', isEqualTo: CategoryInviteStatus.pending.name)
              .limit(1)
              .get();

      if (querySnapshot.docs.isEmpty) return null;
      final doc = querySnapshot.docs.first;
      return CategoryInviteModel.fromFirestore(doc.data(), doc.id);
    } catch (e) {
      debugPrint(
        '❌ 카테고리 초대 조회 실패 - 카테고리: $categoryId, 사용자: $invitedUserId, 오류: $e',
      );
      rethrow;
    }
  }

  /// 초대 상태/필드 업데이트
  Future<void> updateInvite(
    String inviteId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _collection.doc(inviteId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ 카테고리 초대 업데이트 실패 - ID: $inviteId, 오류: $e');
      rethrow;
    }
  }

  /// 초대 상태 갱신 헬퍼
  Future<void> updateInviteStatus(
    String inviteId,
    CategoryInviteStatus status, {
    DateTime? respondedAt,
  }) async {
    final data = {
      'status': status.name,
      'respondedAt':
          respondedAt != null
              ? Timestamp.fromDate(respondedAt)
              : FieldValue.serverTimestamp(),
    };
    await updateInvite(inviteId, data);
  }

  /// 초대 삭제
  Future<void> deleteInvite(String inviteId) async {
    try {
      await _collection.doc(inviteId).delete();
    } catch (e) {
      debugPrint('❌ 카테고리 초대 삭제 실패 - ID: $inviteId, 오류: $e');
      rethrow;
    }
  }

  /// 만료된 초대 정리
  Future<void> deleteExpiredInvites() async {
    try {
      final now = Timestamp.fromDate(DateTime.now());
      final querySnapshot =
          await _collection.where('expiresAt', isLessThanOrEqualTo: now).get();

      if (querySnapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('❌ 만료 초대 정리 실패: $e');
      rethrow;
    }
  }
}
