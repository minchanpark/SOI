import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../api/models/post.dart';
import '../../../utils/format_utils.dart';
import '../../../utils/app_route_observer.dart';
import '../about_more_menu/more_menu_button_widget.dart';

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

  final LayerLink _likeButtonLink = LayerLink(); // 좋아요 버튼 위치 추적용

  // 좋아요 버튼 키 (위치 재조정용)
  // 좋아요 버튼의 위치를 추적하기 위한 키입니다.
  final GlobalKey _likeButtonKey = GlobalKey();

  // 좋아요 패널 키 (위치 재조정용)
  // 좋아요 패널의 위치를 추적하기 위한 키입니다.
  final GlobalKey _likePanelKey = GlobalKey();

  // 좋아요 패널 OverlayEntry
  // 패널이 열려있을 때만 값이 존재합니다.
  OverlayEntry? _likePanelEntry;
  Offset _likePanelClampedOffset = Offset.zero;
  late final AnimationController _likePanelController; // 좋아요 패널 애니메이션 컨트롤러
  late final Animation<double> _likePanelOpacity; // 좋아요 패널 투명도 애니메이션
  late final Animation<Offset> _likePanelSlide; // 좋아요 패널 슬라이드 애니메이션

  // 포인터 다운 위치 저장 --> 드래그 판단용
  // 드래그 제스처가 시작된 위치를 저장하여서 스크롤 제스처인지 판단하는 변수입니다.
  Offset? _pointerDownPosition;

  @override
  void initState() {
    super.initState();
    _likePanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );
    final curved = CurvedAnimation(
      parent: _likePanelController,
      curve: Curves.easeOut,
    );
    _likePanelOpacity = curved;
    _likePanelSlide = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(curved);
  }

  // 좋아요 패널 토글 메서드
  // 좋아요 패널의 열림/닫힘 상태를 반전시킵니다.
  void _toggleLikePanel() {
    if (_isLikePanelOpen) {
      _closeLikePanel();
      return;
    }
    setState(() => _isLikePanelOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showLikePanel());
  }

  // 좋아요 패널 닫기 메서드
  // 좋아요 패널이 열려있을 때만 닫습니다.
  void _closeLikePanel() {
    if (!_isLikePanelOpen) return;
    setState(() => _isLikePanelOpen = false);
    _hideLikePanel();
  }

  void _showLikePanel() {
    if (!mounted || _likePanelEntry != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);

    _likePanelClampedOffset = Offset.zero;
    _likePanelEntry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeLikePanel,
                child: const SizedBox.expand(),
              ),
              CompositedTransformFollower(
                link: _likeButtonLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.centerRight,
                followerAnchor: Alignment.centerRight,
                offset: const Offset(-8, 0) + _likePanelClampedOffset,
                child: FadeTransition(
                  opacity: _likePanelOpacity,
                  child: SlideTransition(
                    position: _likePanelSlide,
                    child: _LikeEmojiPanel(
                      key: _likePanelKey,
                      emojiBuilder: _emojiButton,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    overlay.insert(_likePanelEntry!);
    _likePanelController.forward(from: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _repositionLikePanel());
  }

  void _repositionLikePanel() {
    if (!mounted || _likePanelEntry == null) return;

    final overlayBox =
        Overlay.of(context, rootOverlay: true).context.findRenderObject()
            as RenderBox?;
    final targetBox =
        _likeButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final panelBox =
        _likePanelKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlayBox == null || targetBox == null || panelBox == null) return;

    final overlaySize = overlayBox.size;
    final safePadding = MediaQuery.of(context).padding;

    final targetTopLeft = targetBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final targetSize = targetBox.size;
    final panelSize = panelBox.size;
    if (panelSize.width <= 0) return;

    final desiredRight = targetTopLeft.dx + targetSize.width - 8;
    final desiredLeft = desiredRight - panelSize.width;

    final minLeft = safePadding.left + 8;
    final maxLeft = overlaySize.width - safePadding.right - 8 - panelSize.width;
    final clampedLeft = desiredLeft.clamp(minLeft, maxLeft);

    final dx = (clampedLeft - desiredLeft).toDouble();
    if (dx == _likePanelClampedOffset.dx) return;

    _likePanelClampedOffset = Offset(dx, 0);
    _likePanelEntry?.markNeedsBuild();
  }

  void _hideLikePanel() {
    final entry = _likePanelEntry;
    if (entry == null) return;
    _likePanelController.reverse().then((_) {
      if (!mounted) return;
      if (_isLikePanelOpen) return;
      _likePanelEntry?.remove();
      _likePanelEntry = null;
    });
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
    appRouteObserver.unsubscribe(this);
    _likePanelEntry?.remove();
    _likePanelEntry = null;
    _likePanelController.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    // 다른 페이지가 위에 올라오면(현재 화면이 가려지면) 패널을 닫아둠
    _closeLikePanel();
  }

  Widget _emojiButton(String emoji) {
    return _PressToEnlargeEmojiButton(
      emoji: emoji,
      onPressed: () {
        //TODO: commentController.createEmojiComment으로 이모지 댓글 생성
        _closeLikePanel();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _pointerDownPosition = event.position;
      },
      onPointerMove: (event) {
        if (!_isLikePanelOpen) return;
        final start = _pointerDownPosition;
        if (start == null) return;
        final dx = (event.position.dx - start.dx).abs();
        final dy = (event.position.dy - start.dy).abs();
        // 스크롤 제스처(세로 드래그)로 판단되면 슬라이더 닫기
        if (dy > 6 && dy > dx) {
          _pointerDownPosition = null; // 드래그 종료 처리
          _closeLikePanel(); // 패널 닫기
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

          // 좋아요(이모지) 버튼 (패널은 Overlay로 표시)
          CompositedTransformTarget(
            link: _likeButtonLink,
            child: GestureDetector(
              onTap: () {
                _toggleLikePanel();
                widget.onLikePressed?.call();
              },
              child: Container(
                key: _likeButtonKey,
                width: 33,
                height: 33,
                decoration: BoxDecoration(
                  color: const Color(0xFF323232),
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

class _LikeEmojiPanel extends StatelessWidget {
  const _LikeEmojiPanel({super.key, required this.emojiBuilder});

  final Widget Function(String emoji) emojiBuilder;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        height: 33,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF323232),
          borderRadius: BorderRadius.circular(16.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            emojiBuilder('😀'),
            const SizedBox(width: 15),
            emojiBuilder('😍'),
            const SizedBox(width: 15),
            emojiBuilder('😭'),
            const SizedBox(width: 15),
            emojiBuilder('😡'),
            const SizedBox(width: 21),
          ],
        ),
      ),
    );
  }
}

class _PressToEnlargeEmojiButton extends StatefulWidget {
  const _PressToEnlargeEmojiButton({
    required this.emoji,
    required this.onPressed,
  });

  final String emoji;
  final VoidCallback onPressed;

  @override
  State<_PressToEnlargeEmojiButton> createState() =>
      _PressToEnlargeEmojiButtonState();
}

class _PressToEnlargeEmojiButtonState
    extends State<_PressToEnlargeEmojiButton> {
  bool _isEnlarged = false;
  Timer? _longPressTimer;
  bool _isPointerDown = false;
  bool _didTriggerLongPress = false;

  void _setEnlarged(bool value) {
    if (_isEnlarged == value) return;
    setState(() => _isEnlarged = value);
  }

  void _onPointerDown(PointerDownEvent _) {
    _isPointerDown = true;
    _didTriggerLongPress = false;
    _longPressTimer?.cancel();
    _longPressTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || !_isPointerDown) return;
      _didTriggerLongPress = true;
      _setEnlarged(true);
    });
  }

  void _onPointerUp(PointerUpEvent _) {
    _longPressTimer?.cancel();
    final shouldFireTap = !_didTriggerLongPress;
    _isPointerDown = false;
    _didTriggerLongPress = false;
    _setEnlarged(false);
    if (shouldFireTap) widget.onPressed();
  }

  void _onPointerCancel(PointerCancelEvent _) {
    _longPressTimer?.cancel();
    _isPointerDown = false;
    _didTriggerLongPress = false;
    _setEnlarged(false);
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: SizedBox(
        width: 22,
        height: 22, // 레이아웃은 그대로
        child: Center(
          child: AnimatedScale(
            scale: _isEnlarged ? (40 / 22) : 1.0, // 22 -> 40 느낌으로 확대
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Text(widget.emoji, style: const TextStyle(fontSize: 22)),
          ),
        ),
      ),
    );
  }
}
