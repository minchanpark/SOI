import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/controller/comment_audio_controller.dart';
import '../../../api/models/post.dart';
import '../../../api/controller/audio_controller.dart';
import '../../../api/controller/media_controller.dart';

class FeedAudioManager {
  Future<void> toggleAudio(Post post, BuildContext context) async {
    // async gap 이후에 context를 다시 참조하지 않기 위해 의존성들을 미리 확보합니다.
    final mediaController = context.read<MediaController>();
    final audioController = context.read<AudioController>();
    final messenger = ScaffoldMessenger.maybeOf(context);

    final audioKey = post.audioUrl;
    if (audioKey == null || audioKey.isEmpty) return;

    try {
      var resolvedUrl = audioKey;
      final uri = Uri.tryParse(audioKey);
      if (uri == null || !uri.hasScheme) {
        resolvedUrl = await mediaController.getPresignedUrl(audioKey) ?? '';
      }

      if (resolvedUrl.isEmpty) {
        throw Exception('오디오 URL을 가져올 수 없습니다.');
      }

      await audioController.togglePlayPause(resolvedUrl);
    } catch (e) {
      messenger?.showSnackBar(
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
