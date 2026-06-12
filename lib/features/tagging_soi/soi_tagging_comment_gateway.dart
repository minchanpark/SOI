import 'package:tagging_core/tagging_core.dart';

import '../../api/controller/comment_controller.dart';
import 'soi_tag_comment_mapper.dart';
import 'soi_tagging_ids.dart';

/// SOI CommentController cache/load 규약을 core의 overlay/thread query 포트로 변환합니다.
class SoiTaggingQueryPort implements TagQueryPort {
  const SoiTaggingQueryPort(this._commentController);

  final CommentController _commentController;

  @override
  void appendCreatedEntry({
    required TagScopeId scopeId,
    required TagEntry entry,
  }) {
    _commentController.appendCreatedComment(
      postId: SoiTaggingIds.postIdFromScopeId(scopeId),
      newComment: SoiTagCommentMapper.toComment(entry),
    );
  }

  @override
  void invalidateScope({
    required TagScopeId scopeId,
    bool overlay = true,
    bool thread = true,
  }) {
    _commentController.invalidatePostCaches(
      postId: SoiTaggingIds.postIdFromScopeId(scopeId),
      full: thread,
      parent: false,
      tag: overlay,
    );
  }

  @override
  Future<List<TagEntry>> loadEntries({
    required TagScopeId scopeId,
    required TagEntryLoadMode mode,
    bool forceReload = false,
  }) async {
    final postId = SoiTaggingIds.postIdFromScopeId(scopeId);
    final comments = switch (mode) {
      TagEntryLoadMode.overlay => await _commentController.getTagComments(
        postId: postId,
        forceReload: forceReload,
      ),
      TagEntryLoadMode.thread => await _commentController.getComments(
        postId: postId,
        forceReload: forceReload,
      ),
    };
    return SoiTagCommentMapper.fromComments(comments, scopeId: scopeId);
  }

  @override
  TagEntrySnapshot peekSnapshot({required TagScopeId scopeId}) {
    return TagEntrySnapshot(
      overlayEntries: peekEntries(
        scopeId: scopeId,
        mode: TagEntryLoadMode.overlay,
      ),
      threadEntries: peekEntries(
        scopeId: scopeId,
        mode: TagEntryLoadMode.thread,
      ),
    );
  }

  @override
  List<TagEntry>? peekEntries({
    required TagScopeId scopeId,
    required TagEntryLoadMode mode,
  }) {
    final postId = SoiTaggingIds.postIdFromScopeId(scopeId);
    final comments = switch (mode) {
      TagEntryLoadMode.overlay => _commentController.peekTagCommentsCache(
        postId: postId,
      ),
      TagEntryLoadMode.thread => _commentController.peekCommentsCache(
        postId: postId,
      ),
    };
    return comments == null
        ? null
        : SoiTagCommentMapper.fromComments(comments, scopeId: scopeId);
  }

  @override
  bool hasHydratedEntries({
    required TagScopeId scopeId,
    required TagEntryLoadMode mode,
  }) {
    final postId = SoiTaggingIds.postIdFromScopeId(scopeId);
    return switch (mode) {
      TagEntryLoadMode.overlay => _commentController.hasHydratedTagCommentsCache(
        postId: postId,
      ),
      TagEntryLoadMode.thread => _commentController.peekCommentsCache(
        postId: postId,
      ) !=
          null,
    };
  }

  @override
  void removeEntryFromCache({
    required TagScopeId scopeId,
    required TagEntityId entryId,
  }) {
    final numericCommentId = SoiTaggingIds.intFromEntityId(entryId);
    if (numericCommentId == null) {
      return;
    }
    _commentController.removeCommentFromCache(
      postId: SoiTaggingIds.postIdFromScopeId(scopeId),
      commentId: numericCommentId,
    );
  }

  @override
  void replaceEntries({
    required TagScopeId scopeId,
    required TagEntryLoadMode mode,
    required List<TagEntry> entries,
  }) {
    final comments = SoiTagCommentMapper.toComments(entries);
    final postId = SoiTaggingIds.postIdFromScopeId(scopeId);
    switch (mode) {
      case TagEntryLoadMode.overlay:
        _commentController.replaceTagCommentsCache(postId: postId, comments: comments);
      case TagEntryLoadMode.thread:
        _commentController.replaceCommentsCache(postId: postId, comments: comments);
    }
  }
}
