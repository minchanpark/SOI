import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../api_firebase/controllers/audio_controller.dart';
import '../../../api_firebase/controllers/comment_audio_controller.dart';
import '../../../api_firebase/models/photo_data_model.dart';

class FeedAudioManager {
  /// 오디오 재생/일시정지 토글
  Future<void> toggleAudio(MediaDataModel photo, BuildContext context) async {
    if (photo.audioUrl.isEmpty) {
      return;
    }

    try {
      await Provider.of<AudioController>(
        context,
        listen: false,
      ).toggleAudio(photo.audioUrl);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('음성 파일을 재생할 수 없습니다: $e'),
          backgroundColor: const Color(0xFF5A5A5A),
        ),
      );
    }
  }

  /// 모든 오디오 중지
  void stopAllAudio(BuildContext context) {
    // 1. 게시물 오디오 중지
    final audioController = Provider.of<AudioController>(
      context,
      listen: false,
    );
    audioController.stopAudio();

    // 2. 음성 댓글 오디오 중지
    final commentAudioController = Provider.of<CommentAudioController>(
      context,
      listen: false,
    );
    commentAudioController.stopAllComments();
  }
}
