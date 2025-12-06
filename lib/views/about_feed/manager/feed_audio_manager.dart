import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../api/models/post.dart';
import '../../../api_firebase/controllers/audio_controller.dart';
import '../../../api_firebase/controllers/comment_audio_controller.dart';

class FeedAudioManager {
  Future<void> toggleAudio(Post post, BuildContext context) async {
    final audioUrl = post.audioUrl;
    if (audioUrl == null || audioUrl.isEmpty) return;

    try {
      await Provider.of<AudioController>(
        context,
        listen: false,
      ).toggleAudio(audioUrl);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('음성 파일을 재생할 수 없습니다: $e'),
          backgroundColor: const Color(0xFF5A5A5A),
        ),
      );
    }
  }

  void stopAllAudio(BuildContext context) {
    final audioController = Provider.of<AudioController>(
      context,
      listen: false,
    );
    audioController.stopRealtimeAudio();

    final commentAudioController = Provider.of<CommentAudioController>(
      context,
      listen: false,
    );
    commentAudioController.stopAllComments();
  }
}
