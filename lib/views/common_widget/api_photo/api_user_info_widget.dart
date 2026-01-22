import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../../api/controller/comment_controller.dart';
import '../../../api/controller/friend_controller.dart';
import '../../../api/controller/post_controller.dart';
import '../../../api/controller/user_controller.dart';
import '../../../api/models/comment.dart';
import '../../../api/models/post.dart';
import '../../../views/about_feed/manager/feed_data_manager.dart';
import '../../../utils/format_utils.dart';
import '../../../utils/app_route_observer.dart';
import '../about_more_menu/more_menu_button_widget.dart';
import 'api_emoji_button_widget.dart';
import '../report/report_bottom_sheet.dart';

enum _UserAction { report, block }

/// API 기반 사용자 정보 표시 위젯 (아이디와 날짜)
///
/// Firebase 버전의 UserInfoWidget과 동일한 디자인을 유지하면서
/// Post 모델을 사용합니다.
class ApiUserInfoWidget extends StatefulWidget {
  final Post post;
  final bool isCurrentUserPost;
  final VoidCallback? onDeletePressed;

  final VoidCallback? onCommentPressed;
  final Future<void> Function(int postId)?
  onCommentsReloadRequested; // 댓글 새로고침 콜백
  final ValueChanged<String?>? onEmojiSelected; // 부모 상태(postId별 선택값) 즉시 반영용
  final bool isLiked;
  final String? selectedEmoji;
  final Future<void> Function(ReportResult result)? onReportSubmitted;

  const ApiUserInfoWidget({
    super.key,
    required this.post,
    this.isCurrentUserPost = false,
    this.onDeletePressed,

    this.onCommentPressed,
    this.onCommentsReloadRequested,
    this.onEmojiSelected,
    this.isLiked = false,
    this.selectedEmoji,
    this.onReportSubmitted,
  });

  @override
  State<ApiUserInfoWidget> createState() => _ApiUserInfoWidgetState();
}

class _ApiUserInfoWidgetState extends State<ApiUserInfoWidget>
    with RouteAware, SingleTickerProviderStateMixin {
  // 이모지 패널이 열려있는지 여부
  bool _isLikePanelOpen = false;

  // 포인터 다운 위치 저장 --> 드래그 판단용
  // 드래그 제스처가 시작된 위치를 저장하여서 스크롤 제스처인지 판단하는 변수입니다.
  Offset? _pointerDownPosition;

  final LayerLink _likeButtonLink = LayerLink(); // 이모지 버튼과 이모지 패널을 연결하기 위한 링크
  OverlayEntry? _likePanelEntry;

  late final AnimationController
  _likePanelController; // 이모지 패널 애니메이션을 제어하는 컨트롤러

  Future<void> _reportUser() async {
    if (!mounted) return;
    final result = await ReportBottomSheet.show(context);
    if (result == null) return;
    if (widget.onReportSubmitted != null) {
      await widget.onReportSubmitted!(result);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('신고가 접수되었습니다. 신고 내용을 관리자가 확인 후, 판단 후에 처리하도록 하겠습니다.'),
        backgroundColor: Color(0xFF5A5A5A),
      ),
    );
  }

  Future<void> _blockUser() async {
    final userController = context.read<UserController>();
    final currentUser = userController.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('common.login_required', context: context)),
          backgroundColor: const Color(0xFF5A5A5A),
        ),
      );
      return;
    }

    final shouldBlock = await _showBlockConfirmation();
    if (shouldBlock != true) return;

    final targetUser = await userController.getUserByNickname(
      widget.post.nickName,
    );
    if (targetUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('common.user_info_unavailable', context: context)),
          backgroundColor: const Color(0xFF5A5A5A),
        ),
      );
      return;
    }

    final friendController = context.read<FriendController>();
    final ok = await friendController.blockFriend(
      requesterId: currentUser.id,
      receiverId: targetUser.id,
    );
    if (!mounted) return;

    if (ok) {
      context.read<FeedDataManager>().removePostsByNickname(
        widget.post.nickName,
      );
      context.read<PostController>().notifyPostsChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('common.block_success', context: context)),
          backgroundColor: const Color(0xFF5A5A5A),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('common.block_failed', context: context)),
          backgroundColor: const Color(0xFF5A5A5A),
        ),
      );
    }
  }

  Future<bool?> _showBlockConfirmation() {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xff323232),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 17.h),
              Text(
                '차단 하시겠습니까?',
                style: TextStyle(
                  color: const Color(0xFFF8F8F8),
                  fontSize: 19.78.sp,
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              SizedBox(
                height: 38.h,
                width: 344.w,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xfff5f5f5),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.2.r),
                    ),
                  ),
                  child: Text(
                    '예',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      fontSize: 17.8.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 13.h),
              SizedBox(
                height: 38.h,
                width: 344.w,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF323232),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.2.r),
                    ),
                  ),
                  child: Text(
                    '아니오',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w500,
                      fontSize: 17.8.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 30.h),
            ],
          ),
        );
      },
    );
  }

  static const Duration _likePanelOpenDuration = Duration(
    milliseconds: 300,
  ); // 이모지 패널 열기 애니메이션 지속 시간

  static const Duration _likePanelCloseDuration = Duration(
    milliseconds: 300,
  ); // 이모지 패널 닫기 애니메이션 지속 시간

  static const double _likeButtonSize = 33; // 이모지 버튼 크기
  static const double _likePanelHeight = 33; // 이모지 패널 높이

  // 좋아요 패널 토글 메서드
  // 좋아요 패널의 열림/닫힘 상태를 반전시킵니다.
  void _toggleLikePanel() {
    if (_isLikePanelOpen) {
      _closeLikePanel();
    } else {
      _openLikePanel();
    }
  }

  // 좋아요 패널 닫기 메서드
  // 좋아요 패널이 열려있을 때만 닫습니다.
  Future<void> _closeLikePanel() async {
    if (!_isLikePanelOpen) return;
    _pointerDownPosition = null; // 드래그 위치 초기화
    if (_likePanelEntry == null) return;

    // 애니메이션을 역방향으로 재생하여 패널 닫기
    await _likePanelController.animateBack(
      0, // 애니메이션을 0으로 되돌림 --> 패널을 닫음
      duration: _likePanelCloseDuration, // 닫기 애니메이션 지속 시간
    );
    _likePanelEntry?.remove(); // 오버레이에서 패널 제거
    _likePanelEntry = null; // 참조 해제
    if (mounted) setState(() => _isLikePanelOpen = false);
  }

  void _openLikePanel() {
    if (_isLikePanelOpen) return;
    if (_likePanelEntry == null) {
      // Overlay가 없으면 패널을 띄울 수 없습니다.
      // (Overlay.maybeOf가 null을 반환하는 케이스가 있어서 Navigator overlay도 fallback)
      final overlay =
          Overlay.maybeOf(context, rootOverlay: true) ??
          Navigator.of(context, rootNavigator: true).overlay;
      if (overlay == null) return;

      // 좋아요 패널 오버레이 생성
      // 좋아요 패널을 오버레이로 생성하여 버튼 옆에 표시합니다.
      _likePanelEntry = OverlayEntry(
        builder: (context) {
          return Material(
            type: MaterialType.transparency,
            child: CompositedTransformFollower(
              link: _likeButtonLink, // 좋아요 버튼과 연결
              showWhenUnlinked: false, // 버튼이 사라지면 패널도 사라짐
              targetAnchor: Alignment.centerRight,
              followerAnchor: Alignment.centerRight,

              child: AnimatedBuilder(
                animation: _likePanelController,

                child: RepaintBoundary(child: _buildLikeOverlayPanel()),
                builder: (context, child) {
                  // 애니메이션 값에 따라 패널 위치와 투명도 조절
                  // 좋아요 패널이 열리고 닫히는 애니메이션을 구현합니다.
                  // value: 0.0 ~ 1.0
                  // 0.0일 때 완전히 닫힌 상태, 1.0일 때 완전히 열린 상태
                  final value = _likePanelController.value;

                  // 슬라이드 거리
                  // 패널이 열리고 닫힐 때 슬라이드되는 거리입니다.
                  // 값을 키우면, 패널이 닫히는 끝점이 오른쪽으로 더 이동합니다.
                  final slideDistance = 5.0;

                  // 슬라이드/페이드는 유지하면서, 패널의 우측 끝점을 버튼 쪽에서 살짝 왼쪽으로 당깁니다.
                  // 값을 키우면(+) 우측 끝점이 더 왼쪽으로 들어가서 버튼과 더 많이 겹칩니다.
                  final rightEdgePull = 6.0;

                  return SizedBox(
                    height: _likePanelHeight,
                    child: Stack(
                      alignment: Alignment.centerRight, // 좋아요 버튼 기준 우측 정렬
                      clipBehavior: Clip.none,
                      children: [
                        Opacity(
                          opacity: value,
                          child: Transform.translate(
                            // 패널이 열리고 닫힐 때 위치 조절
                            // 이 값으로 패널이 슬라이드되는 효과를 줍니다.
                            offset: Offset(
                              (1 - value) * slideDistance - rightEdgePull,
                              0,
                            ),
                            child: child,
                          ),
                        ),
                        _buildLikeButton(
                          onTap: () {
                            _toggleLikePanel();
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      );

      // 오버레이에 이모지 패널을 삽입
      overlay.insert(_likePanelEntry!);
    }

    if (!_isLikePanelOpen) {
      setState(() => _isLikePanelOpen = true);
    }
    _likePanelController.forward(from: 0);
  }

  @override
  void initState() {
    super.initState();
    _likePanelController = AnimationController(
      vsync: this,
      duration: _likePanelOpenDuration, // 열기 애니메이션 지속 시간
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      // Route 구독
      // Route를 구독하여서 페이지 전환을 감지합니다.
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _likePanelEntry?.remove(); // 오버레이에서 패널 제거
    _likePanelEntry = null; // 참조 해제

    // 애니메이션 컨트롤러 해제
    // 메모리 누수를 방지하기 위해 애니메이션 컨트롤러를 해제합니다.
    _likePanelController.dispose();

    // Route 구독 해제
    // RouteAware 믹스인을 사용하여 페이지 전환 시 패널을 닫기 위해 구독한 것을 해제합니다.
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() {
    // 다른 페이지가 위에 올라오면(현재 화면이 가려지면) 패널을 닫습니다.
    _closeLikePanel();
  }

  /// 이모지 문자열을 이모지 ID로 매핑하는 함수
  int? _emojiIdFromEmoji(String emoji) {
    switch (emoji) {
      case '😀':
        return 0;
      case '😍':
        return 1;
      case '😭':
        return 2;
      case '😡':
        return 3;
    }
    return null;
  }

  /// 내가 남긴 가장 최신의 이모지 댓글을 찾는 함수
  Comment? _findMyLatestEmojiComment({
    required List<Comment> comments,
    required String currentUserNickname,
  }) {
    // 댓글이 정렬되어 있다고 가정하고, 마지막(가장 최근) emoji 댓글을 찾습니다.
    for (final comment in comments.reversed) {
      if (comment.type != CommentType.emoji) continue;
      if (comment.nickname != currentUserNickname) continue;
      return comment;
    }
    return null;
  }

  /// 이모지 버튼이 눌렸을 때 호출되는 함수
  Future<void> _onEmojiPressed(String emoji) async {
    final emojiId = _emojiIdFromEmoji(emoji); // 이모지에 해당하는 ID 매핑
    final messenger = ScaffoldMessenger.maybeOf(context);
    final currentUser = context.read<UserController>().currentUser;
    final userId = currentUser?.id;
    final currentUserNickname = currentUser?.userId;
    final commentController = context.read<CommentController>();
    if (emojiId == null) return;

    // 탭하자마자 버튼 이모지가 바뀌도록, 서버 요청 전에 부모 캐시를 먼저 갱신합니다.
    final previousEmoji = widget.selectedEmoji;
    widget.onEmojiSelected?.call(emoji);

    await _closeLikePanel();
    if (userId == null) {
      // 로그인 정보가 없으면 원복
      widget.onEmojiSelected?.call(previousEmoji);
      messenger?.showSnackBar(
        const SnackBar(content: Text('로그인 정보를 찾을 수 없습니다.')),
      );
      return;
    }

    // 이전 이모지 댓글 삭제 여부 플래그
    var deletedOldEmoji = false;

    if (currentUserNickname != null) {
      // 기존 댓글 목록 조회
      final existingComments = await commentController.getComments(
        postId: widget.post.id,
      );

      // 내가 남긴 가장 최신의 이모지 댓글 찾기
      final existingEmojiComment = _findMyLatestEmojiComment(
        comments: existingComments,
        currentUserNickname: currentUserNickname,
      );

      // 같은 이모지를 다시 누른 경우는 대체/삭제하지 않습니다.
      if (existingEmojiComment != null &&
          existingEmojiComment.emojiId == emojiId) {
        return;
      }

      if (existingEmojiComment?.id != null) {
        // 기존 이모지 댓글이 있으면 삭제
        final deleted = await commentController.deleteComment(
          existingEmojiComment!.id!,
        );
        // 삭제 후 댓글 목록 즉시 갱신
        await widget.onCommentsReloadRequested?.call(widget.post.id);
        if (!deleted) {
          // 삭제 실패 시 기존 선택값으로 원복
          widget.onEmojiSelected?.call(previousEmoji);
          messenger?.showSnackBar(
            const SnackBar(content: Text('기존 이모지 삭제에 실패했습니다.')),
          );
          return;
        }
        deletedOldEmoji = true;
      }
    }

    // 이모지 댓글 생성 API 호출
    final result = await commentController.createEmojiComment(
      postId: widget.post.id,
      userId: userId,
      emojiId: emojiId,
    );

    if (!result.success) {
      // 생성 실패 시: 기존 이모지를 삭제했다면 선택값을 해제하고, 아니면 이전 값으로 원복합니다.
      widget.onEmojiSelected?.call(deletedOldEmoji ? null : previousEmoji);
      await widget.onCommentsReloadRequested?.call(widget.post.id);
      messenger?.showSnackBar(
        const SnackBar(content: Text('이모지 댓글 전송에 실패했습니다.')),
      );
      return;
    }

    // 댓글 목록 새로고침 요청
    // 댓글이 성공적으로 생성된 후, 댓글 목록을 새로고침합니다.
    await widget.onCommentsReloadRequested?.call(widget.post.id);
  }

  @override
  Widget build(BuildContext context) {
    // 전체 영역에 대한 포인터 이벤트 리스너
    return Listener(
      behavior: HitTestBehavior.translucent, // 투명 영역도 이벤트 수신
      // 포인터 다운 이벤트 처리
      // 포링터 다운 이벤트란, 사용자가 화면을 터치하거나 클릭했을 때 발생하는 이벤트입니다.
      onPointerDown: (event) {
        _pointerDownPosition = event.position; // 드래그 시작 위치 저장
      },
      // 포인터 이동 이벤트 처리
      // 포인터 이동 이벤트란, 사용자가 화면을 터치한 상태에서
      //  손가락을 움직이거나 마우스를 이동시킬 때 발생하는 이벤트입니다.
      onPointerMove: (event) {
        if (!_isLikePanelOpen) return; // 패널이 열려있을 때만 처리
        final start = _pointerDownPosition; // 드래그 시작 위치
        if (start == null) return; // 시작 위치가 없으면 무시
        final dx = (event.position.dx - start.dx).abs(); // 수평 이동 거리
        final dy = (event.position.dy - start.dy).abs(); // 수직 이동 거리

        // 스크롤 제스처(세로 드래그)로 판단되면 슬라이더 닫기
        if (dy > 6 && dy > dx) {
          _pointerDownPosition = null; // 드래그 종료 처리
          _closeLikePanel(); // 이모지 패널 닫기
        }
      },
      onPointerUp: (_) => _pointerDownPosition = null,
      onPointerCancel: (_) => _pointerDownPosition = null,
      child: Row(
        children: [
          SizedBox(width: 23.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 22.h,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '@${widget.post.nickName}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontFamily: "Pretendard Variable",
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.visible,
                  ),
                ),
                Text(
                  widget.post.createdAt != null
                      ? FormatUtils.formatRelativeTime(widget.post.createdAt!)
                      : '',
                  style: TextStyle(
                    color: const Color(0xffcccccc),
                    fontSize: 14.sp,
                    fontFamily: "Pretendard Variable",
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          // CompositedTransformTarget: 오버레이 위치 지정을 위한 위젯
          //   - 좋아요 버튼을 CompositedTransformTarget으로 감싸서
          //     좋아요 패널이 버튼 옆에 위치하도록 합니다.
          CompositedTransformTarget(
            link: _likeButtonLink,
            child: IgnorePointer(
              ignoring: _isLikePanelOpen,
              child: Opacity(
                opacity: _isLikePanelOpen ? 0 : 1,
                child: _buildLikeButton(
                  onTap: () {
                    _toggleLikePanel();
                  },
                ),
              ),
            ),
          ),

          // 댓글 버튼
          IconButton(
            onPressed: widget.onCommentPressed,
            icon: Image.asset(
              'assets/comment_icon.png',
              width: (31.7),
              height: (31.7),
            ),
          ),

          // 더보기
          if (widget.isCurrentUserPost)
            MoreMenuButton(onDeletePressed: widget.onDeletePressed)
          else
            PopupMenuButton<_UserAction>(
              icon: Icon(Icons.more_vert, color: Colors.white, size: 25.sp),
              color: const Color(0xFF323232),
              onSelected: (action) {
                switch (action) {
                  case _UserAction.report:
                    _reportUser();
                    break;
                  case _UserAction.block:
                    _blockUser();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _UserAction.report,
                  child: Text(
                    tr('common.report', context: context),
                    style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  ),
                ),
                PopupMenuItem(
                  value: _UserAction.block,
                  child: Text(
                    tr('common.block', context: context),
                    style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  ),
                ),
              ],
            ),
          SizedBox(width: 13.w),
        ],
      ),
    );
  }

  Widget _buildLikeButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _likeButtonSize,
        height: _likeButtonSize,
        decoration: const BoxDecoration(
          color: Color(0xFF323232),
          shape: BoxShape.circle,
        ),
        // 이모지와 아이콘 모두 정확히 중앙 정렬
        child: Center(
          child: widget.selectedEmoji != null
              ? FittedBox(
                  fit: BoxFit.contain,
                  child: Text(
                    widget.selectedEmoji!,
                    textScaler: TextScaler.noScaling,
                    // 이모지와 아이콘 모두 정확히 중앙 정렬
                    style: TextStyle(
                      fontSize: 25.38,
                      fontFamily: 'Pretendard Variable',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : Image.asset(
                  'assets/like_icon.png',
                  width: 25.38,
                  height: 25.38,
                ),
        ),
      ),
    );
  }

  Widget _buildLikeOverlayPanel() {
    return IgnorePointer(
      ignoring: !_isLikePanelOpen,
      child: Container(
        height: _likePanelHeight,
        padding: EdgeInsets.only(left: 10, right: _likeButtonSize + 3),
        decoration: BoxDecoration(
          color: const Color(0xFF323232),
          borderRadius: BorderRadius.circular(_likePanelHeight / 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ApiEmojiButton(emoji: '😀', onPressed: () => _onEmojiPressed('😀')),
            const SizedBox(width: 15),
            ApiEmojiButton(emoji: '😍', onPressed: () => _onEmojiPressed('😍')),
            const SizedBox(width: 15),
            ApiEmojiButton(emoji: '😭', onPressed: () => _onEmojiPressed('😭')),
            const SizedBox(width: 15),
            ApiEmojiButton(emoji: '😡', onPressed: () => _onEmojiPressed('😡')),
          ],
        ),
      ),
    );
  }
}
