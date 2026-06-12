import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../../api/controller/comment_controller.dart';
import '../../../api/controller/friend_controller.dart';
import '../../../api/controller/media_controller.dart';
import '../../../api/controller/post_controller.dart';
import '../../../api/controller/user_controller.dart';
import '../../../api/media_processing/waveform_codec.dart';
import '../../../api/models/comment.dart';
import '../../../utils/snackbar_utils.dart';
import '../../about_feed/manager/feed_data_manager.dart';
import 'comment_audio_recording_bottom_sheet_widget.dart';
import 'comment_camera_bottom_sheet_widget.dart';
import 'services/about_comment_list_sheet/comment_sheet_moderation_service.dart';
import 'services/about_comment_list_sheet/comment_persistence_service.dart';
import 'services/about_comment_list_sheet/comment_sheet_submission_service.dart';
import 'services/about_comment_list_sheet/comment_thread_service.dart';
import 'widgets/about_comment_list_sheet/comment_sheet_action_bar.dart';
import 'widgets/about_comment_list_sheet/comment_sheet_action_popup.dart';
import 'widgets/about_comment_list_sheet/comment_sheet_list_view.dart';

/// 댓글 리스트를 보여주는 바텀 시트 위젯입니다.
/// - 댓글 작성, 삭제, 신고, 차단 등의 액션을 포함한 완전한 댓글 인터랙션 플로우를 제공합니다.
/// - API에서 제공하는 댓글 데이터를 앱 내부 모델로 변환하여 사용합니다.
///   - API의 CommentRespDto는 앱 내부에서 Comment 모델로 변환되어 사용됩니다.
/// - 댓글 스레드 구조를 지원하며, 원댓글과 대댓글을 구분하여 표시하고 관리합니다.
///
/// fields:
/// - [postId]: 댓글이 속한 포스트의 ID입니다.
/// - [initialComments]
///   - 시트가 처음 열릴 때 표시할 댓글 리스트입니다.
///   - API에서 제공하는 댓글 데이터를 앱 내부 모델로 변환하여 사용합니다.
/// - [loadFullComments]: 시트가 열린 후, 댓글 리스트를 완전한 스레드 구조로 갱신하기 위한 비동기 로더입니다.
/// - [selectedCommentId]: 시트가 열릴 때 자동으로 스크롤한 후, 강조하여 표시할 댓글의 ID입니다.
class ApiVoiceCommentListSheet extends StatefulWidget {
  final int postId;
  final List<Comment> initialComments;
  final Future<List<Comment>> Function(int postId)? loadFullComments;
  final String? selectedCommentId;
  final ValueChanged<List<Comment>>? onCommentsUpdated;

  const ApiVoiceCommentListSheet({
    super.key,
    required this.postId,
    required this.initialComments,
    this.loadFullComments,
    this.selectedCommentId,
    this.onCommentsUpdated,
  });

  @override
  State<ApiVoiceCommentListSheet> createState() =>
      _ApiVoiceCommentListSheetState();
}

class _ApiVoiceCommentListSheetState extends State<ApiVoiceCommentListSheet> {
  /// 시트의 높이를 설정하는 변수
  /// - 화면 높이의 55%로 설정하어, 댓글 리스트와 액션 바가 적절히 배치될 수 있도록 합니다.
  static const double _sheetHeightFactor = 0.55;

  /// 댓글 저장 직후 서버 응답에 id나 필요한 필드가 바로 안 들어올 때,
  /// 댓글 목록을 다시 조회해서 “방금 저장된 댓글”을 찾으려는 **최대 재시도 횟수**
  /// - 저장 API 응답이 불완전할 수 있는 상황을 대비합니다.
  /// - 이 횟수만큼 댓글 목록을 재조회해서 저장된 댓글이 나타나는지 확인합니다.
  static const int _savedCommentLookupAttempts = 4;

  /// 댓글 저장 직후 서버 응답에 id나 필요한 필드가 바로 안 들어올 때,
  /// 댓글 목록을 다시 조회해서 “방금 저장된 댓글”을 찾으려는 **재시도 간격 시간**
  /// - 저장 API 응답이 불완전할 수 있는 상황을 대비합니다.
  /// - 이 간격마다 댓글 목록을 재조회해서 저장된 댓글이 나타나는지 확인합니다.
  static const Duration _savedCommentLookupDelay = Duration(milliseconds: 180);

  /// 음성 댓글의 웨이브폼 데이터는 최대 30개 샘플로 줄여서 서버에 전송합니다.
  static const int _maxWaveformSamples = 30;

  /// 웨이브폼 데이터 인코딩/디코딩을 담당하는 공용 인스턴스입니다.
  static final WaveformCodec _waveformCodec = WaveformCodec();

  late final ScrollController _scrollController;

  /// 댓글 리스트 상태를 관리하는 변수입니다. API에서 제공하는 댓글 데이터를 앱 내부 모델로 변환하여 사용합니다.
  late List<Comment> _comments;

  final GlobalKey _sheetStackKey = GlobalKey(debugLabel: 'comment_sheet_stack');
  final GlobalKey _commentListViewportKey = GlobalKey(
    debugLabel: 'comment_list_viewport',
  );

  /// 댓글 키와 해당 댓글 행의 GlobalKey를 매핑하는 맵입니다. 댓글 스레드 상태와 팝업 앵커 계산에 사용됩니다.
  final Map<String, GlobalKey> _commentKeys = <String, GlobalKey>{};

  /// 펼쳐진 대댓글 스레드의 부모 댓글 키 집합입니다. 스레드 펼침 상태를 관리하는 데 사용됩니다.
  final Set<String> _expandedReplyParentKeys = <String>{};

  /// 댓글이 완전히 로드되어 스레드 상태로 갱신 중인지 여부를 나타내는 플래그입니다.
  bool _isHydratingComments = false;

  /// 특정 댓글 스레드를 수동으로 강조 표시하기 위한 키입니다.
  /// null이면 선택된 댓글 기준으로 자동 강조 표시합니다.
  String? _manuallyHighlightedThreadKey;

  /// 현재 대댓글 입력 모드로 진입한 상태에서, 답글 대상 댓글을 나타내는 변수입니다.
  /// null이면 대댓글 입력 모드가 아닌 상태입니다.
  Comment? _replyTargetComment;

  /// 카메라/미디어 첨부 시트에서 답글 대상 댓글을 참조하기 위한 변수입니다.
  /// 대댓글 입력 모드로 진입했을 때의 답글 대상을 참조합니다.
  Comment? _attachmentReplyTarget;

  /// 대댓글 입력 모드로 진입했는지 여부를 나타내는 플래그입니다.
  /// 이 플래그가 true인 상태에서 입력 필드에 텍스트가 없는 경우에도 대댓글 입력 모드가 유지됩니다.
  bool _isReplyDraftArmed = true;

  /// 텍스트 입력 모드로 진입했는지 여부를 나타내는 플래그입니다.
  bool _isTextInputMode = false;

  /// 첨부 기능 시트(카메라, 음성)가 열려있는지 여부를 나타내는 플래그입니다.
  bool _isOpeningAttachmentSheet = false;

  /// 텍스트 입력 모드 전환 시 새 입력창에 넘길 초기 답글 텍스트입니다.
  String _pendingInitialReplyText = '';

  /// 입력 위젯 교체 시 AnimatedSwitcher key를 갱신하는 세션 카운터입니다.
  int _textInputSession = 0;

  /// 인라인 액션 드로어가 열려있는 댓글의 키입니다.
  /// 한 번에 한 댓글의 드로어만 열리도록 관리합니다.
  String? _expandedActionCommentKey;
  Rect? _expandedActionAnchorRect;

  /// 현재 답글/첨부 흐름에서 참조해야 하는 활성 답글 대상을 반환합니다.
  Comment? get _activeReplyTarget =>
      _replyTargetComment ?? _attachmentReplyTarget;

  /// 현재 reply 대상 닉네임을 액션 바에서 바로 쓸 수 있게 정리합니다.
  String? get _activeReplyTargetName {
    final normalizedName = _activeReplyTarget?.nickname?.trim();
    if (normalizedName == null || normalizedName.isEmpty) {
      return null;
    }
    return normalizedName;
  }

  /// 답글 입력 상태를 기본값으로 되돌려 다음 액션으로 안전하게 전환합니다.
  void _resetReplyComposerState({bool clearAttachmentTarget = true}) {
    _replyTargetComment = null;
    if (clearAttachmentTarget) {
      _attachmentReplyTarget = null;
    }
    _isReplyDraftArmed = true;
    _isTextInputMode = false;
    _pendingInitialReplyText = '';
  }

  /// 인라인 액션 팝업 상태를 정리해 한 번에 하나의 메뉴만 유지합니다.
  void _clearExpandedActionState() {
    _expandedActionCommentKey = null;
    _expandedActionAnchorRect = null;
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _comments = widget.initialComments.toList();
    _expandSelectedReplyParentIfNeeded();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _hydrateFullCommentsIfNeeded();
    });

    if (widget.selectedCommentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedComment();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 시트는 partial 댓글로 먼저 열리고, 가능하면 뒤에서 full thread를 hydrate합니다.
  Future<void> _hydrateFullCommentsIfNeeded() async {
    final loader = widget.loadFullComments;
    if (loader == null) {
      return;
    }

    setState(() {
      _isHydratingComments = true;
    });

    try {
      final hydratedComments = await loader(widget.postId);
      if (!mounted) {
        return;
      }

      setState(() {
        _comments = hydratedComments.toList();
        _expandedReplyParentKeys.clear();
        _expandedActionCommentKey = null;
        _expandedActionAnchorRect = null;
        _expandSelectedReplyParentIfNeeded();
        _isHydratingComments = false;
      });
      _notifyCommentsUpdated();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _scrollToSelectedComment();
      });
    } catch (error) {
      debugPrint('댓글 full hydrate 실패(postId: ${widget.postId}): $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _isHydratingComments = false;
      });
    }
  }

  /// 선택 댓글이 있으면 시트가 열린 직후 해당 댓글을 하단 액션 바 위로 맞춰 스크롤합니다.
  void _scrollToSelectedComment() {
    if (widget.selectedCommentId == null) return;

    final targetComment = ApiCommentThreadService.selectedComment(
      widget.selectedCommentId,
      _comments,
    );
    if (targetComment == null) return;

    _scrollCommentAboveActionBar(targetComment, animated: false);
  }

  /// 선택된 대댓글이 보이도록 부모 스레드를 먼저 펼칩니다.
  void _expandSelectedReplyParentIfNeeded() {
    final targetComment = ApiCommentThreadService.selectedComment(
      widget.selectedCommentId,
      _comments,
    );
    if (targetComment == null || !targetComment.isReply) return;

    final parentComment = ApiCommentThreadService.findParentComment(
      targetComment,
      _comments,
    );
    if (parentComment == null) return;

    _expandedReplyParentKeys.add(_commentKeyId(parentComment));
  }

  /// 답글 입력 모드로 전환하고 포커스를 이동시켜 즉시 입력을 시작할 수 있게 합니다.
  void _showReplyInput({Comment? replyTarget}) {
    if (replyTarget != null &&
        (replyTarget.id == null || replyTarget.userId == null)) {
      _showSnackBar(tr('common.user_info_unavailable'));
      return;
    }

    setState(() {
      _replyTargetComment = replyTarget;
      _attachmentReplyTarget = replyTarget;
      _isReplyDraftArmed = true;
      _isTextInputMode = false;
      _pendingInitialReplyText = '';
      _clearExpandedActionState();
    });

    if (replyTarget != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _scrollCommentAboveActionBar(replyTarget);
      });
    }
  }

  /// 댓글 키는 스레드/선택/팝업 상태를 연결하는 안정적인 식별자입니다.
  String _commentKeyId(Comment comment) {
    return ApiCommentThreadService.commentKeyId(comment);
  }

  /// 댓글 행 GlobalKey를 재사용해 스크롤과 팝업 앵커 계산 대상 위젯을 추적합니다.
  GlobalKey _keyForComment(Comment comment) {
    return _commentKeys.putIfAbsent(
      _commentKeyId(comment),
      () => GlobalKey(debugLabel: 'comment_${_commentKeyId(comment)}'),
    );
  }

  /// 현재 로그인 사용자가 작성한 댓글인지 userId 기준으로 판별합니다.
  bool _isOwnedByCurrentUser(Comment comment) {
    final currentUserId = context.read<UserController>().currentUser?.id;
    return currentUserId != null &&
        comment.userId != null &&
        comment.userId == currentUserId;
  }

  /// 롱프레스된 댓글의 위치를 시트 좌표로 환산해 팝업 메뉴 앵커를 갱신합니다.
  Rect? _resolveCommentAnchorRect(Comment comment) {
    final stackContext = _sheetStackKey.currentContext;
    final commentContext = _keyForComment(comment).currentContext;
    if (stackContext == null || commentContext == null) {
      return null;
    }

    final stackBox = stackContext.findRenderObject() as RenderBox?;
    final commentBox = commentContext.findRenderObject() as RenderBox?;
    if (stackBox == null || commentBox == null) {
      return null;
    }

    final topLeft = stackBox.globalToLocal(
      commentBox.localToGlobal(Offset.zero),
    );
    return topLeft & commentBox.size;
  }

  /// 팝업 메뉴는 한 번에 한 댓글만 열리도록 현재 열린 댓글의 키와 앵커 위치를 함께 관리합니다.
  /// - 앵커 위치란? 팝업 메뉴가 열릴 때, 해당 댓글 행의 어느 위치를 기준으로 메뉴가 열릴지를 결정하는 좌표입니다.
  ///
  /// Parameters:
  /// - [comment]: 팝업 메뉴를 열고자 하는 댓글입니다. 이 댓글의 위치를 기준으로 메뉴가 열립니다.
  void _setExpandedActionComment(Comment comment) {
    final nextKey = _commentKeyId(comment); // 댓글의 고유 키를 생성합니다.

    // 댓글의 위치를 좌표로 환산해 앵커 위치를 계산합니다.
    // 반환값이 Rect 형태이며, Rect는 좌표와 크기를 포함하는 사각형을 나타냅니다.
    // 이 Rect는 팝업 메뉴가 열릴 때 기준이 되는 위치와 영역을 정의합니다.
    final nextAnchorRect = _resolveCommentAnchorRect(comment);
    if (nextAnchorRect == null || !mounted) {
      return;
    }

    if (_expandedActionCommentKey == nextKey &&
        _expandedActionAnchorRect == nextAnchorRect) {
      return;
    }

    setState(() {
      _expandedActionCommentKey = nextKey;
      _expandedActionAnchorRect = nextAnchorRect;
    });
  }

  /// 팝업 메뉴는 외부 탭, 스크롤, 액션 완료 시 즉시 닫힙니다.
  void _collapseExpandedActionComment() {
    if (_expandedActionCommentKey == null || !mounted) {
      return;
    }
    setState(() {
      _clearExpandedActionState();
    });
  }

  /// 특정 댓글이 액션 바 아래에 가려지지 않도록 리스트를 보정 스크롤합니다.
  Future<void> _scrollCommentAboveActionBar(
    Comment targetComment, {
    bool animated = true,
  }) async {
    if (!_scrollController.hasClients) {
      return;
    }

    final viewportContext = _commentListViewportKey.currentContext;
    final targetContext = _keyForComment(targetComment).currentContext;
    if (viewportContext == null || targetContext == null) {
      return;
    }

    final viewportBox = viewportContext.findRenderObject() as RenderBox?;
    final targetBox = targetContext.findRenderObject() as RenderBox?;
    if (viewportBox == null || targetBox == null) {
      return;
    }

    final viewportTopLeft = viewportBox.localToGlobal(Offset.zero);
    final targetTopLeft = targetBox.localToGlobal(Offset.zero);
    final viewportBottom = viewportTopLeft.dy + viewportBox.size.height;
    final targetBottom = targetTopLeft.dy + targetBox.size.height;
    final scrollDelta = targetBottom - viewportBottom;

    if (scrollDelta.abs() < 1) {
      return;
    }

    final nextOffset = (_scrollController.offset + scrollDelta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    if (animated) {
      await _scrollController.animateTo(
        nextOffset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      return;
    }

    _scrollController.jumpTo(nextOffset);
  }

  /// 기본 댓글 바의 중앙 탭으로 텍스트 입력 모드에 진입합니다.
  void _showTextInputComposer() {
    if (!_isReplyDraftArmed || _isTextInputMode) {
      return;
    }

    final replyTarget = _replyTargetComment;
    setState(() {
      _isTextInputMode = true;
      _textInputSession++;
    });
    if (replyTarget != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _scrollCommentAboveActionBar(replyTarget);
      });
    }
  }

  /// 답글 입력과 첨부 타겟 상태를 닫고 composer를 기본 상태로 되돌립니다.
  void _hideReplyInput() {
    if (!mounted) {
      return;
    }
    setState(() {
      _resetReplyComposerState();
      _clearExpandedActionState();
    });
    FocusScope.of(context).unfocus();
  }

  /// 텍스트 댓글 저장 후 재조회 매칭까지 마쳐 현재 스레드 상태에 반영합니다.
  Future<void> _submitTextComment(String text) async {
    try {
      final saveResult = await CommentSheetSubmissionService.submitTextComment(
        userController: context.read<UserController>(),
        commentController: context.read<CommentController>(),
        postId: widget.postId,
        text: text,
        replyTarget: _replyTargetComment,
        savedCommentLookupAttempts: _savedCommentLookupAttempts,
        savedCommentLookupDelay: _savedCommentLookupDelay,
        replyThreadParentId: (comment) =>
            ApiCommentThreadService.replyThreadParentId(comment, _comments),
        showSnackBar: _showSnackBar,
      );
      if (!mounted) {
        return;
      }
      _insertSavedComment(
        saveResult.savedComment,
        replyTarget: saveResult.replyTarget,
        currentUserProfileKey: saveResult.currentUserProfileKey,
      );
    } catch (_) {
      if (mounted) {
        _showSnackBar(tr('comments.save_failed'));
      }
      throw StateError('comment_save_unresolved');
    }
  }

  /// 카메라 시트에서 생성한 미디어를 현재 답글 스레드 또는 일반 댓글로 저장합니다.
  Future<void> _handleCameraPressed() async {
    final replyTarget = _activeReplyTarget;

    await _openAttachmentSheet<CommentCameraSheetResult>(
      openSheet: () {
        return showModalBottomSheet<CommentCameraSheetResult>(
          context: context,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.transparent,
          builder: (_) => const CommentCameraRecordingBottomSheetWidget(),
        );
      },

      onResult: (result) async {
        await _submitMediaComment(
          replyTarget: replyTarget,
          localFilePath: result.localFilePath,
          isVideo: result.isVideo,
        );
      },
    );
  }

  /// 녹음 시트에서 생성한 오디오를 현재 답글 스레드 또는 일반 댓글로 저장합니다.
  Future<void> _handleMicPressed() async {
    final replyTarget = _activeReplyTarget;

    await _openAttachmentSheet<CommentAudioSheetResult>(
      openSheet: () {
        return showModalBottomSheet<CommentAudioSheetResult>(
          context: context,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.transparent,
          builder: (_) => const CommentAudioRecordingBottomSheetWidget(),
        );
      },
      onResult: (result) async {
        /// 녹음 시트에서 반환된 오디오 결과를 사용해 댓글 저장 플로우로 연결합니다.
        await _submitAudioComment(
          replyTarget: replyTarget,
          audioPath: result.audioPath,
          waveformData: result.waveformData,
          durationMs: result.durationMs,
        );
      },
    );
  }

  /// 첨부 시트 중복 오픈을 막고, 결과가 있으면 상위 저장 플로우로 전달합니다.
  Future<void> _openAttachmentSheet<T>({
    required Future<T?> Function() openSheet,
    required Future<void> Function(T result) onResult,
  }) async {
    if (_isOpeningAttachmentSheet) {
      return;
    }

    _isOpeningAttachmentSheet = true;
    FocusScope.of(context).unfocus();

    try {
      final result = await openSheet();
      if (!mounted || result == null) {
        return;
      }
      await onResult(result);
    } finally {
      _isOpeningAttachmentSheet = false;

      // 시트가 닫힌 후에도 포커스가 남아있을 수 있어, 다음 프레임에서 포커스를 정리합니다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        FocusScope.of(context).unfocus();
      });
    }
  }

  /// 오디오 댓글을 저장합니다.
  /// - 녹음 시트에서 반환된 오디오 파일 경로, 웨이브폼 데이터, 지속 시간 정보를 사용해 댓글 저장 플로우로 연결합니다.
  ///
  /// Parameters:
  /// - [replyTarget]: 댓글이 답글로 달릴 대상 댓글입니다. null이면 일반 댓글로 저장됩니다.
  /// - [audioPath]: 녹음된 오디오 파일의 로컬 경로입니다.
  /// - [waveformData]: 오디오의 웨이브폼 데이터입니다. 시각화나 서버 저장에 사용됩니다.
  /// - [durationMs]: 오디오의 지속 시간입니다. 댓글 표시나 서버 저장에 사용됩니다.
  ///
  /// Returns:
  /// - 저장된 댓글을 현재 댓글 리스트에 반영합니다.
  Future<void> _submitAudioComment({
    required Comment? replyTarget,
    required String audioPath,
    required List<double> waveformData,
    required int durationMs,
  }) async {
    try {
      // 녹음 시트에서 반환된 오디오 정보를 사용해 댓글 저장 플로우로 연결합니다.
      final saveResult = await CommentSheetSubmissionService.submitAudioComment(
        userController: context.read<UserController>(),
        commentController: context.read<CommentController>(),
        mediaController: context.read<MediaController>(),
        waveformCodec: _waveformCodec,
        maxWaveformSamples: _maxWaveformSamples,
        postId: widget.postId,
        replyTarget: replyTarget,
        audioPath: audioPath,
        waveformData: waveformData,
        durationMs: durationMs,
        savedCommentLookupAttempts: _savedCommentLookupAttempts,
        savedCommentLookupDelay: _savedCommentLookupDelay,
        replyThreadParentId: (comment) =>
            ApiCommentThreadService.replyThreadParentId(comment, _comments),
        showSnackBar: _showSnackBar,
      );
      if (!mounted) {
        return;
      }
      // 저장된 댓글을 현재 댓글 리스트에 반영합니다.
      _insertSavedComment(
        saveResult.savedComment,
        replyTarget: saveResult.replyTarget,
        currentUserProfileKey: saveResult.currentUserProfileKey,
      );
    } catch (_) {
      if (mounted) {
        _showSnackBar(tr('comments.save_failed'));
      }
    }
  }

  /// 미디어 댓글을 저장합니다.
  /// - 카메라 시트에서 반환된 미디어 파일 경로와 유형 정보를 사용해 댓글 저장 플로우로 연결합니다.
  /// - 미디어 유형에 따라 사진 또는 동영상 댓글로 저장됩니다.
  ///
  /// Parameters:
  /// - [replyTarget]: 댓글이 답글로 달릴 대상 댓글입니다. null이면 일반 댓글로 저장됩니다.
  /// - [localFilePath]: 촬영된 미디어 파일의 로컬 경로입니다.
  /// - [isVideo]: 첨부된 미디어가 동영상인지 여부입니다. true면 동영상 댓글로, false면 사진 댓글로 저장됩니다.
  ///
  /// Returns:
  /// - 저장된 댓글을 현재 댓글 리스트에 반영합니다.
  Future<void> _submitMediaComment({
    required Comment? replyTarget,
    required String localFilePath,
    required bool isVideo,
  }) async {
    try {
      // 카메라 시트에서 반환된 미디어 정보를 사용해 댓글 저장 플로우로 연결합니다.
      final saveResult = await CommentSheetSubmissionService.submitMediaComment(
        userController: context.read<UserController>(),
        commentController: context.read<CommentController>(),
        mediaController: context.read<MediaController>(),
        postId: widget.postId,
        replyTarget: replyTarget,
        localFilePath: localFilePath,
        isVideo: isVideo,
        savedCommentLookupAttempts: _savedCommentLookupAttempts,
        savedCommentLookupDelay: _savedCommentLookupDelay,
        replyThreadParentId: (comment) =>
            ApiCommentThreadService.replyThreadParentId(comment, _comments),
        showSnackBar: _showSnackBar,
      );
      if (!mounted) {
        return;
      }
      _insertSavedComment(
        saveResult.savedComment,
        replyTarget: saveResult.replyTarget,
        currentUserProfileKey: saveResult.currentUserProfileKey,
      );
    } catch (_) {
      if (mounted) {
        _showSnackBar(tr('comments.save_failed'));
      }
    }
  }

  /// 저장된 댓글을 현재 댓글 리스트에 반영합니다.
  /// - API에서 반환된 댓글 데이터를 앱 내부 모델로 변환하여 리스트에 삽입합니다.
  /// - 대댓글인 경우, 부모 댓글의 replyCommentCount를 갱신하고 해당 스레드를 펼칩니다.
  ///
  /// Parameters:
  /// - [savedComment]: API에서 저장 후 반환된 댓글 데이터입니다. 앱 내부 모델로 변환하여 리스트에 반영됩니다.
  /// - [replyTarget]
  ///   - 답글이 달린 대상 댓글입니다.
  ///   - null이면 일반 댓글로 삽입됩니다.
  ///   - 대댓글인 경우, 부모 댓글의 replyCommentCount 갱신과 스레드 펼침이 함께 처리됩니다.
  /// - [currentUserProfileKey]: 현재 로그인한 사용자의 프로필 키입니다. 댓글 데이터 정규화 과정에서 사용됩니다.
  void _insertSavedComment(
    Comment savedComment, {
    required Comment? replyTarget,
    required String? currentUserProfileKey,
  }) {
    final normalizedComment =
        ApiCommentPersistenceService.normalizeCommentForThread(
          comment: savedComment,
          replyTarget: replyTarget,
          currentUserProfileKey: currentUserProfileKey,
          replyThreadParentId: (comment) =>
              ApiCommentThreadService.replyThreadParentId(comment, _comments),
        );

    final insertIndex = ApiCommentThreadService.resolveInsertIndex(
      _comments,
      replyTarget,
    );
    setState(() {
      if (replyTarget != null) {
        final parentComment = ApiCommentThreadService.findParentComment(
          replyTarget,
          _comments,
        );
        if (parentComment != null) {
          final parentIndex = ApiCommentThreadService.indexOfComment(
            _comments,
            parentComment,
          );
          if (parentIndex >= 0) {
            final currentParent = _comments[parentIndex];
            _comments[parentIndex] = currentParent.copyWith(
              replyCommentCount: (currentParent.replyCommentCount ?? 0) + 1,
            );
            _expandedReplyParentKeys.add(_commentKeyId(currentParent));
          }
        }
      }
      _comments.insert(insertIndex, normalizedComment);
      _resetReplyComposerState();
      _clearExpandedActionState();
    });
    _notifyCommentsUpdated();
  }

  /// 특정 스레드를 펼치고 해당 스레드를 수동 강조 대상으로 고정합니다.
  void _showRepliesForComment(Comment comment) {
    final parentComment = comment.isReply
        ? ApiCommentThreadService.findParentComment(comment, _comments)
        : comment;
    if (parentComment == null || !mounted) return;

    final parentKey = _commentKeyId(parentComment);
    setState(() {
      _expandedReplyParentKeys.add(parentKey);
      _manuallyHighlightedThreadKey = parentKey;
      _clearExpandedActionState();
    });
  }

  /// 특정 스레드를 접고, 수동 강조가 그 스레드였다면 함께 해제합니다.
  void _hideRepliesForComment(Comment comment) {
    final parentComment = comment.isReply
        ? ApiCommentThreadService.findParentComment(comment, _comments)
        : comment;
    if (parentComment == null || !mounted) return;

    final parentKey = _commentKeyId(parentComment);
    setState(() {
      _expandedReplyParentKeys.remove(parentKey);
      if (_manuallyHighlightedThreadKey == parentKey) {
        _manuallyHighlightedThreadKey = null;
      }
      _clearExpandedActionState();
    });
  }

  /// 댓글 작성자 신고는 기존 신고 바텀시트 흐름을 그대로 재사용합니다.
  Future<void> _reportCommentAuthor(Comment comment) async {
    await CommentSheetModerationService.reportCommentAuthor(
      context: context,
      collapseExpandedActionComment: _collapseExpandedActionComment,
      showSnackBar: _showSnackBar,
    );
  }

  /// 댓글 작성자 차단 후 피드/포스트 캐시를 함께 갱신해 화면 잔존 데이터를 정리합니다.
  Future<void> _blockCommentAuthor(Comment comment) async {
    await CommentSheetModerationService.blockCommentAuthor(
      context: context,
      comment: comment,
      userController: context.read<UserController>(),
      friendController: context.read<FriendController>(),
      feedDataManager: context.read<FeedDataManager>(),
      postController: context.read<PostController>(),
      collapseExpandedActionComment: _collapseExpandedActionComment,
    );
  }

  /// 댓글 삭제 성공 시 시트 목록과 controller 캐시를 같은 결과로 동기화합니다.
  Future<void> _deleteComment(Comment comment) async {
    await CommentSheetModerationService.deleteComment(
      comment: comment,
      commentController: context.read<CommentController>(),
      onDeleted: mounted
          ? () => _removeDeletedCommentFromLocalState(comment)
          : null,
      showSnackBar: _showSnackBar,
    );
  }

  /// 댓글 삭제 결과를 로컬 리스트에 반영하고, 부모 삭제 시 자식 스레드도 함께 정리합니다.
  void _removeDeletedCommentFromLocalState(Comment comment) {
    final deletedKey = _commentKeyId(comment);
    final deletedThreadId = ApiCommentThreadService.replyThreadParentId(
      comment,
      _comments,
    );

    setState(() {
      if (comment.isReply) {
        final parentComment = ApiCommentThreadService.findParentComment(
          comment,
          _comments,
        );
        if (parentComment != null) {
          final parentIndex = ApiCommentThreadService.indexOfComment(
            _comments,
            parentComment,
          );
          if (parentIndex >= 0) {
            final currentParent = _comments[parentIndex];
            _comments[parentIndex] = currentParent.copyWith(
              replyCommentCount: ((currentParent.replyCommentCount ?? 1) - 1)
                  .clamp(0, 1 << 20),
            );
          }
        }
        _comments.removeWhere((candidate) => candidate.id == comment.id);
      } else {
        _comments.removeWhere(
          (candidate) =>
              candidate.id == comment.id ||
              (candidate.isReply &&
                  deletedThreadId != null &&
                  candidate.threadParentId == deletedThreadId),
        );
        _expandedReplyParentKeys.remove(deletedKey);
      }

      if (_replyTargetComment?.id == comment.id ||
          ApiCommentThreadService.replyThreadParentId(
                _replyTargetComment,
                _comments,
              ) ==
              deletedThreadId) {
        _resetReplyComposerState();
      }
      if (_manuallyHighlightedThreadKey == deletedKey) {
        _manuallyHighlightedThreadKey = null;
      }
      _clearExpandedActionState();
    });

    context.read<CommentController>().replaceCommentsCache(
      postId: widget.postId,
      comments: _comments,
    );
    _notifyCommentsUpdated();
  }

  void _notifyCommentsUpdated() {
    widget.onCommentsUpdated?.call(List<Comment>.unmodifiable(_comments));
  }

  /// 시트 내부 상태 변화 메시지는 공통 스낵바 유틸로 일관되게 노출합니다.
  void _showSnackBar(String message) {
    SnackBarUtils.showSnackBar(context, message);
  }

  /// 댓글 시트 본문은 헤더, 리스트, 액션 바를 조합해 현재 댓글 상호작용 상태를 렌더링합니다.
  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * _sheetHeightFactor;
    final highlightedThreadKey = ApiCommentThreadService.highlightThreadKey(
      manualHighlightedThreadKey: _manuallyHighlightedThreadKey,
      selectedCommentId: widget.selectedCommentId,
      comments: _comments,
    );
    final visibleComments = ApiCommentThreadService.visibleComments(
      _comments,
      _expandedReplyParentKeys,
    );
    final expandedActionComment = _expandedActionCommentKey == null
        ? null
        : _comments.cast<Comment?>().firstWhere(
            (comment) => _commentKeyId(comment!) == _expandedActionCommentKey,
            orElse: () => null,
          );

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _collapseExpandedActionComment,
        child: Stack(
          key: _sheetStackKey,
          children: [
            Container(
              width: double.infinity,
              height: sheetHeight,
              decoration: BoxDecoration(
                color: const Color(0xFF1c1c1c),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24.8),
                  topRight: Radius.circular(24.8),
                ),
              ),
              padding: EdgeInsets.only(bottom: 10.sp),
              child: Column(
                children: [
                  SizedBox(height: 20.sp),
                  Text(
                    tr('comments.title', context: context),
                    style: TextStyle(
                      color: const Color(0xFFF8F8F8),
                      fontSize: 18.sp,
                      fontFamily: 'Pretendard Variable',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 15.sp),
                  if (_isHydratingComments)
                    const LinearProgressIndicator(
                      minHeight: 2,
                      color: Color(0xFFF8F8F8),
                      backgroundColor: Color(0xFF323232),
                    ),
                  ApiCommentSheetListView(
                    viewportKey: _commentListViewportKey,
                    scrollController: _scrollController,
                    comments: _comments,
                    visibleComments: visibleComments,
                    highlightedThreadKey: highlightedThreadKey,
                    expandedReplyParentKeys: _expandedReplyParentKeys,
                    expandedActionCommentKey: _expandedActionCommentKey,
                    commentKeyBuilder: _commentKeyId,
                    isCommentHighlighted: (comment, anchorKey) =>
                        ApiCommentThreadService.belongsToHighlightedThread(
                          comment: comment,
                          anchorKey: anchorKey,
                          comments: _comments,
                        ),
                    keyForComment: _keyForComment,
                    onScrollStarted: _collapseExpandedActionComment,
                    onLongPressComment: _setExpandedActionComment,
                    onReplyTap: (target) =>
                        _showReplyInput(replyTarget: target),
                    onHideRepliesTap: _hideRepliesForComment,
                    onViewMoreRepliesTap: _showRepliesForComment,
                  ),
                  // 액션 바는 댓글 리스트와 별도 레이어로 배치해, 스크롤과 입력 모드 전환 시에도 안정적으로 위치를 유지합니다.
                  ApiCommentSheetActionBar(
                    isTextInputMode: _isTextInputMode,
                    textInputSession: _textInputSession,
                    replyTargetId: _activeReplyTarget?.id,
                    replyTargetName: _activeReplyTargetName,
                    pendingInitialReplyText: _pendingInitialReplyText,
                    isReplyDraftArmed: _isReplyDraftArmed,
                    onCenterTap: _showTextInputComposer,
                    onCameraPressed: _handleCameraPressed,
                    onMicPressed: _handleMicPressed,
                    onSubmitText: _submitTextComment,
                    onEditingCancelled: _hideReplyInput,
                    onClearReplyTap: _hideReplyInput,
                  ),
                ],
              ),
            ),
            if (_expandedActionAnchorRect != null &&
                expandedActionComment != null)
              ApiCommentSheetActionPopup(
                anchorRect: _expandedActionAnchorRect!,
                isOwnedByCurrentUser: _isOwnedByCurrentUser(
                  expandedActionComment,
                ),
                onDelete: () => _deleteComment(expandedActionComment),
                onReport: () => _reportCommentAuthor(expandedActionComment),
                onBlock: () => _blockCommentAuthor(expandedActionComment),
              ),
          ],
        ),
      ),
    );
  }
}
