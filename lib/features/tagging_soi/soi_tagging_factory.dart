import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:tagging_core/tagging_core.dart';

import '../../api/controller/comment_controller.dart';
import '../../api/controller/media_controller.dart';
import 'soi_tagging_comment_gateway.dart';
import 'soi_tagging_controller.dart';
import 'soi_tagging_save_delegate.dart';

/// SOI 앱 컨테이너에서 tagging_core 의존성을 한 번에 조립합니다.
class SoiTaggingFactory {
  const SoiTaggingFactory._();

  static SoiTaggingController createSessionController(BuildContext context) {
    final commentController = context.read<CommentController>();
    return SoiTaggingController(
      commentController: commentController,
      coreController: TaggingSessionController(
        queryPort: SoiTaggingQueryPort(commentController),
      ),
    );
  }

  static TagMutationPort createSaveDelegate(BuildContext context) {
    return SoiTaggingSaveDelegate(
      commentController: context.read<CommentController>(),
      mediaController: context.read<MediaController>(),
    );
  }
}
