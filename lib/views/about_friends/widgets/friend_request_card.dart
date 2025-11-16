import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../api_firebase/controllers/friend_request_controller.dart';
import '../../../api_firebase/models/friend_request_model.dart';

class FriendRequestCard extends StatelessWidget {
  final double scale;
  final Function(String, FriendRequestController) onAcceptRequest;
  final Function(String, FriendRequestController) onRejectRequest;

  const FriendRequestCard({
    super.key,
    required this.scale,
    required this.onAcceptRequest,
    required this.onRejectRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<FriendRequestController>(
      builder: (context, friendRequestController, child) {
        final receivedRequests = friendRequestController.receivedRequests;

        return SizedBox(
          width: (354).w,
          child: Card(
            clipBehavior: Clip.antiAliasWithSaveLayer,
            color: const Color(0xff1c1c1c),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // 친구 요청 리스트
                receivedRequests.isEmpty
                    ? SizedBox(
                        height: 132.h,
                        child: Center(
                          child: Text(
                            friendRequestController.isLoading
                                ? '친구 요청을 불러오는 중...'
                                : '받은 친구 요청이 없습니다',
                            style: TextStyle(
                              color: const Color(0xff666666),
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: receivedRequests.map((request) {
                          return _buildFriendRequestItem(
                            context,
                            scale,
                            request,
                            friendRequestController,
                          );
                        }).toList(),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 개별 친구 요청 아이템 위젯
  Widget _buildFriendRequestItem(
    BuildContext context,
    double scale,
    FriendRequestModel request,
    FriendRequestController controller,
  ) {
    final isProcessing = controller.isProcessingRequest(request.id);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: (18).w, vertical: (12).h),
      child: Row(
        children: [
          // 프로필 이미지
          CircleAvatar(
            radius: (22).w,
            backgroundColor: const Color(0xff323232),
            backgroundImage:
                (request.senderProfileImageUrl != null &&
                    request.senderProfileImageUrl!.isNotEmpty &&
                    (request.senderProfileImageUrl!.startsWith('http://') ||
                        request.senderProfileImageUrl!.startsWith('https://')))
                ? NetworkImage(request.senderProfileImageUrl!)
                : null,
            child:
                (request.senderProfileImageUrl == null ||
                    request.senderProfileImageUrl!.isEmpty)
                ? Text(
                    request.senderid.isNotEmpty
                        ? request.senderid[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: const Color(0xfff9f9f9),
                      fontSize: (16).sp,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
          SizedBox(width: (12).w),

          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.senderid.isNotEmpty ? request.senderid : '알 수 없는 사용자',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xffd9d9d9),
                    fontSize: (16).sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  request.message!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xffd9d9d9),
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),

          // 삭제/수락 버튼
          if (isProcessing) ...[
            SizedBox(
              width: (24).w,
              height: (24).h,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: const Color(0xfff9f9f9),
              ),
            ),
          ] else ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 삭제 버튼
                SizedBox(
                  width: 42.w,
                  height: 29.h,
                  child: ElevatedButton(
                    onPressed: () => onRejectRequest(request.id, controller),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff333333),
                      foregroundColor: const Color(0xff999999),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      padding: EdgeInsets.zero,
                      elevation: 0,
                    ),
                    child: Text(
                      '삭제',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                  ),
                ),
                SizedBox(width: (8).w),
                // 수락 버튼
                SizedBox(
                  width: 42.w,
                  height: 29.h,
                  child: ElevatedButton(
                    onPressed: () => onAcceptRequest(request.id, controller),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xfff9f9f9),
                      foregroundColor: const Color(0xff1c1c1c),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      padding: EdgeInsets.zero,
                      elevation: 0,
                    ),
                    child: Text(
                      '수락',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
