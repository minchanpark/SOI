import 'package:flutter/foundation.dart';
import '../models/emoji_reaction_model.dart';
import '../services/emoji_reaction_service.dart';

/// 내부에서 사용할 Optimistic 상태 객체
class _ReactionKey {
  final String photoId;
  const _ReactionKey(this.photoId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ReactionKey && photoId == other.photoId;
  @override
  int get hashCode => photoId.hashCode;
}

/// 이모티콘 반응 상태를 관리하는 컨트롤러
class EmojiReactionController extends ChangeNotifier {
  final EmojiReactionService _service = EmojiReactionService();

  // 사진별 이모티콘 반응 저장 (photoId -> 선택된 이모티콘)
  final Map<String, EmojiReactionModel?> _photoReactions = {};
  // 진행 중 비동기 작업 추적 (중복 클릭 방지)
  final Set<_ReactionKey> _pending = {};

  /// 특정 사진의 선택된 이모티콘 반응 가져오기
  EmojiReactionModel? getPhotoReaction(String photoId) {
    return _photoReactions[photoId];
  }

  /// 특정 사진에 이모티콘 반응 설정
  Future<void> setPhotoReaction({
    required String categoryId,
    required String photoId,
    required String userId,
    required String userHandle,
    required String userName,
    required String profileImageUrl,
    required EmojiReactionModel reaction,
  }) async {
    final key = _ReactionKey(photoId);
    if (_pending.contains(key)) return; // 중복 방지
    if (_photoReactions[photoId] == reaction) return; // 변경 없음

    _pending.add(key);
    final previous = _photoReactions[photoId];
    _photoReactions[photoId] = reaction; // Optimistic 업데이트
    notifyListeners();

    try {
      await _service.setReaction(
        categoryId: categoryId,
        photoId: photoId,
        userId: userId,
        userHandle: userHandle,
        userName: userName,
        profileImageUrl: profileImageUrl,
        reaction: reaction,
      );
    } catch (e) {
      // 실패 시 롤백
      _photoReactions[photoId] = previous;
      notifyListeners();
      if (kDebugMode) {
        print('Error saving reaction: $e');
      }
    } finally {
      _pending.remove(key);
    }
  }

  Stream<List<Map<String, dynamic>>> reactionsStream({
    required String categoryId,
    required String photoId,
  }) => _service.getReactionsStream(categoryId: categoryId, photoId: photoId);

  /// 특정 사진의 이모티콘 반응 제거
  Future<void> removePhotoReaction({
    required String categoryId,
    required String photoId,
    required String userId,
  }) async {
    final key = _ReactionKey(photoId);
    if (_pending.contains(key)) return;
    if (!_photoReactions.containsKey(photoId)) return;
    final previous = _photoReactions[photoId];
    _pending.add(key);
    _photoReactions.remove(photoId); // Optimistic 제거
    notifyListeners();
    try {
      await _service.removeReaction(
        categoryId: categoryId,
        photoId: photoId,
        userId: userId,
      );
    } catch (e) {
      // 롤백
      _photoReactions[photoId] = previous;
      notifyListeners();
      if (kDebugMode) {
        print('Error removing reaction: $e');
      }
    } finally {
      _pending.remove(key);
    }
  }

  /// 특정 사진에 이모티콘 반응이 있는지 확인
  bool hasReaction(String photoId) {
    return _photoReactions[photoId] != null;
  }

  /// 모든 반응 데이터 초기화 (로그아웃 시 등)
  void clearAllReactions() {
    _photoReactions.clear();
    notifyListeners();
  }

  /// 서버에 반응 저장 (향후 Firebase 연동)
  Future<void> loadUserReactionForPhoto({
    required String categoryId,
    required String photoId,
    required String userId,
  }) async {
    try {
      final existing = await _service.getUserReaction(
        categoryId: categoryId,
        photoId: photoId,
        userId: userId,
      );
      if (existing != null) {
        _photoReactions[photoId] = existing;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load reaction for $photoId: $e');
      }
    }
  }

  /// 서버에서 반응 제거 (향후 Firebase 연동)
  // (옵션) 여러 사진 동시 로딩용 확장 가능
}
