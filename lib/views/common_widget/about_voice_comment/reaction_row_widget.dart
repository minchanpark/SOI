// 리액션 행: 댓글 파형 레이아웃과 동일 구조, 가운데 파형 영역을 이모지 박스로 대체
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:soi/api_firebase/models/comment_record_model.dart';
import '../../../utils/format_utils.dart';

class ReactionRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final String emoji;
  final CommentRecordModel? comment;
  final String? userName; // 사용자 이름 직접 전달

  const ReactionRow({
    super.key,
    required this.data,
    this.emoji = '',
    this.comment,
    this.userName, // 추가
  });

  @override
  Widget build(BuildContext context) {
    final fallbackProfile = data['profileImageUrl'] as String? ?? '';
    final profileImageUrl = (comment?.profileImageUrl.isNotEmpty ?? false)
        ? comment!.profileImageUrl
        : fallbackProfile;

    final userId = comment?.recorderUser.isNotEmpty == true
        ? comment!.recorderUser
        : (data['uid'] as String? ?? '');

    final createdAt = data['createdAt'];
    final createdDate = createdAt is Timestamp
        ? createdAt.toDate()
        : DateTime.now();

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(
                child: profileImageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: profileImageUrl,
                        width: 44.w,
                        height: 44.w,
                        memCacheHeight: (44 * 2).toInt(),
                        memCacheWidth: (44 * 2).toInt(),
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 44.w,
                        height: 44.w,
                        color: const Color(0xFF4E4E4E),
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 사용자 이름 직접 표시 (FutureBuilder 제거)
                    Text(
                      userName ?? userId,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: 'Pretendard Variable',
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.40,
                      ),
                    ),
                    Container(
                      alignment: Alignment.centerRight,
                      child: Text(
                        emoji.isEmpty ? '😊' : emoji,
                        style: TextStyle(fontSize: 25.sp),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
            ],
          ),
          Row(
            children: [
              const Spacer(),
              Text(
                FormatUtils.formatRelativeTime(createdDate),
                style: TextStyle(
                  color: const Color(0xFFC5C5C5),
                  fontSize: 10,
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.40,
                ),
              ),
              SizedBox(width: 12.w),
            ],
          ),
        ],
      ),
    );
  }
}
