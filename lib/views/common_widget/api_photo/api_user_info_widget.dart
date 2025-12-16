import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../api/models/post.dart';
import '../../../utils/format_utils.dart';
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

class _ApiUserInfoWidgetState extends State<ApiUserInfoWidget> {
  bool _isLikePanelOpen = false;

  void _toggleLikePanel() {
    setState(() {
      _isLikePanelOpen = !_isLikePanelOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
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

        // 좋아요(이모지) 버튼을 누르면 왼쪽으로 슬라이드되는 추가 위젯
        AnimatedSize(
          duration: 180.ms,
          curve: Curves.easeOut,
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: _isLikePanelOpen ? 140.w : 0),
            child: _isLikePanelOpen
                ? Container(
                        height: 33,
                        margin: EdgeInsets.only(right: 8.w),
                        padding: EdgeInsets.symmetric(horizontal: 10.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFF323232),
                          borderRadius: BorderRadius.circular(16.5),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('😀', style: TextStyle(fontSize: 18.sp)),
                            SizedBox(width: 6.w),
                            Text('😍', style: TextStyle(fontSize: 18.sp)),
                            SizedBox(width: 6.w),
                            Text('🔥', style: TextStyle(fontSize: 18.sp)),
                          ],
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 120.ms)
                      .slideX(
                        begin: 0.25,
                        end: 0,
                        duration: 200.ms,
                        curve: Curves.easeOutCubic,
                      )
                : const SizedBox.shrink(),
          ),
        ),

        // 좋아요(이모지) 버튼
        SizedBox(
          height: 50,
          child: GestureDetector(
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
                      padding: EdgeInsets.only(top: 1),
                      child: Text(
                        widget.selectedEmoji!,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: (25.38),
                          fontFamily: 'Pretendard Variable',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : Image.asset(
                      'assets/like_icon.png',
                      width: (25.38),
                      height: (25.38),
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
    );
  }
}
