import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../../api/controller/friend_controller.dart';
import '../../../api/controller/post_controller.dart';
import '../../../api/controller/user_controller.dart';
import '../../../api/models/comment.dart';
import '../../../api/controller/audio_controller.dart';
import '../../../utils/video_thumbnail_cache.dart';
import '../../about_feed/manager/feed_data_manager.dart';
import '../report/report_bottom_sheet.dart';

class ApiVoiceCommentListSheet extends StatefulWidget {
  final int postId;
  final List<Comment> comments;
  final String? selectedCommentId;

  const ApiVoiceCommentListSheet({
    super.key,
    required this.postId,
    required this.comments,
    this.selectedCommentId,
  });

  @override
  State<ApiVoiceCommentListSheet> createState() =>
      _ApiVoiceCommentListSheetState();
}

class _ApiVoiceCommentListSheetState extends State<ApiVoiceCommentListSheet> {
  late ScrollController _scrollController;

  int? _selectedHashCode(String? selectedCommentId) {
    if (selectedCommentId == null) return null;
    final parts = selectedCommentId.split('_');
    if (parts.length < 2) return null;
    return int.tryParse(parts.last);
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    if (widget.selectedCommentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedComment();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedComment() {
    if (widget.selectedCommentId == null) return;

    final targetHash = _selectedHashCode(widget.selectedCommentId);
    if (targetHash == null) return;

    final filteredComments = widget.comments.toList();
    final targetIndex = filteredComments.indexWhere(
      (comment) => comment.hashCode == targetHash,
    );
    if (targetIndex < 0) return;

    if (_scrollController.hasClients) {
      const itemHeight = 80.0;
      const separatorHeight = 12.0;
      final scrollOffset = targetIndex * (itemHeight + separatorHeight);

      final viewportHeight = _scrollController.position.viewportDimension;
      final centeredOffset =
          scrollOffset - (viewportHeight / 2) + (itemHeight / 2);

      _scrollController.jumpTo(
        centeredOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF323232),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24.8),
          topRight: Radius.circular(24.8),
        ),
      ),
      padding: EdgeInsets.only(top: 18.h, bottom: 18.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 3.h),
          Text(
            "공감",
            style: TextStyle(
              color: const Color(0xFFF8F8F8),
              fontSize: 18,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 19.h),
          _buildCommentList(),
        ],
      ),
    );
  }

  Widget _buildCommentList() {
    final filteredComments = widget.comments.toList();

    if (filteredComments.isEmpty) {
      return SizedBox(
        height: 120.h,
        child: Center(
          child: Text(
            '댓글이 없습니다',
            style: TextStyle(
              color: const Color(0xFF9E9E9E),
              fontSize: 16.sp,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Flexible(
      child: ListView.separated(
        controller: _scrollController,
        shrinkWrap: true,
        itemCount: filteredComments.length,
        separatorBuilder: (_, __) => SizedBox(height: 12.h),
        itemBuilder: (context, index) {
          final comment = filteredComments[index];
          final selectedHash = _selectedHashCode(widget.selectedCommentId);
          final isHighlighted =
              selectedHash != null && comment.hashCode == selectedHash;
          return _ApiCommentRow(comment: comment, isHighlighted: isHighlighted);
        },
      ),
    );
  }
}

class _ApiCommentRow extends StatelessWidget {
  final Comment comment;
  final bool isHighlighted;

  const _ApiCommentRow({required this.comment, this.isHighlighted = false});

  bool _canShowActions(String? currentUserId) {
    if (currentUserId == null || currentUserId.isEmpty) return false;
    if (comment.nickname == null || comment.nickname!.isEmpty) return false;
    return comment.nickname != currentUserId;
  }

  Future<void> _reportUser(BuildContext context) async {
    final result = await ReportBottomSheet.show(context);
    if (result == null) return;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('신고가 접수되었습니다. 신고 내용을 관리자가 확인 후, 판단 후에 처리하도록 하겠습니다.'),
        backgroundColor: Color(0xFF5A5A5A),
      ),
    );
  }

  Future<void> _blockUser(BuildContext context) async {
    final userController = context.read<UserController>();
    final friendController = context.read<FriendController>();
    final feedDataManager = context.read<FeedDataManager>();
    final postController = context.read<PostController>();
    final messenger = ScaffoldMessenger.of(context);
    final currentUser = userController.currentUser;
    if (currentUser == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr('common.login_required')),
          backgroundColor: const Color(0xFF5A5A5A),
        ),
      );
      return;
    }

    final shouldBlock = await _showBlockConfirmation(context);
    if (shouldBlock != true) return;
    if (!context.mounted) return;

    final nickname = comment.nickname ?? '';
    if (nickname.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr('common.user_info_unavailable')),
          backgroundColor: const Color(0xFF5A5A5A),
        ),
      );
      return;
    }

    final targetUser = await userController.getUserByNickname(nickname);
    if (targetUser == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr('common.user_info_unavailable')),
          backgroundColor: const Color(0xFF5A5A5A),
        ),
      );
      return;
    }

    final ok = await friendController.blockFriend(
      requesterId: currentUser.id,
      receiverId: targetUser.id,
    );
    if (!context.mounted) return;

    if (ok) {
      feedDataManager.removePostsByNickname(nickname);
      postController.notifyPostsChanged();
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr('common.block_success')),
          backgroundColor: const Color(0xFF5A5A5A),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr('common.block_failed')),
          backgroundColor: const Color(0xFF5A5A5A),
        ),
      );
    }
  }

  Future<bool?> _showBlockConfirmation(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xff323232),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 17.h),
              Text(
                '차단 하시겠습니까?',
                style: TextStyle(
                  color: const Color(0xFFF8F8F8),
                  fontSize: 19.78.sp,
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              SizedBox(
                height: 38.h,
                width: 344.w,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xfff5f5f5),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.2.r),
                    ),
                  ),
                  child: Text(
                    '예',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      fontSize: 17.8.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 13.h),
              SizedBox(
                height: 38.h,
                width: 344.w,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF323232),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.2.r),
                    ),
                  ),
                  child: Text(
                    '아니오',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w500,
                      fontSize: 17.8.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 30.h),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.white, size: 20.sp),
      color: const Color(0xFF323232),
      onSelected: (value) {
        if (value == 'report') {
          _reportUser(context);
        } else if (value == 'block') {
          _blockUser(context);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'report',
          child: Text(
            tr('common.report', context: context),
            style: TextStyle(color: Colors.white, fontSize: 14.sp),
          ),
        ),
        PopupMenuItem(
          value: 'block',
          child: Text(
            tr('common.block', context: context),
            style: TextStyle(color: Colors.white, fontSize: 14.sp),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (comment.type) {
      case CommentType.emoji:
        return _buildEmojiRow(context);
      case CommentType.text:
        return _buildTextRow(context);
      case CommentType.audio:
        return _buildAudioRow(context);
      case CommentType.photo:
        return _buildMediaRow(context);
      case CommentType.reply:
        return _buildTextRow(context);
    }
  }

  String get _profileUrl => comment.userProfileUrl ?? '';
  String get _userName => comment.nickname ?? '알 수 없는 사용자';

  bool _shouldShowActions(BuildContext context) {
    final currentUserId = context.read<UserController>().currentUser?.userId;
    return _canShowActions(currentUserId);
  }

  TextStyle _userNameStyle() => TextStyle(
    color: Colors.white,
    fontSize: 14.sp,
    fontFamily: 'Pretendard',
    fontWeight: FontWeight.w600,
  );

  TextStyle _relativeTimeStyle() => TextStyle(
    color: const Color(0xFFC4C4C4),
    fontSize: 10.sp,
    fontFamily: 'Pretendard',
    fontWeight: FontWeight.w500,
    letterSpacing: -0.40,
  );

  Widget _buildRelativeTimeRow() {
    return Row(
      children: [
        const Spacer(),
        Text(_formatRelativeTime(), style: _relativeTimeStyle()),
        SizedBox(width: 12.w),
      ],
    );
  }

  Widget _wrapRowContent(Widget content) {
    if (isHighlighted) {
      return Container(
        color: const Color(0xff000000).withValues(alpha: 0.23),
        padding: EdgeInsets.symmetric(horizontal: 27.w, vertical: 10.h),
        child: content,
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 27.w),
      child: content,
    );
  }

  Widget _buildCommentRowLayout({
    required BuildContext context,
    required Widget body,
    required bool showActions,
    double bodySpacing = 8,
  }) {
    return _wrapRowContent(
      Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileImage(_profileUrl),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_userName, style: _userNameStyle()),
                    if (bodySpacing > 0) SizedBox(height: bodySpacing.h),
                    body,
                  ],
                ),
              ),
              if (showActions) _buildActionMenu(context),
              SizedBox(width: 10.w),
            ],
          ),
          SizedBox(height: 7.h),
          _buildRelativeTimeRow(),
        ],
      ),
    );
  }

  String _emojiFromId(int? emojiId) {
    switch (emojiId) {
      case 0:
        return '😀';
      case 1:
        return '😍';
      case 2:
        return '😭';
      case 3:
        return '😡';
      default:
        return '❓';
    }
  }

  Widget _buildEmojiRow(BuildContext context) {
    return _buildCommentRowLayout(
      context: context,
      showActions: _shouldShowActions(context),
      bodySpacing: 0,
      body: Text(
        _emojiFromId(comment.emojiId),
        style: TextStyle(fontSize: 22.sp),
      ),
    );
  }

  Widget _buildTextCommentText(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white,
        fontSize: 14.sp,
        fontFamily: 'Pretendard',
        fontWeight: FontWeight.w400,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildTextRow(BuildContext context) {
    return _buildCommentRowLayout(
      context: context,
      showActions: _shouldShowActions(context),
      body: _buildTextCommentText(comment.text ?? ''),
    );
  }

  Widget _buildAudioRow(BuildContext context) {
    final waveformData = _parseWaveformData(comment.waveformData);
    final showActions = _shouldShowActions(context);

    return Consumer<AudioController>(
      builder: (context, audioController, child) {
        final isPlaying = audioController.isUrlPlaying(comment.audioUrl ?? '');
        return _buildCommentRowLayout(
          context: context,
          showActions: showActions,
          bodySpacing: 4,
          body: _ApiWaveformPlaybackBar(
            isPlaying: isPlaying,
            onPlayPause: () async {
              final audioUrl = comment.audioUrl;
              if (audioUrl == null || audioUrl.isEmpty) {
                return;
              }
              if (isPlaying) {
                await audioController.pause();
              } else {
                await audioController.play(audioUrl);
              }
            },
            position: isPlaying
                ? audioController.currentPosition
                : Duration.zero,
            duration: isPlaying
                ? audioController.totalDuration
                : Duration(milliseconds: comment.duration ?? 0),
            waveformData: waveformData,
          ),
        );
      },
    );
  }

  String? _resolveMediaSource() {
    final fileUrl = (comment.fileUrl ?? '').trim();
    if (fileUrl.isNotEmpty) {
      return fileUrl;
    }

    final fileKey = (comment.fileKey ?? '').trim();
    if (fileKey.isNotEmpty) {
      return fileKey;
    }
    return null;
  }

  bool _isVideoMediaSource(String source) {
    final normalized = source.split('?').first.split('#').first.toLowerCase();
    const videoExtensions = <String>[
      '.mp4',
      '.mov',
      '.m4v',
      '.avi',
      '.mkv',
      '.webm',
    ];
    return videoExtensions.any(normalized.endsWith);
  }

  Widget _buildMediaRow(BuildContext context) {
    final mediaSource = _resolveMediaSource();
    if (mediaSource == null) {
      return _buildTextRow(context);
    }

    final isVideo = _isVideoMediaSource(mediaSource);
    final cacheKey = (comment.fileKey ?? '').trim().isEmpty
        ? mediaSource
        : comment.fileKey!;
    final trimmedText = (comment.text ?? '').trim();

    return _buildCommentRowLayout(
      context: context,
      showActions: _shouldShowActions(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ApiCommentMediaPreview(
            source: mediaSource,
            isVideo: isVideo,
            cacheKey: cacheKey,
          ),
          if (trimmedText.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(
              trimmedText,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w400,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileImage(String? profileUrl) {
    return ClipOval(
      child: profileUrl != null && profileUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: profileUrl,
              width: 44.w,
              height: 44.w,
              memCacheHeight: (44 * 2).toInt(),
              memCacheWidth: (44 * 2).toInt(),
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 44.w,
                height: 44.w,
                color: const Color(0xFF4E4E4E),
              ),
              errorWidget: (context, url, error) => Container(
                width: 44.w,
                height: 44.w,
                color: const Color(0xFF4E4E4E),
                child: const Icon(Icons.person, color: Colors.white),
              ),
            )
          : Container(
              width: 44.w,
              height: 44.w,
              color: const Color(0xFF4E4E4E),
              child: const Icon(Icons.person, color: Colors.white),
            ),
    );
  }

  List<double> _parseWaveformData(String? waveformString) {
    if (waveformString == null || waveformString.isEmpty) {
      return [];
    }

    final trimmed = waveformString.trim();
    if (trimmed.isEmpty) return [];

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded.map((e) => (e as num).toDouble()).toList();
      }
    } catch (e) {
      final sanitized = trimmed.replaceAll('[', '').replaceAll(']', '').trim();
      if (sanitized.isEmpty) return [];

      final parts = sanitized
          .split(RegExp(r'[,\s]+'))
          .where((part) => part.isNotEmpty);

      try {
        final values = parts.map((part) => double.parse(part)).toList();
        return values;
      } catch (_) {
        debugPrint('waveformData 파싱 실패: $e');
      }
    }

    return [];
  }

  String _formatRelativeTime() {
    return '';
  }
}

class _ApiCommentMediaPreview extends StatefulWidget {
  final String source;
  final bool isVideo;
  final String cacheKey;

  const _ApiCommentMediaPreview({
    required this.source,
    required this.isVideo,
    required this.cacheKey,
  });

  @override
  State<_ApiCommentMediaPreview> createState() =>
      _ApiCommentMediaPreviewState();
}

class _ApiCommentMediaPreviewState extends State<_ApiCommentMediaPreview> {
  Future<Uint8List?>? _thumbnailFuture;
  VideoPlayerController? _videoController;
  Future<void>? _videoInitialization;
  bool _videoLoadFailed = false;
  bool _showPlayOverlay = true;

  @override
  void initState() {
    super.initState();
    _refreshPreviewState();
  }

  @override
  void didUpdateWidget(covariant _ApiCommentMediaPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.cacheKey != widget.cacheKey) {
      _refreshPreviewState();
    }
  }

  @override
  void dispose() {
    _disposeVideoController();
    super.dispose();
  }

  void _refreshPreviewState() {
    _showPlayOverlay = true;
    _refreshThumbnailFuture();
    if (widget.isVideo) {
      _initializeVideoController();
    } else {
      _disposeVideoController();
    }
  }

  void _refreshThumbnailFuture() {
    if (!widget.isVideo) {
      _thumbnailFuture = null;
      return;
    }

    final stableKey = VideoThumbnailCache.buildStableCacheKey(
      fileKey: widget.cacheKey,
      videoUrl: widget.source,
    );
    _thumbnailFuture = VideoThumbnailCache.getThumbnail(
      videoUrl: widget.source,
      cacheKey: stableKey,
    );
  }

  Future<void> _initializeVideoController() async {
    _disposeVideoController();
    _videoLoadFailed = false;
    _showPlayOverlay = true;

    final source = widget.source;
    final isLocal = _isLocalFile(source);

    VideoPlayerController? controller;
    try {
      if (isLocal) {
        final file = File(source);
        if (!await file.exists()) {
          if (!mounted) return;
          setState(() {
            _videoLoadFailed = true;
          });
          return;
        }
        controller = VideoPlayerController.file(file);
      } else {
        controller = VideoPlayerController.networkUrl(Uri.parse(source));
      }

      _videoController = controller;
      _videoInitialization = controller
          .initialize()
          .then((_) async {
            await controller?.setLooping(true);
            await controller?.setVolume(1.0);
            if (!mounted) return;
            setState(() {});
          })
          .catchError((_) {
            if (!mounted) return;
            setState(() {
              _videoLoadFailed = true;
              _showPlayOverlay = true;
            });
          });

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _videoLoadFailed = true;
        _showPlayOverlay = true;
      });
    }
  }

  void _disposeVideoController() {
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    _videoInitialization = null;
  }

  Future<void> _toggleVideoPlayback() async {
    final controller = _videoController;
    final initialization = _videoInitialization;
    if (controller == null || initialization == null) {
      return;
    }

    try {
      if (!controller.value.isInitialized) {
        await initialization;
      }
      if (!mounted || !controller.value.isInitialized) {
        return;
      }

      if (controller.value.isPlaying) {
        await controller.pause();
        if (!mounted) return;
        setState(() {
          _showPlayOverlay = true;
        });
      } else {
        await controller.play();
        if (!mounted) return;
        setState(() {
          _showPlayOverlay = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _videoLoadFailed = true;
        _showPlayOverlay = true;
      });
    }
  }

  bool _isLocalFile(String source) {
    final uri = Uri.tryParse(source);
    if (uri == null) {
      return false;
    }
    if (uri.hasScheme) {
      return uri.scheme == 'file';
    }
    return true;
  }

  Widget _buildImagePreview() {
    final source = widget.source;
    final isLocal = _isLocalFile(source);
    final file = File(source);

    if (isLocal) {
      if (!file.existsSync()) {
        return _buildPlaceholder();
      }
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    return CachedNetworkImage(
      imageUrl: source,
      cacheKey: widget.cacheKey,
      useOldImageOnUrlChange: true,
      fit: BoxFit.cover,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => _buildPlaceholder(),
      errorWidget: (_, __, ___) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return const ColoredBox(
      color: Color(0xFF4A4A4A),
      child: Center(
        child: Icon(Icons.image_not_supported, color: Colors.white70, size: 24),
      ),
    );
  }

  Widget _buildThumbnail({bool showPlayIcon = false}) {
    return FutureBuilder<Uint8List?>(
      future: _thumbnailFuture,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              Image.memory(bytes, fit: BoxFit.cover)
            else
              _buildPlaceholder(),
            if (showPlayIcon)
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 30,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildVideoPreview() {
    final controller = _videoController;
    final initialization = _videoInitialization;

    final videoContent =
        _videoLoadFailed || controller == null || initialization == null
        ? _buildThumbnail()
        : FutureBuilder<void>(
            future: initialization,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done ||
                  !controller.value.isInitialized) {
                return _buildThumbnail();
              }

              return FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              );
            },
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleVideoPlayback,
      child: Stack(
        fit: StackFit.expand,
        children: [
          videoContent,
          if (_showPlayOverlay)
            const Center(
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 30,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 82.w,
        height: 82.w,
        child: widget.isVideo ? _buildVideoPreview() : _buildImagePreview(),
      ),
    );
  }
}

class _ApiWaveformPlaybackBar extends StatelessWidget {
  final bool isPlaying;
  final Future<void> Function() onPlayPause;
  final Duration position;
  final Duration duration;
  final List<double> waveformData;

  const _ApiWaveformPlaybackBar({
    required this.isPlaying,
    required this.onPlayPause,
    required this.position,
    required this.duration,
    required this.waveformData,
  });

  @override
  Widget build(BuildContext context) {
    final totalMs = duration.inMilliseconds == 0 ? 1 : duration.inMilliseconds;
    final playedMs = position.inMilliseconds;
    final barProgress = (playedMs / totalMs).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF000000).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPlayPause,
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 25.sp,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    GestureDetector(
                      onTap: onPlayPause,
                      child: _buildWaveformBase(
                        color: isPlaying
                            ? const Color(0xFF4A4A4A)
                            : Colors.white,
                        availableWidth: availableWidth,
                      ),
                    ),
                    if (isPlaying)
                      ClipRect(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          widthFactor: barProgress,
                          child: _buildWaveformBase(
                            color: Colors.white,
                            availableWidth: availableWidth,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveformBase({
    required Color color,
    required double availableWidth,
  }) {
    const maxBars = 40;

    if (waveformData.isEmpty) {
      return SizedBox(
        width: availableWidth,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(maxBars, (i) {
            final h = (i % 5 + 4) * 3.0;
            return Container(
              width: (2.54).w,
              height: h,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      );
    }

    const minHeight = 4.0;
    const maxHeight = 20.0;

    final sampledData = _sampleWaveformData(waveformData, maxBars);

    return Container(
      width: availableWidth,
      padding: EdgeInsets.only(right: 10.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: sampledData.asMap().entries.map((entry) {
          final value = entry.value;
          final barHeight = minHeight + (value * (maxHeight - minHeight));

          return Container(
            width: (2.54).w,
            height: barHeight,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<double> _sampleWaveformData(List<double> data, int targetCount) {
    if (data.isEmpty) {
      return List.generate(targetCount, (i) => (i % 5 + 4) / 10.0);
    }

    if (data.length <= targetCount) {
      final sampled = <double>[];
      for (int i = 0; i < targetCount; i++) {
        final position = (i * (data.length - 1)) / (targetCount - 1);
        final index = position.floor();
        final fraction = position - index;

        if (index >= data.length - 1) {
          sampled.add(data.last.abs().clamp(0.0, 1.0));
        } else {
          final value1 = data[index].abs();
          final value2 = data[index + 1].abs();
          final interpolated = value1 + (value2 - value1) * fraction;
          sampled.add(interpolated.clamp(0.0, 1.0));
        }
      }
      return sampled;
    }

    final step = data.length / targetCount;
    final sampled = <double>[];

    for (int i = 0; i < targetCount; i++) {
      final index = (i * step).floor();
      if (index < data.length) {
        sampled.add(data[index].abs().clamp(0.0, 1.0));
      }
    }

    return sampled;
  }
}
