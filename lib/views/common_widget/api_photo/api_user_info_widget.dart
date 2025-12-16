import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

class _ApiUserInfoWidgetState extends State<ApiUserInfoWidget> with RouteAware {
  // 이모지 패널이 열려있는지 여부
  bool _isLikePanelOpen = false;

  // 포인터 다운 위치 저장 --> 드래그 판단용
  // 드래그 제스처가 시작된 위치를 저장하여서 스크롤 제스처인지 판단하는 변수입니다.
  Offset? _pointerDownPosition;

  // 좋아요 패널 토글 메서드
  // 좋아요 패널의 열림/닫힘 상태를 반전시킵니다.
  void _toggleLikePanel() {
    setState(() {
      // 좋아요 패널의 상태를 반전시킴
      // 좋아요 패널이 열려있으면 닫고, 닫혀있으면 엽니다.
      _isLikePanelOpen = !_isLikePanelOpen;
    });
  }

  // 좋아요 패널 닫기 메서드
  // 좋아요 패널이 열려있을 때만 닫습니다.
  void _closeLikePanel() {
    if (!_isLikePanelOpen) return;
    setState(() {
      // 좋아요 패널을 닫음
      _isLikePanelOpen = false;
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

          // 좋아요(이모지) 버튼 + (버튼 뒤로) 왼쪽 슬라이드 패널
          Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: 8,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: _isLikePanelOpen ? 1 : 0),
                  duration: 220.ms,
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return ClipRect(
                      child: Align(
                        alignment: Alignment.centerRight,
                        widthFactor: value,
                        child: Opacity(opacity: value, child: child),
                      ),
                    );
                  },
                  child: RepaintBoundary(
                    child: Container(
                      height: 33,
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF323232),
                        borderRadius: BorderRadius.circular(16.5),
                      ),

                      child: Row(
                        // mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ApiEmojiButton(
                            emoji: '😀',
                            onPressed: () => _onEmojiPressed('😀'),
                          ),
                          SizedBox(width: 15),
                          ApiEmojiButton(
                            emoji: '😍',
                            onPressed: () => _onEmojiPressed('😍'),
                          ),
                          SizedBox(width: 15),
                          ApiEmojiButton(
                            emoji: '😭',
                            onPressed: () => _onEmojiPressed('😭'),
                          ),
                          SizedBox(width: 15),
                          ApiEmojiButton(
                            emoji: '😡',
                            onPressed: () => _onEmojiPressed('😡'),
                          ),
                          SizedBox(width: 21),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  _toggleLikePanel();
                  widget.onLikePressed?.call();
                },
                child: Container(
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
            ],
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
