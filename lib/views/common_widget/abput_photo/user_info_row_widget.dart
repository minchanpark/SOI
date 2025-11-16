import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../api_firebase/models/photo_data_model.dart';
import '../../../utils/format_utils.dart';
import '../../../api_firebase/controllers/comment_record_controller.dart';
import '../about_like/like_button.dart';
import '../about_more_menu/more_menu_button_widget.dart';
import '../about_voice_comment/voice_comment_list_sheet.dart';
import 'package:provider/provider.dart';

/// 사용자 정보 표시 위젯 (아이디와 날짜)
/// 피드에서 사진 하단에 표시되는 사용자 닉네임과 날짜 정보를 담당합니다.
/// 단일 책임: 사용자 닉네임과 날짜 정보 표시를 담당
class UserInfoWidget extends StatelessWidget {
  final MediaDataModel photo;
  final Map<String, String> userNames;
  final bool isCurrentUserPhoto; // 현재 사용자 사진인지 여부
  final VoidCallback? onDeletePressed; // 삭제 콜백 (피드 갱신 위해 상위 전달)
  final VoidCallback? onLikePressed; // 좋아요 콜백 (추후 구현용)
  final bool isLiked; // 좋아요 상태 (간단 표시)

  const UserInfoWidget({
    super.key,
    required this.photo,
    required this.userNames,
    this.isCurrentUserPhoto = false,
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
                  '@${userNames[photo.userID] ?? photo.userID}',
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
                FormatUtils.formatRelativeTime(photo.createdAt),
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
        // 좋아요 버튼 (이모티콘 선택 기능 추가)
        SizedBox(
          height: 50.h,
          child: EmojiButton(photoId: photo.id, categoryId: photo.categoryId),
        ),

        IconButton(
          onPressed: () {
            final recordController = context.read<CommentRecordController>();
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) {
                return ChangeNotifierProvider.value(
                  value: recordController,
                  child: SizedBox(
                    height: 480.h,
                    child: VoiceCommentListSheet(
                      photoId: photo.id,
                      categoryId: photo.categoryId,
                    ),
                  ),
                );
              },
            );
          },
          icon: Image.asset(
            'assets/comment_icon.png',
            width: (31.7).w,
            height: (31.7).h,
          ),
        ),
        // 더보기 (현재 사용자 소유 사진일 때만)
        if (isCurrentUserPhoto)
          MoreMenuButton(onDeletePressed: onDeletePressed),
        SizedBox(width: 13.w),
      ],
    );
  }
}
