import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:flutter_reaction_button/flutter_reaction_button.dart';

import '../../../api_firebase/controllers/emoji_reaction_controller.dart';
import '../../../api_firebase/controllers/auth_controller.dart';
import '../../../api_firebase/models/emoji_reaction_model.dart';

class EmojiButton extends StatefulWidget {
  final String photoId;
  final String categoryId; // Firestore 경로 계산용

  const EmojiButton({
    super.key,
    required this.photoId,
    required this.categoryId,
  });

  @override
  State<EmojiButton> createState() => _EmojiButtonState();
}

class _EmojiButtonState extends State<EmojiButton> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final auth = context.read<AuthController>();
      final userId = auth.getUserId;
      if (userId != null && userId.isNotEmpty) {
        final reactionController = context.read<EmojiReactionController>();
        // 이미 메모리에 없으면 서버에서 로드
        if (reactionController.getPhotoReaction(widget.photoId) == null) {
          await reactionController.loadUserReactionForPhoto(
            categoryId: widget.categoryId,
            photoId: widget.photoId,
            userId: userId,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EmojiReactionController>(
      builder: (context, reactionController, child) {
        final selectedReaction = reactionController.getPhotoReaction(
          widget.photoId,
        );

        // flutter_reaction_button을 위한 Reaction 리스트 생성
        final reactions = EmojiConstants.availableEmojis.map((emoji) {
          return Reaction<EmojiReactionModel>(
            value: emoji,
            icon: Text(emoji.emoji, style: TextStyle(fontSize: 22.sp)),
          );
        }).toList();

        // 초기 선택된 리액션 찾기
        Reaction<EmojiReactionModel>? selectedReactionObj;
        if (selectedReaction != null) {
          try {
            selectedReactionObj = reactions.firstWhere(
              (r) => r.value?.emoji == selectedReaction.emoji,
            );
          } catch (_) {}
        }

        return ReactionButton<EmojiReactionModel>(
          onReactionChanged: (Reaction<EmojiReactionModel>? reaction) async {
            final auth = context.read<AuthController>();
            final userId = auth.getUserId;
            if (userId == null || userId.isEmpty) return;

            final currentReaction = reactionController.getPhotoReaction(
              widget.photoId,
            );

            final bool shouldRemove =
                reaction == null ||
                reaction.value == null ||
                (currentReaction != null &&
                    reaction.value?.emoji == currentReaction.emoji);

            if (shouldRemove) {
              // 리액션 제거
              reactionController.removePhotoReaction(
                categoryId: widget.categoryId,
                photoId: widget.photoId,
                userId: userId,
              );
            } else {
              // 리액션 설정
              String userHandle = '';
              String userName = '';
              String profileUrl = '';

              try {
                userHandle = await auth.getUserID();
              } catch (_) {}
              try {
                userName = await auth.getUserName();
              } catch (_) {}
              try {
                profileUrl = await auth.getUserProfileImageUrl();
              } catch (_) {}

              reactionController.setPhotoReaction(
                categoryId: widget.categoryId,
                photoId: widget.photoId,
                userId: userId,
                userHandle: userHandle,
                userName: userName,
                profileImageUrl: profileUrl,
                reaction: reaction.value!,
              );
            }
          },
          reactions: reactions,
          selectedReaction: selectedReactionObj,
          boxColor: const Color(0xFF2A2A2A),
          boxRadius: (13.56).r,
          boxPadding: EdgeInsets.only(left: 8.w, right: 12.w),
          boxElevation: 0,
          itemSize: Size(20.w, 33.h),
          itemsSpacing: 15,

          // 0.0 < itemScale < 1.0 범위 안에 있어야 함.
          itemScale: 0.9,
          direction: ReactionsBoxAlignment.rtl,

          // toggle을 false로 설정하면 탭으로 오버레이 표시
          toggle: false,
          child: Container(
            width: 33.w,
            height: 33.h,
            decoration: BoxDecoration(
              color: const Color(0xFF323232),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: selectedReaction != null
                ? Padding(
                    padding: EdgeInsets.only(top: 1.h),
                    child: Text(
                      selectedReaction.emoji,

                      style: TextStyle(
                        color: Colors.black,
                        fontSize: (25.38).sp,
                        fontFamily: 'Pretendard Variable',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : Image.asset(
                    'assets/like_icon.png',
                    width: (25.38).w,
                    height: (25.38).h,
                  ),
          ),
        );
      },
    );
  }
}
