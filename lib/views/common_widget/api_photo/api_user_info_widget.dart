import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../api/models/post.dart';
import '../../../utils/format_utils.dart';
import '../about_more_menu/more_menu_button_widget.dart';

/// API 기반 사용자 정보 표시 위젯 (아이디와 날짜)
///
/// Firebase 버전의 UserInfoWidget과 동일한 디자인을 유지하면서
/// Post 모델을 사용합니다.
class ApiUserInfoWidget extends StatelessWidget {
  final Post post;
  final Map<String, String> userNames;
  final bool isCurrentUserPost;
  final VoidCallback? onDeletePressed;
  final VoidCallback? onLikePressed;
  final bool isLiked;

  const ApiUserInfoWidget({
    super.key,
    required this.post,
    required this.userNames,
    this.isCurrentUserPost = false,
    this.onDeletePressed,
    this.onLikePressed,
    this.isLiked = false,
  });

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
                  '@${userNames[post.userId] ?? post.userId}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontFamily: "Pretendard",
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.visible,
                ),
              ),
              Text(
                post.createdAt != null
                    ? FormatUtils.formatRelativeTime(post.createdAt!)
                    : '',
                style: TextStyle(
                  color: const Color(0xffcccccc),
                  fontSize: 14.sp,
                  fontFamily: "Pretendard",
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),

        // 좋아요 버튼 (추후 API 버전으로 구현 예정)
        // SizedBox(
        //   height: 50.h,
        //   child: ApiEmojiButton(postId: post.id, categoryId: categoryId),
        // ),

        // 댓글 버튼 (추후 API 버전으로 구현 예정)
        // IconButton(
        //   onPressed: () { ... },
        //   icon: Image.asset(
        //     'assets/comment_icon.png',
        //     width: (31.7).w,
        //     height: (31.7).h,
        //   ),
        // ),

        // 더보기 (현재 사용자 소유 게시물일 때만)
        if (isCurrentUserPost) MoreMenuButton(onDeletePressed: onDeletePressed),
        SizedBox(width: 13.w),
      ],
    );
  }
}
