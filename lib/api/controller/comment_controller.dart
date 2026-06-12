import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/comment_service.dart';

/// 댓글과 관련된 상태와 동작을 한 곳에서 관리함.
///
/// 댓글 목록 저장, 생성/삭제 뒤 캐시 정리, 에러 처리까지 맡음.
class CommentController extends ChangeNotifier {
  /// 댓글 API를 실제로 호출하는 서비스.
  final CommentService _commentService;

  /// **게시물별 전체 댓글 목록**을 저장해 두는 캐시.
  /// - 화면에 다시 들어왔을 때 바로 보여줄 때 사용.
  final Map<int, List<Comment>> _cachedCommentsByPost = {};

  /// **원댓글만 모은 목록**을 저장하는 캐시.
  /// - 댓글 시트를 열기 전 가벼운 미리보기와 새로고침 동기화에 사용함.
  final Map<int, List<Comment>> _cachedParentCommentsByPost = {};

  /// **위치 정보가 있는 댓글**만 따로 저장하는 캐시.
  /// - 태그 오버레이(사진에 태그를 표시하는 것)를 빠르게 다시 그릴 때 씀.
  final Map<int, List<Comment>> _cachedTagCommentsByPost = {};

  /// 태그 캐시가 서버/parent/full 기준으로 완전하게 hydrate됐는지 추적합니다.
  /// - 로컬에서 내 태그만 임시 반영된 경우에는 제외해 다음 로드에서 재조회합니다.
  final Set<int> _hydratedTagCommentPosts = <int>{};

  /// 같은 게시물의 전체 댓글 요청이 여러 번 겹치지 않게 막는 맵.
  /// - 키는 postId, 값은 해당 게시물에 대한 **댓글**을 가져오는 Future 형식.
  final Map<int, Future<List<Comment>>> _inFlightCommentsByPost = {};

  /// 같은 게시물의 원댓글 전체 미리보기 요청이 여러 번 겹치지 않게 막는 맵.
  /// - 키는 postId, 값은 해당 게시물에 대한 **원댓글 목록**을 가져오는 Future 형식.
  final Map<int, Future<List<Comment>>> _inFlightParentPreviewCommentsByPost =
      {};

  /// 같은 게시물의 태그 댓글 요청이 여러 번 겹치지 않게 막는 맵.
  /// - 키는 postId, 값은 해당 게시물에 대한 **태그 댓글**을 가져오는 Future 형식.
  final Map<int, Future<List<Comment>>> _inFlightTagCommentsByPost = {};

  /// 게시물 원댓글 페이지 요청을 "postId:page" 키로 묶어 두는 맵.
  ///
  /// 왜 이렇게 할까?
  /// - 원댓글이 많아서 페이지네이션이 필요한데, 같은 페이지를 여러 번 요청할 수 있음.
  /// - 예를 들어, 사용자가 빠르게 스크롤하면서 같은 페이지를 여러 번 요청할 수 있는데,
  ///   이 맵이 있으면 첫 번째 요청이 끝날 때까지 나머지 요청들은 기다렸다가 같은 결과를 재사용할 수 있음.
  ///
  ///
  /// Map 구조 예시:
  /// {
  ///   "123:0": Future.value((
  ///     comments: `List<Comment>` 형태의 목록,
  ///     hasMore: true,
  ///   )),
  /// }
  ///
  /// 키
  /// - "123:0"은 게시물 ID 123의 첫 페이지 원댓글 요청을 나타냄.
  ///
  /// 값
  /// - [comments]: 해당 페이지에 있는 댓글 목록.
  /// - [hasMore]: 다음 페이지가 더 있는지 여부.
  final Map<String, Future<({List<Comment> comments, bool hasMore})>>
  _inFlightParentCommentsByPostPage = {};

  /// 대댓글 페이지 요청을 "parentCommentId:page" 키로 묶어 두는 맵.
  ///
  /// 왜 이렇게 할까?
  /// - 대댓글도 페이지네이션이 필요한데, 같은 페이지를 여러 번 요청할 수 있음.
  /// - 예를 들어, 사용자가 빠르게 스크롤하면서 같은 페이지를 여러 번 요청할 수 있는데,
  ///   이 맵이 있으면 첫 번째 요청이 끝날 때까지 나머지 요청들은 기다렸다가 같은 결과를 재사용할 수 있음.
  ///
  /// Map 구조 예시:
  /// {
  ///   "456:1": Future.value((
  ///     comments: `List<Comment>` 형태의 목록,
  ///     hasMore: false,
  ///   )),
  /// }
  ///
  /// 키
  /// - "456:1"은 부모 댓글 ID 456의 두 번째 페이지 대댓글 요청을 나타냄.
  ///
  /// 값
  /// - [comments]: 해당 페이지에 있는 대댓글 목록.
  /// - [hasMore]: 다음 페이지가 더 있는지 여부.
  final Map<String, Future<({List<Comment> comments, bool hasMore})>>
  _inFlightChildCommentsByParentPage = {};

  /// 사용자 댓글 페이지 요청을 `"userId:page"` 키로 묶어 두는 맵.
  ///
  /// 왜 이렇게 할까?
  /// - 사용자가 작성한 댓글도 페이지네이션이 필요한데, 같은 페이지를 여러 번 요청할 수 있음.
  /// - 예를 들어, 사용자가 빠르게 스크롤하면서 같은 페이지를 여러 번 요청할 수 있는데,
  ///   이 맵이 있으면 첫 번째 요청이 끝날 때까지 나머지 요청들은 기다렸다가 같은 결과를 재사용할 수 있음.
  ///
  /// Map 구조 예시:
  /// {
  ///   "789:0": Future.value((
  ///     comments: `List<Comment>` 형태의 목록,
  ///     hasMore: true,
  ///   )),
  /// }
  ///
  /// 키
  /// - "789:0"은 사용자 ID 789의 첫 페이지 댓글 요청을 나타냄.
  ///
  /// 값
  /// - [comments]: 해당 페이지에 있는 댓글 목록.
  /// - [hasMore]: 다음 페이지가 더 있는지 여부.
  final Map<String, Future<({List<Comment> comments, bool hasMore})>>
  _inFlightCommentsByUserPage = {};

  /// 댓글 관련 요청이 지금 진행 중인지 나타내는 값임.
  bool _isLoading = false;

  /// 마지막으로 발생한 댓글 관련 에러 메시지임.
  String? _errorMessage;

  /// 동시에 실행 중인 댓글 요청 개수를 세는 값임.
  int _activeRequestCount = 0;

  /// 댓글 상태 관리에 쓸 서비스를 받아 컨트롤러를 만듦.
  ///
  /// - [commentService]: 테스트나 교체용으로 넣을 서비스임.
  ///   값을 넘기지 않으면 기본 [CommentService]를 씀.
  CommentController({CommentService? commentService})
    : _commentService = commentService ?? CommentService();

  // ============================================
  // 공개 상태
  // ============================================

  /// 댓글 관련 요청이 진행 중인지 알려줌.
  ///
  /// 반환값: 요청이 있으면 `true`, 없으면 `false`를 반환함.
  bool get isLoading => _isLoading;

  /// 현재 저장된 에러 메시지를 알려줌.
  ///
  /// 반환값: 에러 메시지가 있으면 문자열을, 없으면 `null`을 반환함.
  String? get errorMessage => _errorMessage;

  // ============================================
  // 캐시 접근
  // ============================================

  /// 게시물의 전체 댓글 캐시를 바로 꺼내서 보여줄 때 사용.
  ///
  /// 캐시가 없으면 서버에서 다시 불러와야 함.
  ///
  /// Parameters:
  /// - [postId]: 캐시를 확인할 게시물 ID.
  ///
  /// Returns: 캐시에 전체 댓글 목록이 있으면 반환하고, 없으면 `null`을 반환.
  /// - [List<'Comment'>]: 캐시에 있는 전체 댓글 목록.
  /// - [null]: 캐시에 해당 게시물의 댓글이 없음.
  List<Comment>? peekCommentsCache({required int postId}) =>
      _cachedCommentsByPost[postId];

  /// 게시물의 원댓글 캐시를 꺼내서 댓글 시트 초기 미리보기에 사용.
  ///
  /// 원댓글 캐시가 없으면 `null`을 반환해 호출부가 서버 재조회를 결정하게 함.
  ///
  /// Parameters:
  /// - [postId]: 원댓글 캐시를 확인할 게시물 ID.
  ///
  /// Returns: 원댓글 목록이 있으면 반환하고, 없으면 `null`을 반환함.
  List<Comment>? peekParentCommentsCache({required int postId}) =>
      _cachedParentCommentsByPost[postId];

  /// 게시물의 위치 댓글 캐시를 꺼내서 태그 오버레이에 보여줄 때 사용.
  ///
  /// 태그 캐시가 없으면 null을 반환해 호출부가 서버 재조회를 결정하게 합니다.
  ///
  /// Parameters:
  /// - [postId]: 태그 캐시를 확인할 게시물 ID.
  ///
  /// Returns: 위치 댓글 목록이 있으면 반환하고, 없으면 `null`을 반환함.
  /// - [List<'Comment'>]: 캐시에 있는 태그 댓글 목록.
  /// - [null]: 캐시에 해당 게시물의 태그 댓글이 없음.
  List<Comment>? peekTagCommentsCache({required int postId}) =>
      _cachedTagCommentsByPost[postId];

  /// 현재 태그 캐시가 서버 기준의 완전한 목록인지 호출부가 판단할 수 있게 노출합니다.
  bool hasHydratedTagCommentsCache({required int postId}) =>
      _hydratedTagCommentPosts.contains(postId);

  /// 새로 받아온 데이터로 캐시를 통째로 바꿈.
  /// - 댓글 데이터가 바뀌는 시점에 두 캐시를 항상 동시에 교체해서 둘 사이의 불일치를 방지
  ///
  /// 사용되는 상황:
  /// - voice_comment_state_manager
  ///   - 음성 댓글 추가 후 force reload 직후, 전체/원댓글/태그 캐시를 같은 기준으로 새 데이터로 통째로 바꿈.
  /// - api_photo_display_widget
  ///   - 댓글 시트에서 돌아올 때, 댓글이 바뀌었을 수 있으니 전체/원댓글/태그 캐시를 새 데이터로 통째로 바꿈.
  /// - api_photo_detail_screen
  ///   - 아카이브 상세에서 댓글 시트 닫힐 때, 댓글이 바뀌었을 수 있으니 전체/원댓글/태그 캐시를 새 데이터로 통째로 바꿈.
  ///
  /// Parameters:
  /// - [postId]: 캐시를 바꿀 게시물 ID.
  /// - [comments]: 새로 저장할 전체 댓글 목록.
  ///
  /// Returns: 값을 반환하지 않음.
  void replaceCommentsCache({
    required int postId,
    required List<Comment> comments,
  }) {
    final frozen = _freeze(comments); // 입력받은 댓글 목록을 고쳐지지 않는 리스트로 만듦.
    _cachedCommentsByPost[postId] = frozen; // 전체 댓글 캐시에 새 리스트 저장.
    _syncDerivedCachesFromFull(postId);
    notifyListeners();
  }

  /// 원댓글만 다시 받아왔을 때, 원댓글/태그 캐시만 새 데이터로 교체함.
  ///
  /// 댓글 시트 전체 스레드는 비워 둔 채, 오버레이와 시트 초기 미리보기만 최신 상태로 맞출 때 사용함.
  ///
  /// Parameters:
  /// - [postId]: 원댓글 캐시를 바꿀 게시물 ID.
  /// - [comments]: 새로 저장할 원댓글 목록.
  void replaceParentCommentsCache({
    required int postId,
    required List<Comment> comments,
  }) {
    final frozenParents = _freeze(_filterParentComments(comments));
    _cachedParentCommentsByPost[postId] = frozenParents;
    _cachedTagCommentsByPost[postId] = _freeze(
      _filterTagComments(frozenParents),
    );
    _hydratedTagCommentPosts.add(postId);
    notifyListeners();
  }

  /// 태그 댓글만 다시 받아왔을 때, **태그 캐시만** 바꿈.
  ///
  /// 사용되는 상황:
  /// - commentController.getTagComments
  ///   - 태그 댓글을 다시 불러올 때, 전체 댓글 캐시는 그대로 두고 태그 댓글 캐시만 새 데이터로 바꿈.
  ///
  /// Parameters:
  /// - [postId]: 태그 캐시를 바꿀 게시물 ID.
  /// - [comments]: 위치 정보가 있는 댓글 목록.
  ///
  /// Returns: 값을 반환하지 않음.
  void replaceTagCommentsCache({
    required int postId,
    required List<Comment> comments,
  }) {
    _cachedTagCommentsByPost[postId] = _freeze(comments);
    _hydratedTagCommentPosts.add(postId);
    notifyListeners();
  }

  /// 새 댓글을 이미 로드한 캐시에 덧붙임.
  ///
  /// 사용되는 상황:
  /// - comment_controller.createComment
  ///   - 댓글을 새로 만들고 나서, 서버에서 성공적으로 만들어진 댓글 데이터를 받아오면, 전체 댓글 캐시에 새 댓글을 덧붙임.
  /// - voice_comment_state_manager
  ///   - 음성 댓글 업로드를 성공 후, 케시에 저장.
  /// - feed_home
  ///   -
  ///
  /// Parameters:
  /// - [postId]: 댓글이 추가된 게시물 ID.
  /// - [newComment]: 새로 만들어진 댓글.
  ///
  /// Returns: 값을 반환하지 않음.
  /// - full/parent cache가 없는 tag-only 상태에서 추가된 값은 임시 cache로 간주합니다.
  void appendCreatedComment({
    required int postId,
    required Comment newComment,
  }) {
    var didChange = false;
    final full = _cachedCommentsByPost[postId]; // 전체 댓글 캐시 먼저 확인
    final parentComments = _cachedParentCommentsByPost[postId];

    // 전체 댓글이 존재하고(full != null), 새 댓글이 전체 댓글 캐시에 아직 없으면(!_contains(full, newComment.id))
    // 전체 댓글 캐시에 새 댓글을 덧붙여서 저장함.
    if (full != null && !_contains(full, newComment.id)) {
      _cachedCommentsByPost[postId] = _freeze([...full, newComment]);
      _syncDerivedCachesFromFull(postId);
      didChange = true;
    } else if (!newComment.isReply &&
        parentComments != null &&
        !_contains(parentComments, newComment.id)) {
      final nextParents = _freeze([...parentComments, newComment]);
      _cachedParentCommentsByPost[postId] = nextParents;
      _cachedTagCommentsByPost[postId] = _freeze(
        _filterTagComments(nextParents),
      );
      didChange = true;
    }

    if (!newComment.hasLocation) {
      if (didChange) {
        notifyListeners();
      }
      return;
    }

    final tags = _cachedTagCommentsByPost[postId];

    // 태그 댓글이 존재하고(tags != null), 새 댓글이 태그 댓글 캐시에 아직 없으면(!_contains(tags, newComment.id))
    // 태그 댓글 캐시에 새 댓글을 덧붙여서 저장함.
    // 전체 댓글 캐시는 이미 위에서 새 댓글이 없으면 덧붙였거나, 새 댓글이 있으면 그대로 두었음.
    if (full == null &&
        parentComments == null &&
        tags != null &&
        !_contains(tags, newComment.id)) {
      _cachedTagCommentsByPost[postId] = _freeze([...tags, newComment]);
      _hydratedTagCommentPosts.remove(postId);
      didChange = true; // 태그 캐시에 새 댓글을 추가했으니 변경이 있었음.
    }

    if (didChange) {
      notifyListeners();
    }
  }

  /// 삭제한 댓글을 현재 메모리에 있는 캐시에서만 제거함.
  ///
  /// - [postId]: 댓글이 삭제된 게시물 ID임.
  /// - [commentId]: 캐시에서 지울 댓글 ID임.
  /// Returns: 값을 반환하지 않음.
  void removeCommentFromCache({required int postId, required int commentId}) {
    var didChange = false; // 캐시에서 댓글을 지운 적이 있는지 여부를 추적하는 변수임.
    final full = _cachedCommentsByPost[postId];
    if (full != null) {
      _cachedCommentsByPost[postId] = _freeze(
        full.where((c) => c.id != commentId).toList(),
      );
      _syncDerivedCachesFromFull(postId);
      didChange = true; // 전체 댓글 캐시에서 댓글을 지웠으니 변경이 있었음.
    } else {
      final parentComments = _cachedParentCommentsByPost[postId];
      if (parentComments != null) {
        final nextParents = _freeze(
          parentComments.where((c) => c.id != commentId).toList(),
        );
        _cachedParentCommentsByPost[postId] = nextParents;
        _cachedTagCommentsByPost[postId] = _freeze(
          _filterTagComments(nextParents),
        );
        didChange = true;
      } else {
        final tags = _cachedTagCommentsByPost[postId];
        if (tags != null) {
          _cachedTagCommentsByPost[postId] = _freeze(
            tags.where((c) => c.id != commentId).toList(),
          );
          _hydratedTagCommentPosts.remove(postId);
          didChange = true;
        }
      }
    }

    if (didChange) {
      notifyListeners();
    }
  }

  /// 게시물 댓글 캐시를 지워서 다음 조회 때 다시 가져오게 함.
  ///
  /// - [postId]: 캐시를 지울 게시물 ID임.
  /// - [full]: `true`면 전체 댓글 캐시도 지움.
  /// - [parent]: `true`면 원댓글 미리보기 캐시도 지움.
  /// - [tag]: `true`면 태그 댓글 캐시도 지움.
  /// Returns: 값을 반환하지 않음.
  void invalidatePostCaches({
    required int postId,
    bool full = true,
    bool parent = false,
    bool tag = true,
  }) {
    var didChange = false;
    if (full) {
      didChange = _cachedCommentsByPost.remove(postId) != null || didChange;
      didChange =
          _cachedParentCommentsByPost.remove(postId) != null || didChange;
    } else if (parent) {
      didChange =
          _cachedParentCommentsByPost.remove(postId) != null || didChange;
    }
    if (tag) {
      didChange = _cachedTagCommentsByPost.remove(postId) != null || didChange;
      _hydratedTagCommentPosts.remove(postId);
    }
    if (didChange) {
      notifyListeners();
    }
  }

  // ============================================
  // 댓글 생성
  // ============================================

  /// 댓글 생성 요청에 필요한 값을 정리해 서비스에 보냄.
  /// 성공하면 캐시도 함께 업데이트함.
  ///
  /// - [postId]: 댓글을 달 게시물 ID임.
  /// - [userId]: 댓글 작성자 ID임.
  /// - [emojiId]: 함께 보낼 이모지 ID임.
  /// - [parentId]: 대댓글이면 연결할 부모 댓글 ID임.
  /// - [replyUserId]: 답글 대상 사용자 ID임.
  /// - [text]: 텍스트 댓글 내용임.
  /// - [audioKey]: 음성 댓글 파일 키임.
  /// - [fileKey]: 사진 댓글 파일 키임.
  /// - [waveformData]: 음성 파형 데이터임.
  /// - [duration]: 음성 길이 정보임.
  /// - [locationX]: 댓글 위치의 X 좌표임.
  /// - [locationY]: 댓글 위치의 Y 좌표임.
  /// - [type]: 직접 지정할 댓글 타입임. 없으면 내부 규칙으로 정함.
  /// Returns: 생성 결과를 담은 [CommentCreationResult]를 반환함.
  Future<CommentCreationResult> createComment({
    required int postId,
    required int userId,
    int? emojiId,
    int? parentId,
    int? replyUserId,
    String? text,
    String? audioKey,
    String? fileKey,
    String? waveformData,
    int? duration,
    double? locationX,
    double? locationY,
    CommentType? type,
  }) async {
    _beginRequest();
    try {
      final effAudioKey = audioKey?.trim() ?? '';
      final effParentId = parentId ?? 0;
      final effReplyUserId = replyUserId ?? 0;
      final effFileKey = fileKey?.trim() ?? '';
      final effLocationX = locationX ?? 0.0;
      final effLocationY = locationY ?? 0.0;
      final hasAudio = effAudioKey.isNotEmpty;

      final result = await _commentService.createComment(
        postId: postId,
        userId: userId,
        emojiId: emojiId ?? 0,
        parentId: effParentId,
        replyUserId: effReplyUserId,
        // Swagger와 맞추기 위해 음성이 있으면 audio만 채우고 text는 비움.
        // REPLY 타입이어도 음성 답글이면 audio payload를 함께 보냄.
        text: hasAudio ? '' : (text?.trim() ?? ''),
        audioFileKey: hasAudio ? effAudioKey : '',
        fileKey: effFileKey,
        waveformData: hasAudio ? (waveformData?.trim() ?? '') : '',
        duration: hasAudio ? (duration ?? 0) : 0,
        locationX: effLocationX,
        locationY: effLocationY,
        type:
            type ??
            _inferType(
              hasAudio: hasAudio,
              parentId: effParentId,
              replyUserId: effReplyUserId,
              fileKey: effFileKey,
            ),
      );

      if (result.success) {
        result.comment != null
            ? appendCreatedComment(postId: postId, newComment: result.comment!)
            : invalidatePostCaches(postId: postId);
      }
      return result;
    } catch (e) {
      _setError('댓글 생성 실패: $e');
      return const CommentCreationResult.failure();
    } finally {
      _endRequest();
    }
  }

  /// 텍스트 원댓글을 만들기 쉽게 [createComment]를 감싼 메서드임.
  ///
  /// - [postId]: 댓글을 달 게시물 ID임.
  /// - [userId]: 댓글 작성자 ID임.
  /// - [text]: 텍스트 댓글 내용임.
  /// - [locationX]: 댓글 위치의 X 좌표임.
  /// - [locationY]: 댓글 위치의 Y 좌표임.
  /// Returns: 생성 결과를 담은 [CommentCreationResult]를 반환함.
  Future<CommentCreationResult> createTextComment({
    required int postId,
    required int userId,
    required String text,
    required double locationX,
    required double locationY,
  }) => createComment(
    postId: postId,
    userId: userId,
    emojiId: 0,
    parentId: 0,
    replyUserId: 0,
    text: text,
    locationX: locationX,
    locationY: locationY,
    type: CommentType.text,
  );

  /// 음성 원댓글을 만들기 쉽게 [createComment]를 감싼 메서드임.
  ///
  /// - [postId]: 댓글을 달 게시물 ID임.
  /// - [userId]: 댓글 작성자 ID임.
  /// - [audioFileKey]: 업로드된 음성 파일 키임.
  /// - [waveformData]: 음성 파형 문자열임.
  /// - [duration]: 음성 길이 정보임.
  /// - [locationX]: 댓글 위치의 X 좌표임.
  /// - [locationY]: 댓글 위치의 Y 좌표임.
  /// Returns: 생성 결과를 담은 [CommentCreationResult]를 반환함.
  Future<CommentCreationResult> createAudioComment({
    required int postId,
    required int userId,
    required String audioFileKey,
    required String waveformData,
    required int duration,
    required double locationX,
    required double locationY,
  }) => createComment(
    postId: postId,
    userId: userId,
    emojiId: 0,
    parentId: 0,
    replyUserId: 0,
    audioKey: audioFileKey,
    waveformData: waveformData,
    duration: duration,
    locationX: locationX,
    locationY: locationY,
    type: CommentType.audio,
  );

  // ============================================
  // 댓글 조회
  // ============================================

  /// 게시물의 전체 댓글을 가져옴.
  /// 먼저 캐시를 보고, 필요하면 서버에서 다시 불러옴.
  ///
  /// - [postId]: 댓글을 가져올 게시물 ID임.
  /// - [forceReload]: `true`면 캐시를 지우고 다시 가져옴.
  /// Returns: 전체 댓글 목록을 담은 [Future<List<Comment>>]를 반환함.
  Future<List<Comment>> getComments({
    required int postId,
    bool forceReload = false,
  }) async {
    if (!forceReload) {
      final cached = _cachedCommentsByPost[postId];
      if (cached != null) return cached;
    } else {
      invalidatePostCaches(postId: postId);
    }

    return _dedup(
      _inFlightCommentsByPost,
      postId,
      () async {
        _beginRequest();
        try {
          final comments = await _commentService.getComments(postId: postId);
          replaceCommentsCache(postId: postId, comments: comments);
          return _cachedCommentsByPost[postId] ?? const <Comment>[];
        } finally {
          _endRequest();
        }
      },
      const <Comment>[],
      '댓글 조회 실패',
    );
  }

  /// 게시물의 원댓글만 페이지를 끝까지 따라가며 가져옴.
  /// 새로고침/알림 진입에서 가벼운 미리보기와 태그 오버레이를 최신 상태로 맞출 때 사용함.
  ///
  /// - [postId]: 원댓글을 가져올 게시물 ID임.
  /// - [forceReload]: `true`면 전체/원댓글/태그 캐시를 비우고 다시 가져옴.
  /// Returns: 원댓글 목록을 담은 [Future<List<Comment>>]를 반환함.
  Future<List<Comment>> getAllParentComments({
    required int postId,
    bool forceReload = false,
  }) async {
    if (!forceReload) {
      final cached = _cachedParentCommentsByPost[postId];
      if (cached != null) return cached;
    } else {
      invalidatePostCaches(postId: postId);
    }

    return _dedup(
      _inFlightParentPreviewCommentsByPost,
      postId,
      () async {
        _beginRequest();
        try {
          final comments = <Comment>[];
          var page = 0;
          while (true) {
            final slice = await _commentService.getParentComments(
              postId: postId,
              page: page,
            );
            if (slice.comments.isEmpty) {
              break;
            }
            comments.addAll(slice.comments);
            if (!slice.hasMore) {
              break;
            }
            page += 1;
          }
          replaceParentCommentsCache(postId: postId, comments: comments);
          return _cachedParentCommentsByPost[postId] ?? const <Comment>[];
        } finally {
          _endRequest();
        }
      },
      const <Comment>[],
      '원댓글 전체 조회 실패',
    );
  }

  /// 태그 오버레이에 필요한 위치 댓글만 가져옴.
  /// 먼저 태그 캐시를 보고, 필요하면 서버에서 다시 불러옴.
  ///
  /// - [postId]: 태그 댓글을 가져올 게시물 ID임.
  /// - [forceReload]: `true`면 태그 캐시를 지우고 다시 가져옴.
  /// Returns: 위치 댓글 목록을 담은 [Future<List<Comment>>]를 반환함.
  Future<List<Comment>> getTagComments({
    required int postId,
    bool forceReload = false,
  }) async {
    if (!forceReload) {
      final cached = peekTagCommentsCache(postId: postId);
      if (cached != null && hasHydratedTagCommentsCache(postId: postId)) {
        return cached;
      }
    } else {
      invalidatePostCaches(postId: postId, tag: true, full: false);
    }

    return _dedup(
      _inFlightTagCommentsByPost,
      postId,
      () async {
        _beginRequest();
        try {
          final comments = await _commentService.getTagComments(postId: postId);

          // 태그 캐시만 새 데이터로 바꿈. 전체 댓글 캐시는 그대로 둠.
          replaceTagCommentsCache(postId: postId, comments: comments);
          return _cachedTagCommentsByPost[postId] ?? const <Comment>[];
        } finally {
          _endRequest();
        }
      },
      const <Comment>[],
      '태그 댓글 조회 실패',
    );
  }

  /// 게시물의 댓글 총개수를 가져옴.
  ///
  /// - [postId]: 댓글 개수를 확인할 게시물 ID임.
  /// Returns: 댓글 개수를 담은 [Future<int>]를 반환함. 실패하면 `0`을 반환함.
  Future<int> getCommentCount({required int postId}) async {
    _beginRequest();
    try {
      return await _commentService.getCommentCount(postId: postId);
    } catch (e) {
      _setError('댓글 개수 조회 실패: $e');
      return 0;
    } finally {
      _endRequest();
    }
  }

  /// 게시물의 원댓글 한 페이지를 가져옴.
  /// 같은 페이지 요청이 겹치면 한 번만 보내도록 처리함.
  ///
  /// - [postId]: 원댓글을 가져올 게시물 ID임.
  /// - [page]: 0부터 시작하는 페이지 번호임.
  /// Returns: 댓글 목록과 다음 페이지 여부를 담은 레코드 [Future]를 반환함.
  Future<({List<Comment> comments, bool hasMore})> getParentComments({
    required int postId,
    int page = 0,
  }) => _dedup(
    _inFlightParentCommentsByPostPage,
    _pageKey(postId, page),
    () async {
      _beginRequest();
      try {
        return await _commentService.getParentComments(
          postId: postId,
          page: page,
        );
      } finally {
        _endRequest();
      }
    },
    (comments: <Comment>[], hasMore: false),
    '원댓글 조회 실패',
  );

  /// 부모 댓글의 대댓글 한 페이지를 가져옴.
  /// 같은 페이지 요청이 겹치면 한 번만 보내도록 처리함.
  ///
  /// - [parentCommentId]: 대댓글을 가져올 부모 댓글 ID임.
  /// - [page]: 0부터 시작하는 페이지 번호임.
  /// Returns: 댓글 목록과 다음 페이지 여부를 담은 레코드 [Future]를 반환함.
  Future<({List<Comment> comments, bool hasMore})> getChildComments({
    required int parentCommentId,
    int page = 0,
  }) => _dedup(
    _inFlightChildCommentsByParentPage,
    _pageKey(parentCommentId, page),
    () async {
      _beginRequest();
      try {
        return await _commentService.getChildComments(
          parentCommentId: parentCommentId,
          page: page,
        );
      } finally {
        _endRequest();
      }
    },
    (comments: <Comment>[], hasMore: false),
    '대댓글 조회 실패',
  );

  /// 사용자가 작성한 댓글 한 페이지를 가져옴.
  /// 같은 페이지 요청이 겹치면 한 번만 보내도록 처리함.
  ///
  /// - [userId]: 댓글을 작성한 사용자 ID임.
  /// - [page]: 0부터 시작하는 페이지 번호임.
  /// Returns: 댓글 목록과 다음 페이지 여부를 담은 레코드 [Future]를 반환함.
  Future<({List<Comment> comments, bool hasMore})> getCommentsByUserId({
    required int userId,
    int page = 0,
  }) => _dedup(
    _inFlightCommentsByUserPage,
    _pageKey(userId, page),
    () async {
      _beginRequest();
      try {
        return await _commentService.getCommentsByUserId(
          userId: userId,
          page: page,
        );
      } finally {
        _endRequest();
      }
    },
    (comments: <Comment>[], hasMore: false),
    '사용자 댓글 조회 실패',
  );

  // ============================================
  // 댓글 삭제
  // ============================================

  /// 댓글 삭제 요청을 보냄.
  ///
  /// - [commentId]: 삭제할 댓글 ID임.
  /// Returns: 삭제에 성공하면 `true`, 실패하면 `false`를 담은 [Future<bool>]를 반환함.
  Future<bool> deleteComment(int commentId) async {
    _beginRequest();
    try {
      return await _commentService.deleteComment(commentId);
    } catch (e) {
      _setError('댓글 삭제 실패: $e');
      return false;
    } finally {
      _endRequest();
    }
  }

  // ============================================
  // 에러 처리
  // ============================================

  /// 저장해 둔 에러 메시지를 비움.
  ///
  /// Returns: 값을 반환하지 않음.
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  // ============================================
  // 내부 헬퍼
  // ============================================

  /// 같은 요청이 동시에 들어오면 하나의 Future를 같이 기다리게 함.
  /// 작업이 끝나면 맵에서 해당 요청을 정리함.
  ///
  /// - [pending]: 진행 중인 요청을 보관하는 맵임.
  /// - [key]: 요청을 구분하는 키임.
  /// - [work]: 실제로 실행할 비동기 작업임.
  /// - [empty]: 실패했을 때 대신 돌려줄 기본값임.
  /// - [errorLabel]: 에러 메시지 앞에 붙일 설명임.
  /// Returns: 작업 결과 또는 기본값을 담은 [Future<T>]를 반환함.
  Future<T> _dedup<K, T>(
    Map<K, Future<T>> pending,
    K key,
    Future<T> Function() work,
    T empty,
    String errorLabel,
  ) async {
    final task = pending.putIfAbsent(key, work);
    try {
      return await task;
    } catch (e) {
      _setError('$errorLabel: $e');
      return empty;
    } finally {
      if (identical(pending[key], task)) pending.remove(key);
    }
  }

  /// 댓글 요청이 시작될 때 로딩 상태를 켬.
  ///
  /// Returns: 값을 반환하지 않음.
  void _beginRequest() {
    _activeRequestCount++;
    final shouldNotify = _errorMessage != null || !_isLoading;
    _isLoading = true;
    _errorMessage = null;
    if (shouldNotify) notifyListeners();
  }

  /// 댓글 요청이 끝날 때 남은 요청 수를 보고 로딩 상태를 다시 계산함.
  ///
  /// Returns: 값을 반환하지 않음.
  void _endRequest() {
    if (_activeRequestCount > 0) _activeRequestCount--;
    final newLoading = _activeRequestCount > 0;
    if (_isLoading != newLoading) {
      _isLoading = newLoading;
      notifyListeners();
    }
  }

  /// 에러 메시지를 저장하고 화면에 알림.
  ///
  /// - [message]: 저장할 에러 메시지임.
  /// Returns: 값을 반환하지 않음.
  void _setError(String message) {
    if (_errorMessage == message) return;
    _errorMessage = message;
    notifyListeners();
  }

  /// 페이지 요청을 `"id:page"` 형태의 문자열 키로 만듦.
  ///
  /// - [id]: 게시물, 부모 댓글, 사용자 중 하나의 ID임.
  /// - [page]: 페이지 번호임.
  /// Returns: 중복 요청을 구분할 키 문자열을 반환함.
  static String _pageKey(int id, int page) => '$id:$page';

  /// 입력값을 보고 댓글 타입을 정함.
  /// 음성 댓글, 답글, 사진 댓글, 텍스트 댓글 순서로 판단함.
  ///
  /// - [hasAudio]: 음성 파일이 있는지 여부임.
  /// - [parentId]: 부모 댓글 ID임.
  /// - [replyUserId]: 답글 대상 사용자 ID임.
  /// - [fileKey]: 사진 파일 키임.
  /// Returns: 결정된 [CommentType]을 반환함.
  static CommentType _inferType({
    required bool hasAudio,
    required int parentId,
    required int replyUserId,
    required String fileKey,
  }) {
    if (hasAudio) return CommentType.audio;
    if (replyUserId > 0 || parentId > 0) return CommentType.reply;
    if (fileKey.isNotEmpty) return CommentType.photo;
    return CommentType.text;
  }

  /// 댓글 목록을 수정 불가능한 리스트로 바꿈.
  /// 캐시에 넣은 뒤 다른 곳에서 실수로 바꾸지 못하게 함.
  ///
  /// - [comments]: 고정할 댓글 목록임.
  /// Returns: 비어 있으면 상수 리스트를, 아니면 불변 리스트를 반환함.
  static List<Comment> _freeze(List<Comment> comments) => comments.isEmpty
      ? const <Comment>[]
      : List<Comment>.unmodifiable(comments);

  /// 전체 댓글 중 원댓글만 골라냄.
  ///
  /// - [comments]: 필터링할 전체 댓글 목록임.
  /// Returns: 대댓글을 제외한 원댓글만 담은 리스트를 반환함.
  static List<Comment> _filterParentComments(List<Comment> comments) =>
      comments.where((c) => !c.isReply).toList(growable: false);

  /// 전체 댓글 중 위치 정보가 있는 댓글만 골라냄.
  ///
  /// - [comments]: 필터링할 전체 댓글 목록임.
  /// Returns: 위치 정보가 있는 댓글만 담은 리스트를 반환함.
  static List<Comment> _filterTagComments(List<Comment> comments) =>
      comments.where((c) => c.hasLocation).toList(growable: false);

  /// 전체 댓글 캐시가 바뀌면 원댓글/태그 파생 캐시도 같은 기준으로 다시 맞춤.
  void _syncDerivedCachesFromFull(int postId) {
    final fullComments = _cachedCommentsByPost[postId];
    if (fullComments == null) {
      _cachedParentCommentsByPost.remove(postId);
      _hydratedTagCommentPosts.remove(postId);
      return;
    }
    final parentComments = _freeze(_filterParentComments(fullComments));
    _cachedParentCommentsByPost[postId] = parentComments;
    _cachedTagCommentsByPost[postId] = _freeze(
      _filterTagComments(parentComments),
    );
    _hydratedTagCommentPosts.add(postId);
  }

  /// 댓글 목록에 특정 ID가 이미 있는지 확인함.
  ///
  /// - [comments]: 확인할 댓글 목록임.
  /// - [id]: 찾을 댓글 ID임.
  /// Returns: 있으면 `true`, 없으면 `false`를 반환함.
  static bool _contains(List<Comment> comments, int? id) =>
      id != null && comments.any((c) => c.id == id);
}
