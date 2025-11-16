import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/emoji_reaction_model.dart';

/// EmojiReactionRepository
/// 사진의 리액션(이모지)을 Firestore에 저장/조회/삭제하는 데이터 접근 계층
/// 경로 구조:
/// categories/{categoryId}/photos/{photoId}/reactions/{userId}
/// 필드: emoji, name, createdAt, updatedAt
class EmojiReactionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _reactionCol({
    required String categoryId,
    required String photoId,
  }) {
    return _firestore
        .collection('categories')
        .doc(categoryId)
        .collection('photos')
        .doc(photoId)
        .collection('reactions');
  }

  /// 사용자 리액션 저장/업데이트 (upsert)
  /// userId: Firebase Auth UID
  /// userHandle: 사용자가 정의한 공개 ID (id)
  /// userName: 표시 이름 (name)
  Future<void> setReaction({
    required String categoryId,
    required String photoId,
    required String userId,
    required String userHandle,
    required String userName,
    required String profileImageUrl,
    required EmojiReactionModel reaction,
  }) async {
    final docRef = _reactionCol(
      categoryId: categoryId,
      photoId: photoId,
    ).doc(userId);
    await docRef.set({
      // 이모지 정보
      'emoji': reaction.emoji,
      'emojiName': reaction.name,
      // 사용자 메타데이터
      'uid': userId,
      'id': userHandle,
      'name': userName,
      'profileImageUrl': profileImageUrl,
      // 타임스탬프
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 사용자 리액션 삭제
  Future<void> removeReaction({
    required String categoryId,
    required String photoId,
    required String userId,
  }) async {
    final docRef = _reactionCol(
      categoryId: categoryId,
      photoId: photoId,
    ).doc(userId);
    await docRef.delete();
  }

  /// 현재 사용자의 리액션 한 건 조회
  Future<EmojiReactionModel?> getUserReaction({
    required String categoryId,
    required String photoId,
    required String userId,
  }) async {
    final doc =
        await _reactionCol(
          categoryId: categoryId,
          photoId: photoId,
        ).doc(userId).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return EmojiReactionModel(
      emoji: data['emoji'] ?? '',
      name: data['emojiName'] ?? data['name'] ?? '',
    );
  }

  /// 전체 리액션 카운트 (간단 합계) - 추후 UI 확장용
  Future<Map<String, int>> getReactionCounts({
    required String categoryId,
    required String photoId,
  }) async {
    final snap =
        await _reactionCol(categoryId: categoryId, photoId: photoId).get();
    final Map<String, int> counts = {};
    for (final d in snap.docs) {
      final data = d.data();
      final emoji = data['emoji'] as String? ?? '';
      if (emoji.isEmpty) continue;
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return counts;
  }

  /// 실시간 리액션 스트림 (UI 표시용)
  Stream<List<Map<String, dynamic>>> getReactionsStream({
    required String categoryId,
    required String photoId,
  }) {
    return _reactionCol(categoryId: categoryId, photoId: photoId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((d) {
                final data = d.data();
                data['uid'] = data['uid'] ?? d.id;
                return data;
              }).toList(),
        );
  }
}
