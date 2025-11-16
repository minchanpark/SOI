import '../models/emoji_reaction_model.dart';
import '../repositories/emoji_reaction_repository.dart';

/// EmojiReactionService
/// 비즈니스 로직 (중복 저장 방지나 향후 집계/트랜잭션 확장을 위한 계층)
class EmojiReactionService {
  final EmojiReactionRepository _repository = EmojiReactionRepository();

  Future<void> setReaction({
    required String categoryId,
    required String photoId,
    required String userId,
    required String userHandle,
    required String userName,
    required String profileImageUrl,
    required EmojiReactionModel reaction,
  }) async {
    await _repository.setReaction(
      categoryId: categoryId,
      photoId: photoId,
      userId: userId,
      userHandle: userHandle,
      userName: userName,
      profileImageUrl: profileImageUrl,
      reaction: reaction,
    );
  }

  Stream<List<Map<String, dynamic>>> getReactionsStream({
    required String categoryId,
    required String photoId,
  }) =>
      _repository.getReactionsStream(categoryId: categoryId, photoId: photoId);

  Future<void> removeReaction({
    required String categoryId,
    required String photoId,
    required String userId,
  }) async {
    await _repository.removeReaction(
      categoryId: categoryId,
      photoId: photoId,
      userId: userId,
    );
  }

  Future<EmojiReactionModel?> getUserReaction({
    required String categoryId,
    required String photoId,
    required String userId,
  }) async {
    return _repository.getUserReaction(
      categoryId: categoryId,
      photoId: photoId,
      userId: userId,
    );
  }
}
