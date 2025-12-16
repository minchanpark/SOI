import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../api/controller/comment_controller.dart';
import '../../../api/controller/user_controller.dart';
import '../../../api/models/post.dart';
import '../../../utils/format_utils.dart';
import '../../../utils/app_route_observer.dart';
import '../about_more_menu/more_menu_button_widget.dart';
import 'api_emoji_button_widget.dart';

/// API 기반 사용자 정보 표시 위젯 (아이디와 날짜)
///
/// Firebase 버전의 UserInfoWidget과 동일한 디자인을 유지하면서
/// Post 모델을 사용합니다.
class ApiUserInfoWidget extends StatefulWidget {
  final Post post;
  final bool isCurrentUserPost;
  final VoidCallback? onDeletePressed;
  final VoidCallback? onLikePressed;
  final VoidCallback? onCommentPressed;
  final Future<void> Function(int postId)? onCommentsReloadRequested;
  final bool isLiked;
  final String? selectedEmoji;

  const ApiUserInfoWidget({
    super.key,
    required this.post,
    this.isCurrentUserPost = false,
    this.onDeletePressed,
    this.onLikePressed,
    this.onCommentPressed,
    this.onCommentsReloadRequested,
    this.isLiked = false,
    this.selectedEmoji,
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
  late final AnimationController _likePanelController;

  static const Duration _likePanelOpenDuration = Duration(milliseconds: 300);
  static const Duration _likePanelCloseDuration = Duration(milliseconds: 300);
  static const double _likeButtonSize = 33;
  static const double _likePanelHeight = 33;

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
              showWhenUnlinked: false,
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

                  // 접히듯(widthFactor) 없이, 슬라이드 + 페이드만 적용합니다.
                  // 이 값(슬라이드 거리)을 조절하면 닫힐 때 우측 끝점 위치도 함께 바뀝니다.
                  final slideDistance = 7.0;

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
                            widget.onLikePressed?.call();
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
      duration: _likePanelOpenDuration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _likePanelEntry?.remove();
    _likePanelEntry = null;
    _likePanelController.dispose();
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() {
    // 다른 페이지가 위에 올라오면(현재 화면이 가려지면) 패널을 닫아둠
    _closeLikePanel();
  }

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

  Future<void> _onEmojiPressed(String emoji) async {
    final emojiId = _emojiIdFromEmoji(emoji);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final userId = context.read<UserController>().currentUser?.id;
    final commentController = context.read<CommentController>();
    await _closeLikePanel();
    if (emojiId == null) return;

    if (userId == null) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('로그인 정보를 찾을 수 없습니다.')),
      );
      return;
    }

    final result = await commentController.createEmojiComment(
      postId: widget.post.id,
      userId: userId,
      emojiId: emojiId,
    );

    if (!result.success) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('이모지 댓글 전송에 실패했습니다.')),
      );
      return;
    }

    await widget.onCommentsReloadRequested?.call(widget.post.id);
  }

  @override
  Widget build(BuildContext context) {
    // 전체 영역에 대한 포인터 이벤트 리스너
    return Listener(
      behavior: HitTestBehavior.translucent, // 투명 영역도 이벤트 수신
      // 포인터 다운 이벤트 처리
      onPointerDown: (event) {
        _pointerDownPosition = event.position; // 드래그 시작 위치 저장
      },
      // 포인터 이동 이벤트 처리
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
                    widget.onLikePressed?.call();
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

          // 더보기 (현재 사용자 소유 게시물일 때만)
          if (widget.isCurrentUserPost)
            MoreMenuButton(onDeletePressed: widget.onDeletePressed),
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
        alignment: Alignment.center,
        child: widget.selectedEmoji != null
            ? Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  widget.selectedEmoji!,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 25.38,
                    fontFamily: 'Pretendard Variable',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : Image.asset('assets/like_icon.png', width: 25.38, height: 25.38),
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
