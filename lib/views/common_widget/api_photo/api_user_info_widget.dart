import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
  final bool isLiked;
  final String? selectedEmoji;

  const ApiUserInfoWidget({
    super.key,
    required this.post,
    this.isCurrentUserPost = false,
    this.onDeletePressed,
    this.onLikePressed,
    this.onCommentPressed,
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

  static const Duration _likePanelDuration = Duration(milliseconds: 220);

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
    _pointerDownPosition = null;
    setState(() {
      // 좋아요 패널을 닫음
      _isLikePanelOpen = false;
    });

    if (_likePanelEntry == null) return;
    await _likePanelController.reverse();
    _likePanelEntry?.remove();
    _likePanelEntry = null;
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
              targetAnchor: Alignment.centerLeft,
              followerAnchor: Alignment.centerRight,
              // 버튼의 왼쪽에 패널을 붙이고, 약간의 간격을 둡니다.
              offset: const Offset(-8, 0),
              child: AnimatedBuilder(
                animation: _likePanelController,
                child: RepaintBoundary(
                  child: Container(
                    height: 33,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF323232),
                      borderRadius: BorderRadius.circular(16.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ApiEmojiButton(
                          emoji: '😀',
                          onPressed: () => _onEmojiPressed('😀'),
                        ),
                        const SizedBox(width: 15),
                        ApiEmojiButton(
                          emoji: '😍',
                          onPressed: () => _onEmojiPressed('😍'),
                        ),
                        const SizedBox(width: 15),
                        ApiEmojiButton(
                          emoji: '😭',
                          onPressed: () => _onEmojiPressed('😭'),
                        ),
                        const SizedBox(width: 15),
                        ApiEmojiButton(
                          emoji: '😡',
                          onPressed: () => _onEmojiPressed('😡'),
                        ),
                        const SizedBox(width: 21),
                      ],
                    ),
                  ),
                ),
                builder: (context, child) {
                  final value = _likePanelController.value;
                  return ClipRect(
                    child: Align(
                      alignment: Alignment.centerRight,
                      widthFactor: value,
                      child: Opacity(opacity: value, child: child),
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
      duration: _likePanelDuration,
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

  void _onEmojiPressed(String emoji) {
    // TODO: commentController.createEmojiComment으로 이모지 댓글 생성
    _closeLikePanel();
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
            child: GestureDetector(
              onTap: () {
                _toggleLikePanel();
                widget.onLikePressed?.call();
              },
              child: Container(
                width: 33,
                height: 33,
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
                    : Image.asset(
                        'assets/like_icon.png',
                        width: 25.38,
                        height: 25.38,
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
}
