import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../api_firebase/controllers/auth_controller.dart';
import '../../../api_firebase/controllers/photo_controller.dart';
import '../../../api_firebase/models/photo_data_model.dart';
import '../../../api_firebase/models/comment_record_model.dart';
import '../../common_widget/abput_photo/photo_card_widget_common.dart';

// 피드 페이지 빌더
// 사용자의 피드를 표시하는 위젯
class FeedPageBuilder extends StatelessWidget {
  final List<Map<String, dynamic>> photos;
  final bool hasMoreData;
  final bool isLoadingMore;
  final Map<String, Offset?> profileImagePositions;
  final Map<String, String> droppedProfileImageUrls;
  final Map<String, List<CommentRecordModel>> photoComments;
  final Map<String, String> userProfileImages;
  final Map<String, bool> profileLoadingStates;
  final Map<String, String> userNames;
  final Map<String, bool> voiceCommentActiveStates;
  final Map<String, bool> voiceCommentSavedStates;
  final Map<String, String> commentProfileImageUrls;

  // 콜백 함수들
  final Function(MediaDataModel) onToggleAudio;
  final Function(String) onToggleVoiceComment;
  final Function(String, String?, List<double>?, int?) onVoiceCommentCompleted;
  final Function(String, String) onTextCommentCompleted; // 텍스트 댓글 완료 콜백
  final Function(String) onVoiceCommentDeleted;
  final Function(String, Offset) onProfileImageDragged;
  final Future<void> Function(String) onSaveRequested; // 프로필 배치 저장
  final Function(String) onSaveCompleted;
  final Function(int) onDeletePhoto;
  final VoidCallback onLikePressed;
  final Function(int) onPageChanged;
  final VoidCallback onStopAllAudio;

  const FeedPageBuilder({
    super.key,
    required this.photos,
    required this.hasMoreData,
    required this.isLoadingMore,
    required this.profileImagePositions,
    required this.droppedProfileImageUrls,
    required this.photoComments,
    required this.userProfileImages,
    required this.profileLoadingStates,
    required this.userNames,
    required this.voiceCommentActiveStates,
    required this.voiceCommentSavedStates,
    required this.commentProfileImageUrls,
    required this.onToggleAudio,
    required this.onToggleVoiceComment,
    required this.onVoiceCommentCompleted,
    required this.onTextCommentCompleted, // 텍스트 댓글 완료 콜백 추가
    required this.onVoiceCommentDeleted,
    required this.onProfileImageDragged,
    required this.onSaveRequested,
    required this.onSaveCompleted,
    required this.onDeletePhoto,
    required this.onLikePressed,
    required this.onPageChanged,
    required this.onStopAllAudio,
  });

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: photos.length + (hasMoreData ? 1 : 0),
      onPageChanged: (index) {
        onPageChanged(index);
        onStopAllAudio();
      },
      itemBuilder: (context, index) {
        if (index >= photos.length) {
          // 로딩 인디케이터 또는 빈 공간
          return const SizedBox.shrink();
        }

        final photoData = photos[index];
        final MediaDataModel photo = photoData['photo'] as MediaDataModel;
        final String categoryName = photoData['categoryName'] as String;
        final String categoryId = photoData['categoryId'] as String;

        final authController = Provider.of<AuthController>(
          context,
          listen: false,
        );
        final currentUserId = authController.getUserId;
        final isOwner = currentUserId != null && currentUserId == photo.userID;

        return PhotoCardWidgetCommon(
          photo: photo,
          categoryName: categoryName,
          categoryId: categoryId,
          index: index,
          isOwner: isOwner,
          photoComments: photoComments,
          userProfileImages: userProfileImages,
          profileLoadingStates: profileLoadingStates,
          userNames: userNames,
          voiceCommentActiveStates: voiceCommentActiveStates,
          voiceCommentSavedStates: voiceCommentSavedStates,
          onToggleAudio: onToggleAudio,
          onToggleVoiceComment: onToggleVoiceComment,
          onVoiceCommentCompleted: onVoiceCommentCompleted,
          onTextCommentCompleted: onTextCommentCompleted, // 텍스트 댓글 콜백 전달
          onVoiceCommentDeleted: onVoiceCommentDeleted,
          onProfileImageDragged: onProfileImageDragged,
          onSaveRequested: onSaveRequested,
          onSaveCompleted: onSaveCompleted,
          onDeletePressed: () =>
              _handleDelete(context, index, categoryId, photo),
          onLikePressed: onLikePressed,
        );
      },
    );
  }

  // 사진 삭제 처리
  // 사용자가 사진을 삭제할 때 호출되는 메서드
  Future<void> _handleDelete(
    BuildContext context,
    int index,
    String categoryId,
    MediaDataModel photo,
  ) async {
    try {
      final photoController = Provider.of<PhotoController>(
        context,
        listen: false,
      );
      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final userId = authController.getUserId;
      if (userId == null) return;

      final success = await photoController.deletePhoto(
        categoryId: categoryId,
        photoId: photo.id,
        userId: userId,
      );

      if (success) {
        onDeletePhoto(index);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('사진이 삭제되었습니다.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('사진 삭제에 실패했습니다.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      throw Exception('사진 삭제 중 오류 발생: $e');
    }
  }
}
