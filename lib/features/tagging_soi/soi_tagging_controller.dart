import 'package:flutter/foundation.dart';
import 'package:tagging_core/tagging_core.dart';

import '../../api/controller/comment_controller.dart';
import 'soi_tag_comment_mapper.dart';
import 'soi_tag_entry_extensions.dart';
import 'soi_tagging_metadata.dart';

/// SOI 화면이 core 세션과 SOI 댓글 캐시 정책을 한 객체로 다루도록 감싸는 어댑터입니다.
class SoiTaggingController extends ChangeNotifier {
  SoiTaggingController({
    required TaggingSessionController coreController,
    required CommentController commentController,
  }) : _coreController = coreController,
       _commentController = commentController {
    _coreListener = notifyListeners;
    _coreController.addListener(_coreListener);
  }

  final TaggingSessionController _coreController;
  final CommentController _commentController;
  late final VoidCallback _coreListener;
  final Map<TagScopeId, String?> _selectedEmojisByScopeId =
      <TagScopeId, String?>{};

  Map<TagScopeId, String?> get selectedEmojisByScopeId =>
      _selectedEmojisByScopeId;

  Map<TagScopeId, TagDraft> get pendingDrafts => _coreController.pendingDrafts;

  Map<TagScopeId, TagPendingMarker> get pendingMarkers =>
      _coreController.pendingMarkers;

  List<TagEntry> peekTagComments(TagScopeId scopeId) =>
      _coreController.peekOverlayEntries(scopeId);

  void setSelectedEmoji(TagScopeId scopeId, String? emoji) {
    _selectedEmojisByScopeId[scopeId] = emoji;
    notifyListeners();
  }

  TagSaveRequest? buildSaveRequest(TagScopeId scopeId) =>
      _coreController.buildSaveRequest(scopeId);

  void stageTextDraft({
    required TagScopeId scopeId,
    required String text,
    required TagAuthor author,
    TagEntityId? parentId,
    TagEntityId? replyUserId,
  }) {
    _stageDraft(
      scopeId: scopeId,
      content: TagContent.text(text.trim()),
      author: author,
      parentId: parentId,
      replyUserId: replyUserId,
    );
  }

  void stageAudioDraft({
    required TagScopeId scopeId,
    required String audioPath,
    required List<double> waveformData,
    required int durationMs,
    required TagAuthor author,
    TagEntityId? parentId,
    TagEntityId? replyUserId,
  }) {
    _stageDraft(
      scopeId: scopeId,
      content: TagContent.audio(
        reference: audioPath.trim(),
        waveformSamples: List<double>.from(waveformData),
        durationMs: durationMs,
      ),
      author: author,
      parentId: parentId,
      replyUserId: replyUserId,
    );
  }

  void stageMediaDraft({
    required TagScopeId scopeId,
    required String localFilePath,
    required bool isVideo,
    required TagAuthor author,
    TagEntityId? parentId,
    TagEntityId? replyUserId,
  }) {
    _stageDraft(
      scopeId: scopeId,
      content: isVideo
          ? TagContent.video(reference: localFilePath.trim())
          : TagContent.image(reference: localFilePath.trim()),
      author: author,
      parentId: parentId,
      replyUserId: replyUserId,
    );
  }

  void _stageDraft({
    required TagScopeId scopeId,
    required TagContent content,
    required TagAuthor author,
    TagEntityId? parentId,
    TagEntityId? replyUserId,
  }) {
    _coreController.stageDraft(
      scopeId: scopeId,
      draft: TagDraft(
        actorId: author.id,
        content: content,
        parentEntryId: parentId,
        metadata: <String, Object?>{
          SoiTaggingMetadata.handle: author.handle,
          SoiTaggingMetadata.profileImageSource: author.profileImageSource,
          SoiTaggingMetadata.replyUserId: replyUserId,
        },
      ),
    );
    notifyListeners();
  }

  void updatePendingMarkerFromAbsolutePosition({
    required TagScopeId scopeId,
    required TagPosition absolutePosition,
    required TagViewportSize viewportSize,
  }) {
    _coreController.updatePendingMarkerFromAbsolutePosition(
      scopeId: scopeId,
      absolutePosition: absolutePosition,
      viewportSize: viewportSize,
    );
  }

  void updatePendingProgress(TagScopeId scopeId, double progress) {
    _coreController.updatePendingProgress(scopeId, progress);
  }

  void handleCommentSaveSuccess(TagScopeId scopeId, TagEntry comment) {
    _commentController.appendCreatedComment(
      postId: _postId(scopeId),
      newComment: SoiTagCommentMapper.toComment(comment),
    );
    _coreController.handleSaveSuccess(scopeId, comment);
  }

  void handleCommentSaveFailure(TagScopeId scopeId) {
    _coreController.handleSaveFailure(scopeId);
  }

  void removeCommentFromCache({
    required TagScopeId scopeId,
    required TagEntityId commentId,
  }) {
    _coreController.removeEntryFromCache(scopeId: scopeId, entryId: commentId);
  }

  void replaceCommentsCache(TagScopeId scopeId, List<TagEntry> comments) {
    _commentController.replaceCommentsCache(
      postId: _postId(scopeId),
      comments: SoiTagCommentMapper.toComments(comments),
    );
    _coreController.replaceThreadEntries(scopeId, comments);
    _coreController.replaceOverlayEntries(
      scopeId,
      comments.where((comment) => comment.hasLocation).toList(growable: false),
    );
  }

  Future<void> loadParentCommentsForScopes(
    List<TagScopeId> scopeIds, {
    bool forceReload = false,
  }) async {
    await Future.wait<void>(
      scopeIds.map(
        (scopeId) => loadParentCommentsForScope(
          scopeId,
          forceReload: forceReload,
        ),
      ),
    );
  }

  Future<List<TagEntry>> loadParentCommentsForScope(
    TagScopeId scopeId, {
    bool forceReload = false,
  }) async {
    final comments = await _commentController.getAllParentComments(
      postId: _postId(scopeId),
      forceReload: forceReload,
    );
    final entries = SoiTagCommentMapper.fromComments(comments, scopeId: scopeId);
    _coreController.replaceOverlayEntries(
      scopeId,
      entries.where((entry) => entry.hasLocation).toList(growable: false),
    );
    return entries;
  }

  Future<List<TagEntry>> loadCommentsForScope(
    TagScopeId scopeId, {
    bool forceReload = false,
  }) async {
    return _coreController.loadThreadEntriesForScope(
      scopeId,
      forceReload: forceReload,
    );
  }

  void clearScopeState(TagScopeId scopeId) {
    _selectedEmojisByScopeId.remove(scopeId);
    _coreController.clearScopeState(scopeId);
  }

  int _postId(TagScopeId scopeId) => int.parse(scopeId.split(':').last);

  @override
  void dispose() {
    _coreController.removeListener(_coreListener);
    _coreController.dispose();
    super.dispose();
  }
}
