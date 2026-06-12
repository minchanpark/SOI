import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:tagging_core/tagging_core.dart';

import '../../../api/controller/comment_controller.dart';
import '../../../api/controller/media_controller.dart' as api_media;
import '../../../api/controller/user_controller.dart';
import '../../../api/models/comment.dart';
import '../../../api/models/comment_creation_result.dart';
import '../../../utils/position_converter.dart';
import '../../../api/media_processing/waveform_codec.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../features/tagging_soi/soi_tag_entry_extensions.dart';

/// 게시물별 음성/텍스트 댓글 상태를 관리하는 매니저 클래스
/// 피드 화면에서 각 게시물에 대해 음성/텍스트 댓글의 활성화 상태, 저장 상태, 대기 중인 댓글 정보 등을 관리하여,
/// UI와 상호작용할 수 있도록 합니다.
///
/// Parameters:
///   - [voiceCommentActiveStates]: 게시물 ID별 음성/텍스트 댓글 활성화 상태 맵
///   - [voiceCommentSavedStates]: 게시물 ID별 음성/텍스트 댓글 저장 상태 맵
///   - [pendingVoiceComments]: 게시물 ID별 대기 중인 음성/텍스트 댓글 맵
///   - [pendingTextComments]: 게시물 ID별 대기 중인 텍스트 댓글 상태 맵
///   - [autoPlacementIndices]: 게시물 ID별 자동 배치 인덱스 맵
///   - [onStateChanged]: 상태 변경 시 호출되는 콜백 함수
class VoiceCommentStateManager {
  static const int _kMaxWaveformSamples = 30;
  static final WaveformCodec _waveformCodec = WaveformCodec();
  final Map<int, bool> _voiceCommentActiveStates = {};
  final Map<int, bool> _voiceCommentSavedStates = {};
  final Map<int, TagDraft> _pendingCommentDrafts = {}; // 임시 댓글 초안 저장
  final Map<int, TagPendingMarker> _pendingCommentMarkers =
      {}; // UI 마커용 최소 데이터 저장
  final Map<int, bool> _pendingTextComments = {};
  final Map<int, int> _autoPlacementIndices = {};
  final Map<int, String?> _selectedEmojisByPostId = {}; // postId별 내가 선택한 이모지
  final Map<int, Future<List<Comment>>> _inFlightParentCommentLoads = {};
  final Map<int, Future<void>> _inFlightTagCommentLoads = {};
  final Map<int, Future<List<Comment>>> _inFlightFullCommentLoads = {};

  VoidCallback? _onStateChanged;

  Map<int, bool> get voiceCommentActiveStates => _voiceCommentActiveStates;
  Map<int, bool> get voiceCommentSavedStates => _voiceCommentSavedStates;
  Map<int, TagPendingMarker> get pendingVoiceComments => _pendingCommentMarkers;
  Map<int, TagDraft> get pendingCommentDrafts => _pendingCommentDrafts;
  Map<int, bool> get pendingTextComments => _pendingTextComments;
  Map<int, String?> get selectedEmojisByPostId => _selectedEmojisByPostId;

  void setOnStateChanged(VoidCallback? callback) {
    _onStateChanged = callback;
  }

  void _notifyStateChanged() {
    _onStateChanged?.call();
  }

  String? _emojiFromId(int? emojiId) {
    switch (emojiId) {
      case 0:
        return '😀';
      case 1:
        return '😍';
      case 2:
        return '😭';
      case 3:
        return '😡';
    }
    return null;
  }

  String? _selectedEmojiFromComments({
    required List<Comment> comments,
    required String currentUserNickname,
  }) {
    for (final comment in comments.reversed) {
      if (comment.emojiId == null || comment.emojiId == 0) continue;
      if (comment.nickname != currentUserNickname) continue;
      return _emojiFromId(comment.emojiId);
    }
    return null;
  }

  // 이모지 선택 시, 부모 상태(postId별 선택값)를 즉시 갱신하기 위한 메서드
  void setSelectedEmoji(int postId, String? emoji) {
    if (emoji == null) {
      _selectedEmojisByPostId.remove(postId); // 선택 해제 시 맵에서 제거
    } else {
      _selectedEmojisByPostId[postId] = emoji; // 선택된 이모지 저장
    }
    _notifyStateChanged(); // 상태 변경 알림
  }

  /// 태그 오버레이는 위치 댓글만 선로딩해 첫 표시 시간을 줄입니다.
  Future<void> loadTagCommentsForPost(
    int postId,
    BuildContext context, {
    bool forceReload = false,
  }) async {
    await loadTagCommentsForPosts([postId], context, forceReload: forceReload);
  }

  /// 여러 게시물의 원댓글 미리보기를 새로 받아 refresh 직후 보이는 카드 상태를 최신화합니다.
  Future<void> loadParentCommentsForPosts(
    List<int> postIds,
    BuildContext context, {
    bool forceReload = false,
  }) async {
    final commentController = context.read<CommentController>();
    final uniquePostIds = postIds
        .toSet()
        .where((postId) {
          final cached = commentController.peekParentCommentsCache(
            postId: postId,
          );
          return forceReload ||
              cached == null ||
              _needsProfileImageResolution(cached);
        })
        .toList(growable: false);
    if (uniquePostIds.isEmpty) {
      return;
    }

    await Future.wait(
      uniquePostIds.map(
        (postId) => _loadParentCommentsForPostInternal(
          postId,
          context,
          forceReload: forceReload,
        ),
      ),
    );
  }

  /// 단일 게시물의 원댓글 미리보기 refresh를 감싼 편의 메서드입니다.
  Future<void> loadParentCommentsForPost(
    int postId,
    BuildContext context, {
    bool forceReload = false,
  }) async {
    await loadParentCommentsForPosts(
      [postId],
      context,
      forceReload: forceReload,
    );
  }

  /// 여러 게시물의 태그 댓글을 post 단위로 병렬 로드하고, 완료 즉시 개별 반영합니다.
  Future<void> loadTagCommentsForPosts(
    List<int> postIds,
    BuildContext context, {
    bool forceReload = false,
  }) async {
    final commentController = context.read<CommentController>();
    final uniquePostIds = postIds
        .toSet()
        .where((postId) {
          final cached = commentController.peekTagCommentsCache(postId: postId);
          return forceReload ||
              cached == null ||
              _needsProfileImageResolution(cached);
        })
        .toList(growable: false);
    if (uniquePostIds.isEmpty) {
      return;
    }

    await Future.wait(
      uniquePostIds.map(
        (postId) => _loadTagCommentsForPostInternal(
          postId,
          context,
          forceReload: forceReload,
        ),
      ),
    );
  }

  /// 댓글 바텀시트는 전체 스레드를 캐시해 재오픈 시 네트워크를 줄입니다.
  Future<List<Comment>> loadCommentsForPost(
    int postId,
    BuildContext context, {
    bool forceReload = false,
  }) async {
    final commentController = context.read<CommentController>();
    if (!forceReload) {
      final cached = commentController.peekCommentsCache(postId: postId);
      if (cached != null) {
        final resolved = await _resolveAndStoreCommentsIfNeeded(
          postId: postId,
          comments: cached,
          context: context,
          tagOnly: false,
        );
        if (!context.mounted) {
          return resolved;
        }
        _syncCommentStateFromLoadedComments(postId, resolved, context);
        _notifyStateChanged();
        return resolved;
      }
      final inFlight = _inFlightFullCommentLoads[postId];
      if (inFlight != null) {
        return inFlight;
      }
    }

    final future = _loadFullCommentsForPostInternal(
      postId,
      context,
      forceReload: forceReload,
    );
    _inFlightFullCommentLoads[postId] = future;
    try {
      return await future;
    } finally {
      final registered = _inFlightFullCommentLoads[postId];
      if (identical(registered, future)) {
        _inFlightFullCommentLoads.remove(postId);
      }
    }
  }

  /// 기존 전체 댓글 로딩 호출은 full-thread cache warmup으로 유지합니다.
  Future<void> loadCommentsForPosts(
    List<int> postIds,
    BuildContext context, {
    bool forceReload = false,
  }) async {
    final uniquePostIds = postIds.toSet().toList(growable: false);
    if (uniquePostIds.isEmpty) {
      return;
    }

    await Future.wait(
      uniquePostIds.map(
        (postId) =>
            loadCommentsForPost(postId, context, forceReload: forceReload),
      ),
    );
  }

  /// 원댓글 미리보기는 reply를 제외한 부모 댓글만 다시 받아 태그와 시트 초기 상태를 함께 갱신합니다.
  Future<List<Comment>> _loadParentCommentsForPostInternal(
    int postId,
    BuildContext context, {
    required bool forceReload,
  }) async {
    if (!forceReload) {
      final inFlight = _inFlightParentCommentLoads[postId];
      if (inFlight != null) {
        return inFlight;
      }
    }

    final future = () async {
      try {
        final commentController = context.read<CommentController>();
        final mediaController = context.read<api_media.MediaController>();
        final comments = await commentController.getAllParentComments(
          postId: postId,
          forceReload: forceReload,
        );
        final resolvedComments = await _resolveCommentProfileImages(
          comments,
          mediaController,
        );

        if (!context.mounted) {
          return resolvedComments;
        }

        commentController.replaceParentCommentsCache(
          postId: postId,
          comments: resolvedComments,
        );
        _syncCommentStateFromLoadedComments(postId, resolvedComments, context);
        _notifyStateChanged();
        _prefetchProfileImages(
          context,
          _buildProfilePrefetchCandidates(resolvedComments),
        );
        return resolvedComments;
      } catch (e) {
        debugPrint('원댓글 로드 실패(postId: $postId): $e');
        return context.read<CommentController>().peekParentCommentsCache(
              postId: postId,
            ) ??
            const <Comment>[];
      }
    }();

    _inFlightParentCommentLoads[postId] = future;
    try {
      return await future;
    } finally {
      final registered = _inFlightParentCommentLoads[postId];
      if (identical(registered, future)) {
        _inFlightParentCommentLoads.remove(postId);
      }
    }
  }

  /// 태그 전용 로드는 위치 댓글만 post 단위로 반영해 느린 sibling post의 영향 범위를 줄입니다.
  Future<void> _loadTagCommentsForPostInternal(
    int postId,
    BuildContext context, {
    bool forceReload = false,
  }) async {
    if (!forceReload) {
      final inFlight = _inFlightTagCommentLoads[postId];
      if (inFlight != null) {
        return inFlight;
      }
    }

    final future = () async {
      try {
        final commentController = context.read<CommentController>();
        final mediaController = context.read<api_media.MediaController>();
        final cached = forceReload
            ? null
            : commentController.peekTagCommentsCache(postId: postId);
        final comments =
            cached ??
            await commentController.getTagComments(
              postId: postId,
              forceReload: forceReload,
            );
        final resolvedComments = await _resolveCommentProfileImages(
          comments,
          mediaController,
        );

        if (!context.mounted) return;
        commentController.replaceTagCommentsCache(
          postId: postId,
          comments: resolvedComments,
        );
        _voiceCommentSavedStates[postId] =
            resolvedComments.isNotEmpty ||
            ((commentController
                    .peekCommentsCache(postId: postId)
                    ?.isNotEmpty) ??
                false);
        _notifyStateChanged();
        _prefetchProfileImages(
          context,
          _buildProfilePrefetchCandidates(resolvedComments),
        );
      } catch (e) {
        debugPrint('태그 댓글 로드 실패(postId: $postId): $e');
      }
    }();

    _inFlightTagCommentLoads[postId] = future;
    try {
      await future;
    } finally {
      final registered = _inFlightTagCommentLoads[postId];
      if (identical(registered, future)) {
        _inFlightTagCommentLoads.remove(postId);
      }
    }
  }

  /// 전체 댓글 로드는 바텀시트와 저장/삭제 보정의 진실 소스로 사용합니다.
  Future<List<Comment>> _loadFullCommentsForPostInternal(
    int postId,
    BuildContext context, {
    required bool forceReload,
  }) async {
    try {
      final commentController = context.read<CommentController>();
      final mediaController = context.read<api_media.MediaController>();
      final comments = await commentController.getComments(
        postId: postId,
        forceReload: forceReload,
      );
      final resolvedComments = await _resolveCommentProfileImages(
        comments,
        mediaController,
      );

      if (!context.mounted) {
        return resolvedComments;
      }

      commentController.replaceCommentsCache(
        postId: postId,
        comments: resolvedComments,
      );
      _syncCommentStateFromLoadedComments(postId, resolvedComments, context);
      _notifyStateChanged();
      _prefetchProfileImages(
        context,
        _buildProfilePrefetchCandidates(resolvedComments),
      );
      return resolvedComments;
    } catch (e) {
      debugPrint('전체 댓글 로드 실패(postId: $postId): $e');
      return context.read<CommentController>().peekCommentsCache(
            postId: postId,
          ) ??
          const <Comment>[];
    }
  }

  Future<List<Comment>> _resolveCommentProfileImages(
    List<Comment> comments,
    api_media.MediaController mediaController,
  ) async {
    if (comments.isEmpty) {
      return comments;
    }

    final resolvedUrlsByKey = <String, String>{};
    final keysToResolve = <String>[];
    final seenKeys = <String>{};

    for (final comment in comments) {
      final profileKey = _extractCommentProfileKey(comment);
      if (profileKey == null) {
        continue;
      }

      final cachedUrl = mediaController.peekPresignedUrl(profileKey);
      if (cachedUrl != null && cachedUrl.isNotEmpty) {
        resolvedUrlsByKey[profileKey] = cachedUrl;
        continue;
      }

      if (seenKeys.add(profileKey)) {
        keysToResolve.add(profileKey);
      }
    }

    if (keysToResolve.isNotEmpty) {
      final resolvedUrls = await mediaController.getPresignedUrls(
        keysToResolve,
      );
      final upperBound = keysToResolve.length < resolvedUrls.length
          ? keysToResolve.length
          : resolvedUrls.length;
      for (var i = 0; i < upperBound; i++) {
        final resolvedUrl = resolvedUrls[i].trim();
        if (resolvedUrl.isEmpty) {
          continue;
        }
        resolvedUrlsByKey[keysToResolve[i]] = resolvedUrl;
      }
    }

    return comments
        .map((comment) {
          final profileKey = _extractCommentProfileKey(comment);
          if (profileKey == null) {
            return comment;
          }

          final originalUrl = (comment.userProfileUrl ?? '').trim();
          final resolvedUrl = resolvedUrlsByKey[profileKey];
          final nextUrl = (resolvedUrl != null && resolvedUrl.isNotEmpty)
              ? resolvedUrl
              : originalUrl;
          final originalKey = (comment.userProfileKey ?? '').trim();
          final nextKey = originalKey.isNotEmpty ? originalKey : profileKey;

          if (nextUrl == originalUrl && nextKey == originalKey) {
            return comment;
          }

          return comment.copyWith(
            userProfileUrl: nextUrl.isEmpty ? profileKey : nextUrl,
            userProfileKey: nextKey,
          );
        })
        .toList(growable: false);
  }

  String? _extractCommentProfileKey(Comment comment) {
    final profileKey = (comment.userProfileKey ?? '').trim();
    if (profileKey.isNotEmpty) {
      return profileKey;
    }

    final profileUrl = (comment.userProfileUrl ?? '').trim();
    if (profileUrl.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(profileUrl);
    if (uri != null && uri.hasScheme) {
      return null;
    }

    return profileUrl;
  }

  void _collectProfileImagePrefetchCandidates({
    required List<Comment> comments,
    required List<_ProfileImagePrefetchCandidate> prefetchCandidates,
    required Set<String> seenPrefetchKeys,
  }) {
    for (final comment in comments) {
      final imageUrl = (comment.userProfileUrl ?? '').trim();
      if (imageUrl.isEmpty) {
        continue;
      }

      final uri = Uri.tryParse(imageUrl);
      if (uri == null || !uri.hasScheme) {
        continue;
      }

      final cacheKey = _extractCommentProfileKey(comment);
      final dedupeKey = cacheKey ?? imageUrl;
      if (!seenPrefetchKeys.add(dedupeKey)) {
        continue;
      }

      prefetchCandidates.add(
        _ProfileImagePrefetchCandidate(imageUrl: imageUrl, cacheKey: cacheKey),
      );
    }
  }

  List<_ProfileImagePrefetchCandidate> _buildProfilePrefetchCandidates(
    List<Comment> comments,
  ) {
    final candidates = <_ProfileImagePrefetchCandidate>[];
    final seenPrefetchKeys = <String>{};
    _collectProfileImagePrefetchCandidates(
      comments: comments,
      prefetchCandidates: candidates,
      seenPrefetchKeys: seenPrefetchKeys,
    );
    return candidates;
  }

  /// presigned URL이 아직 풀리지 않은 댓글은 feed용 cache에 보정해 재사용합니다.
  bool _needsProfileImageResolution(List<Comment> comments) {
    for (final comment in comments) {
      final profileKey = _extractCommentProfileKey(comment);
      if (profileKey == null) {
        continue;
      }

      final profileUrl = (comment.userProfileUrl ?? '').trim();
      final uri = Uri.tryParse(profileUrl);
      if (profileUrl.isEmpty || uri == null || !uri.hasScheme) {
        return true;
      }
    }
    return false;
  }

  /// feed 화면은 controller cache도 presigned URL이 반영된 상태로 유지합니다.
  Future<List<Comment>> _resolveAndStoreCommentsIfNeeded({
    required int postId,
    required List<Comment> comments,
    required BuildContext context,
    required bool tagOnly,
  }) async {
    if (!_needsProfileImageResolution(comments)) {
      return comments;
    }

    final mediaController = context.read<api_media.MediaController>();
    final commentController = context.read<CommentController>();
    final resolvedComments = await _resolveCommentProfileImages(
      comments,
      mediaController,
    );

    if (!context.mounted) {
      return resolvedComments;
    }

    if (tagOnly) {
      commentController.replaceTagCommentsCache(
        postId: postId,
        comments: resolvedComments,
      );
      return commentController.peekTagCommentsCache(postId: postId) ??
          resolvedComments;
    }

    commentController.replaceCommentsCache(
      postId: postId,
      comments: resolvedComments,
    );
    return commentController.peekCommentsCache(postId: postId) ??
        resolvedComments;
  }

  /// 피드에 보이는 댓글 캐시가 갱신되면 저장 여부와 선택 이모지를 UI 상태에 동기화합니다.
  void _syncCommentStateFromLoadedComments(
    int postId,
    List<Comment> comments,
    BuildContext context,
  ) {
    final currentUserNickname = context
        .read<UserController>()
        .currentUser
        ?.userId;
    if (currentUserNickname != null) {
      final selected = _selectedEmojiFromComments(
        comments: comments,
        currentUserNickname: currentUserNickname,
      );
      if (selected != null) {
        _selectedEmojisByPostId[postId] = selected;
      }
    }

    _voiceCommentSavedStates[postId] = comments.isNotEmpty;
  }

  void _prefetchProfileImages(
    BuildContext context,
    List<_ProfileImagePrefetchCandidate> candidates,
  ) {
    if (!context.mounted || candidates.isEmpty) {
      return;
    }

    for (final candidate in candidates.take(12)) {
      unawaited(
        precacheImage(
          CachedNetworkImageProvider(
            candidate.imageUrl,
            cacheKey: candidate.cacheKey,
          ),
          context,
        ).catchError((_) {}),
      );
    }
  }

  /// 음성/텍스트 댓글 활성화 상태 토글 메서드
  void toggleVoiceComment(int postId) {
    final newValue = !(_voiceCommentActiveStates[postId] ?? false);
    _voiceCommentActiveStates[postId] = newValue;
    if (!newValue) {
      _clearPendingState(postId);
    }
    _notifyStateChanged();
  }

  /// 텍스트 댓글이 완료되었을 때 호출되는 메서드
  Future<void> onTextCommentCompleted(
    int postId,
    String text,
    UserController userController,
  ) async {
    if (text.trim().isEmpty) {
      debugPrint('[VoiceCommentStateManager] text is empty');
      return;
    }
    final currentUser = userController.currentUser;
    if (currentUser == null) {
      debugPrint('[VoiceCommentStateManager] current user is null');
      return;
    }

    // 텍스트 댓글 초안 저장 (위치는 드래그로 별도 저장)
    _pendingCommentDrafts[postId] = TagDraft(
      actorId: currentUser.id.toString(),
      content: TagContent.text(text.trim()),
      metadata: {'profileImageSource': currentUser.profileImageKey},
    );

    // 텍스트 댓글 대기 상태 설정
    _pendingTextComments[postId] = true;

    // 저장된 댓글 상태 업데이트
    _voiceCommentSavedStates[postId] = false;

    // 상태 변경 알림
    _notifyStateChanged();
  }

  /// 음성 댓글이 완료되었을 때 호출되는 메서드
  Future<void> onVoiceCommentCompleted(
    int postId,
    String? audioPath,
    List<double>? waveformData,
    int? duration,
    UserController userController,
  ) async {
    if (audioPath == null || waveformData == null || duration == null) {
      debugPrint('[VoiceCommentStateManager] invalid audio comment payload');
      return;
    }
    final currentUser = userController.currentUser;
    if (currentUser == null) {
      debugPrint('[VoiceCommentStateManager] current user is null');
      return;
    }

    // 음성 댓글 초안 저장 (위치는 드래그로 별도 저장)
    _pendingCommentDrafts[postId] = TagDraft(
      actorId: currentUser.id.toString(),
      content: TagContent.audio(
        reference: audioPath,
        waveformSamples: waveformData,
        durationMs: duration,
      ),
      metadata: {'profileImageSource': currentUser.profileImageKey},
    );

    // 저장된 댓글 상태 업데이트
    _pendingTextComments.remove(postId);

    // 저장된 댓글 상태 업데이트
    _voiceCommentSavedStates[postId] = false;

    // 상태 변경 알림
    _notifyStateChanged();
  }

  /// 사진/비디오 댓글이 완료되었을 때 호출되는 메서드
  Future<void> onMediaCommentCompleted(
    int postId,
    String localFilePath,
    bool isVideo,
    UserController userController,
  ) async {
    if (localFilePath.trim().isEmpty) {
      debugPrint('[VoiceCommentStateManager] media path is empty');
      return;
    }

    final currentUser = userController.currentUser;
    if (currentUser == null) {
      debugPrint('[VoiceCommentStateManager] current user is null');
      return;
    }

    _pendingCommentDrafts[postId] = TagDraft(
      actorId: currentUser.id.toString(),
      content: isVideo
          ? TagContent.video(reference: localFilePath.trim())
          : TagContent.image(reference: localFilePath.trim()),
      metadata: {'profileImageSource': currentUser.profileImageKey},
    );

    _pendingTextComments.remove(postId);
    _voiceCommentSavedStates[postId] = false;
    _notifyStateChanged();
  }

  /// 프로필 이미지 위치가 드래그로 변경되었을 때 호출되는 메서드
  void onProfileImageDragged(int postId, Offset absolutePosition) {
    final imageSize = Size(354.w, 500.h);

    // pending 태그 원형 중심 좌표를 사진 상대 위치로 변환합니다.
    final relativePosition = PositionConverter.toRelativePosition(
      absolutePosition,
      imageSize,
    );

    final draft = _pendingCommentDrafts[postId];
    if (draft == null) return;

    // UI 마커에 필요한 최소 데이터만 저장
    final previousProgress = _pendingCommentMarkers[postId]?.progress;
    _pendingCommentMarkers[postId] = TagPendingMarker(
      relativePosition: TagPosition(
        x: relativePosition.dx,
        y: relativePosition.dy,
      ),
      progress: previousProgress,
    );

    _notifyStateChanged();
  }

  void updatePendingProgress(int postId, double progress) {
    final marker = _pendingCommentMarkers[postId];
    if (marker == null) return;
    final clamped = progress.clamp(0.0, 1.0).toDouble();
    _pendingCommentMarkers[postId] = marker.copyWith(progress: clamped);
    _notifyStateChanged();
  }

  void handleCommentSaveSuccess(int postId, Comment _) {
    _voiceCommentSavedStates[postId] = true;
    _voiceCommentActiveStates[postId] = false;
    _pendingTextComments.remove(postId);
    _pendingCommentDrafts.remove(postId);
    _pendingCommentMarkers.remove(postId);
    _notifyStateChanged();
  }

  void handleCommentSaveFailure(int postId) {
    _voiceCommentSavedStates[postId] = false;
    final marker = _pendingCommentMarkers[postId];
    if (marker != null) {
      _pendingCommentMarkers[postId] = marker.copyWith(clearProgress: true);
    }
    _notifyStateChanged();
  }

  /// 음성/텍스트 댓글을 서버에 저장하는 메서드
  Future<void> saveVoiceComment(int postId, BuildContext context) async {
    final draft = _pendingCommentDrafts[postId];
    if (draft == null) {
      throw StateError('임시 댓글을 찾을 수 없습니다. postId: $postId');
    }

    // async gap 없이 필요한 의존성들을 미리 확보해두면 lint(use_build_context_synchronously)도 피할 수 있습니다.
    final commentController = context.read<CommentController>();
    api_media.MediaController? mediaController;
    try {
      mediaController = context.read<api_media.MediaController>();
    } catch (_) {
      mediaController = null;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);

    // 로그인된 사용자 ID 가져오기
    final userId = int.tryParse(draft.recorderUserId);
    if (userId == null || userId <= 0) {
      SnackBarUtils.showWithMessenger(messenger, '사용자 정보를 확인할 수 없습니다.');
      return;
    }

    // 최종 위치 결정
    final finalPosition =
        _pendingCommentMarkers[postId]?.relativePosition ??
        _generateAutoProfilePosition(postId, commentController);

    // 저장 중에도 UI 마커가 유지되도록 최종 위치를 마커에 기록
    _pendingCommentMarkers[postId] = TagPendingMarker(
      relativePosition: finalPosition,
      progress: 0.0,
    );

    _voiceCommentSavedStates[postId] = true;
    _pendingTextComments.remove(postId);
    _voiceCommentActiveStates[postId] = false;
    _notifyStateChanged();

    // 비동기적으로 서버에 댓글 저장
    // UI 스레드를 차단하지 않도록 함
    Future.microtask(() async {
      _updatePendingProgress(postId, 0.05);
      final didSave = await _saveCommentToServer(
        postId,
        userId,
        draft,
        finalPosition,
        commentController: commentController,
        mediaController: mediaController,
        messenger: messenger,
      );

      if (!didSave) {
        _voiceCommentSavedStates[postId] = false;
        _notifyStateChanged();
        return;
      }

      _pendingCommentDrafts.remove(postId);
      _pendingCommentMarkers.remove(postId);

      // 상태 변경 알림
      _notifyStateChanged();
    });
  }

  void _updatePendingProgress(int postId, double progress) {
    updatePendingProgress(postId, progress);
  }

  /// 댓글을 서버에 저장하는 내부 메서드
  Future<bool> _saveCommentToServer(
    int postId,
    int userId,
    TagDraft pending,
    TagPosition relativePosition, {
    required CommentController commentController,
    api_media.MediaController? mediaController,
    ScaffoldMessengerState? messenger,
  }) async {
    try {
      CommentCreationResult creationResult =
          const CommentCreationResult.failure();

      if (pending.isTextComment && pending.text != null) {
        // 텍스트 댓글 저장하고 그 결과를 success에 할당
        _updatePendingProgress(postId, 0.4);
        creationResult = await commentController.createTextComment(
          postId: postId,
          userId: userId,
          text: pending.text!,
          locationX: relativePosition.x,
          locationY: relativePosition.y,
        );
        _updatePendingProgress(postId, 0.85);
      } else if (pending.audioPath != null) {
        if (mediaController == null) {
          SnackBarUtils.showWithMessenger(messenger, '미디어 컨트롤러를 찾을 수 없습니다.');
          return false;
        }
        // 오디오 파일 객체 생성 --> Stirng으로 되어있는 경로를 File 객체로 변환
        _updatePendingProgress(postId, 0.15);
        final audioFile = File(pending.audioPath!);

        // 파일을 멀티파트로 변환 --> 서버 업로드를 위해
        _updatePendingProgress(postId, 0.25);
        final multipartFile = await mediaController.fileToMultipart(audioFile);

        // 오디오 업로드하고 그 키를 받아옴
        _updatePendingProgress(postId, 0.35);
        final audioKey = await mediaController.uploadCommentAudio(
          file: multipartFile,
          userId: userId,
          postId: postId,
        );

        if (audioKey == null) {
          SnackBarUtils.showWithMessenger(messenger, '음성 업로드에 실패했습니다.');
          return false;
        }

        // 파형 데이터를 JSON 문자열로 변환 (서버 제한을 고려해 축소)
        _updatePendingProgress(postId, 0.75);
        final waveformJson = _encodeWaveformForRequest(pending.waveformData);

        // 오디오 댓글 생성하고 그 결과를 success에 할당
        _updatePendingProgress(postId, 0.85);
        creationResult = await commentController.createAudioComment(
          postId: postId,
          userId: userId,
          audioFileKey: audioKey,
          waveformData: waveformJson!,
          duration: pending.durationMs!,
          locationX: relativePosition.x,
          locationY: relativePosition.y,
        );
        _updatePendingProgress(postId, 0.95);
      }

      if (creationResult.success) {
        _updatePendingProgress(postId, 1.0);
        if (creationResult.comment != null) {
          _voiceCommentSavedStates[postId] = true;
        } else {
          final refreshed = await commentController.getComments(
            postId: postId,
            forceReload: true,
          );
          _voiceCommentSavedStates[postId] = refreshed.isNotEmpty;
        }
        return true;
      }

      SnackBarUtils.showWithMessenger(messenger, '댓글 저장에 실패했습니다.');
      return false;
    } catch (e) {
      debugPrint('댓글 저장 실패(postId: $postId): $e');
      SnackBarUtils.showWithMessenger(messenger, '댓글 저장 중 오류가 발생했습니다.');
      return false;
    }
  }

  /// 음성/텍스트 댓글이 삭제되었을 때 호출되는 메서드
  void onVoiceCommentDeleted(int postId) {
    _voiceCommentActiveStates[postId] = false;
    _voiceCommentSavedStates[postId] = false;
    _clearPendingState(postId);
    _notifyStateChanged();
  }

  /// 음성/텍스트 댓글이 저장이 완료되었을 때 호출되는 메서드
  void onSaveCompleted(int postId) {
    _voiceCommentActiveStates[postId] = false;
    _notifyStateChanged();
  }

  /// 자동 배치 위치 생성기
  TagPosition _generateAutoProfilePosition(
    int postId,
    CommentController commentController,
  ) {
    final occupiedPositions = <TagPosition>[];
    final comments =
        commentController.peekTagCommentsCache(postId: postId) ??
        const <Comment>[];

    for (final comment in comments) {
      if (comment.hasLocation) {
        occupiedPositions.add(
          TagPosition(x: comment.locationX ?? 0.5, y: comment.locationY ?? 0.5),
        );
      }
    }

    // 현재 대기 중인 댓글의 위치도 포함
    final pending = _pendingCommentMarkers[postId];
    if (pending != null) {
      occupiedPositions.add(pending.relativePosition);
    }

    // 자동 배치 패턴
    const pattern = [
      TagPosition(x: 0.5, y: 0.5),
      TagPosition(x: 0.62, y: 0.5),
      TagPosition(x: 0.38, y: 0.5),
      TagPosition(x: 0.5, y: 0.62),
      TagPosition(x: 0.5, y: 0.38),
      TagPosition(x: 0.62, y: 0.62),
      TagPosition(x: 0.38, y: 0.62),
      TagPosition(x: 0.62, y: 0.38),
      TagPosition(x: 0.38, y: 0.38),
    ];

    const maxAttempts = 30;
    final patternLength = pattern.length;
    final startingIndex = _autoPlacementIndices[postId] ?? 0;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final rawIndex = startingIndex + attempt;
      final baseOffset = pattern[rawIndex % patternLength];
      final loop = rawIndex ~/ patternLength;
      final candidate = _applyJitter(baseOffset, loop, attempt);

      if (!_isPositionTooClose(candidate, occupiedPositions)) {
        _autoPlacementIndices[postId] = rawIndex + 1;
        return candidate;
      }
    }

    _autoPlacementIndices[postId] = startingIndex + 1;
    return const TagPosition(x: 0.5, y: 0.5);
  }

  TagPosition _applyJitter(TagPosition base, int loop, int attempt) {
    if (loop <= 0) {
      return _clampOffset(base);
    }
    final step = (0.02 * loop).clamp(0.02, 0.08).toDouble();
    final dxDirection = (attempt % 2 == 0) ? 1 : -1;
    final dyDirection = ((attempt ~/ 2) % 2 == 0) ? 1 : -1;

    final offsetWithJitter = TagPosition(
      x: base.x + (step * dxDirection),
      y: base.y + (step * dyDirection),
    );

    return _clampOffset(offsetWithJitter);
  }

  TagPosition _clampOffset(TagPosition offset) {
    const min = 0.05;
    const max = 0.95;
    return TagPosition(
      x: offset.x.clamp(min, max).toDouble(),
      y: offset.y.clamp(min, max).toDouble(),
    );
  }

  bool _isPositionTooClose(TagPosition candidate, List<TagPosition> occupied) {
    const threshold = 0.04;
    for (final existing in occupied) {
      if ((candidate.x - existing.x).abs() < threshold &&
          (candidate.y - existing.y).abs() < threshold) {
        return true;
      }
    }
    return false;
  }

  void dispose() {
    _pendingCommentDrafts.clear();
    _pendingCommentMarkers.clear();
    _pendingTextComments.clear();
    _inFlightTagCommentLoads.clear();
    _inFlightFullCommentLoads.clear();
  }

  void _clearPendingState(int postId) {
    _pendingCommentDrafts.remove(postId); // 임시 댓글 초안 삭제
    _pendingCommentMarkers.remove(postId); // UI 마커용 데이터 삭제
    _pendingTextComments.remove(postId); // 대기 중인 텍스트 댓글 상태 삭제
  }

  // 음성 파형 데이터를 서버 요청용으로 인코딩
  // (샘플링 및 JSON 인코딩)
  String? _encodeWaveformForRequest(List<double>? waveformData) {
    return _waveformCodec.encodeOrNull(
      waveformData,
      maxSamples: _kMaxWaveformSamples,
    );
  }
}

class _ProfileImagePrefetchCandidate {
  const _ProfileImagePrefetchCandidate({
    required this.imageUrl,
    required this.cacheKey,
  });

  final String imageUrl;
  final String? cacheKey;
}
