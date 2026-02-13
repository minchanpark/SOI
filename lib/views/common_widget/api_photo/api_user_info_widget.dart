import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../../api/controller/friend_controller.dart';
import '../../../api/controller/post_controller.dart';
import '../../../api/controller/user_controller.dart';
import '../../../api/models/post.dart';
import '../../../views/about_feed/manager/feed_data_manager.dart';
import '../../../utils/format_utils.dart';
import '../about_more_menu/more_menu_button_widget.dart';
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
  final Future<void> Function(ReportResult result)? onReportSubmitted;

  const ApiUserInfoWidget({
    super.key,
    required this.post,
    this.isCurrentUserPost = false,
    this.onDeletePressed,
    this.onCommentPressed,
    this.onReportSubmitted,
  });

  @override
  State<ApiUserInfoWidget> createState() => _ApiUserInfoWidgetState();
}

class _ApiUserInfoWidgetState extends State<ApiUserInfoWidget> {
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

        // 댓글 버튼
        IconButton(
          onPressed: widget.onCommentPressed,
          icon: Image.asset(
            'assets/comment_icon.png',
            width: (24.75),
            height: (24.75),
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
    );
  }
}
