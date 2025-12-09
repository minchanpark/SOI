import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../api/models/post.dart';
import '../../../api/controller/audio_controller.dart';
import '../../../api/controller/media_controller.dart';
import '../../../api_firebase/controllers/comment_audio_controller.dart';

class FeedAudioManager {
  Future<void> toggleAudio(Post post, BuildContext context) async {
    final audioKey = post.audioUrl;
    if (audioKey == null || audioKey.isEmpty) return;

    try {
      var resolvedUrl = audioKey;
      final uri = Uri.tryParse(audioKey);
      if (uri == null || !uri.hasScheme) {
        final mediaController = Provider.of<MediaController>(
          context,
          listen: false,
        );
        resolvedUrl = await mediaController.getPresignedUrl(audioKey) ?? '';
      }

      if (resolvedUrl.isEmpty) {
        throw Exception('오디오 URL을 가져올 수 없습니다.');
      }

      await Provider.of<AudioController>(
        context,
        listen: false,
      ).togglePlayPause(resolvedUrl);
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
