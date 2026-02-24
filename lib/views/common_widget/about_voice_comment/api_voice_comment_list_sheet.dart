import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../../api/controller/friend_controller.dart';
import '../../../api/controller/post_controller.dart';
import '../../../api/controller/user_controller.dart';
import '../../../api/models/comment.dart';
import '../../../api/controller/audio_controller.dart';
import '../../../utils/video_thumbnail_cache.dart';
import '../../about_feed/manager/feed_data_manager.dart';
import '../report/report_bottom_sheet.dart';

/// API 기반 음성 댓글 리스트 Bottom Sheet
///
/// Firebase 버전의 VoiceCommentListSheet와 동일한 디자인을 유지하면서
/// API Comment 모델을 사용합니다.
///
/// 주의: 현재 서버 API에서 comment.userProfile은 프로필 이미지 URL입니다.
/// 사용자 ID나 닉네임은 별도 필드가 없으므로 표시하지 않습니다.
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

    // 선택된 댓글이 있으면 스크롤 예약
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

  /// 선택된 댓글로 자동 스크롤
  void _scrollToSelectedComment() {
    if (widget.selectedCommentId == null) return;

    final targetHash = _selectedHashCode(widget.selectedCommentId);
    if (targetHash == null) return;

    // selectedCommentId는 "index_hashCode" 형식이지만, 이모지 댓글이 섞이면 index가 달라질 수 있어
    // hashCode 기준으로 찾습니다.
    final filteredComments = widget.comments.toList();
    final targetIndex = filteredComments.indexWhere(
      (comment) => comment.hashCode == targetHash,
    );
    if (targetIndex < 0) return;

    if (_scrollController.hasClients) {
      // 아이템 높이 추정 (각 댓글 행의 대략적인 높이 + separator)
      const itemHeight = 80.0;
      const separatorHeight = 12.0;
      final scrollOffset = targetIndex * (itemHeight + separatorHeight);

      // 선택된 댓글이 화면 중앙에 오도록 오프셋 조정
      final viewportHeight = _scrollController.position.viewportDimension;
      final centeredOffset =
          scrollOffset - (viewportHeight / 2) + (itemHeight / 2);

      // jumpTo를 사용하여 애니메이션 없이 즉시 중앙 위치로 이동
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
    // 텍스트/오디오/이모지 댓글 모두 표시
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

/// API 댓글 행 위젯
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
        return _buildEmojiRow(context); // 이모지 댓글
      case CommentType.text:
        return _buildTextRow(context); // 텍스트 댓글
      case CommentType.audio:
        return _buildAudioRow(context); // 음성 댓글
      case CommentType.photo:
        return _buildMediaRow(context); // 사진/비디오 댓글
      case CommentType.reply:
        return _buildTextRow(context); // 답글 댓글(텍스트 UI 재사용)
    }
  }

  /// 이모지 ID를 이모지 문자열로 매핑
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

  /// 이모지 댓글 UI
  Widget _buildEmojiRow(BuildContext context) {
    final profileUrl = comment.userProfileUrl ?? '';
    final userName = comment.nickname ?? '알 수 없는 사용자';
    final emoji = _emojiFromId(comment.emojiId);
    final currentUserId = context.read<UserController>().currentUser?.userId;
    final showActions = _canShowActions(currentUserId);

    final content = Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileImage(profileUrl),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  //  SizedBox(height: 8.h),
                  Text(emoji, style: TextStyle(fontSize: 22.sp)),
                ],
              ),
            ),
            if (showActions) _buildActionMenu(context),
            SizedBox(width: 10.w),
          ],
        ),
        SizedBox(height: 7.h),
        Row(
          children: [
            const Spacer(),
            Text(
              _formatRelativeTime(),
              style: TextStyle(
                color: const Color(0xFFC4C4C4),
                fontSize: 10.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
                letterSpacing: -0.40,
              ),
            ),
            SizedBox(width: 12.w),
          ],
        ),
      ],
    );

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

  /// 텍스트 댓글 UI
  Widget _buildTextRow(BuildContext context) {
    // userProfile은 프로필 이미지 URL
    final profileUrl = comment.userProfileUrl ?? '';
    final userName = comment.nickname ?? '알 수 없는 사용자';
    final currentUserId = context.read<UserController>().currentUser?.userId;
    final showActions = _canShowActions(currentUserId);

    final content = Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로필 이미지
            _buildProfileImage(profileUrl),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  // 텍스트 댓글 내용
                  Text(
                    comment.text ?? '',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            if (showActions) _buildActionMenu(context),
            SizedBox(width: 10.w),
          ],
        ),
        SizedBox(height: 7.h),
        Row(
          children: [
            const Spacer(),
            Text(
              _formatRelativeTime(),
              style: TextStyle(
                color: const Color(0xFFC4C4C4),
                fontSize: 10.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
                letterSpacing: -0.40,
              ),
            ),
            SizedBox(width: 12.w),
          ],
        ),
      ],
    );

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

  /// 음성 댓글 UI
  Widget _buildAudioRow(BuildContext context) {
    final profileUrl = comment.userProfileUrl ?? '';
    final userName = comment.nickname ?? '알 수 없는 사용자';
    final currentUserId = context.read<UserController>().currentUser?.userId;
    final showActions = _canShowActions(currentUserId);

    // waveformData 파싱 (String -> List<double>)
    final waveformData = _parseWaveformData(comment.waveformData);

    final content = Consumer<AudioController>(
      builder: (context, audioController, child) {
        final isPlaying = audioController.isUrlPlaying(comment.audioUrl ?? '');
        final progress = audioController.progress;
        final position = audioController.currentPosition;
        final duration = audioController.totalDuration;

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // 프로필 이미지
                _buildProfileImage(profileUrl),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      _ApiWaveformPlaybackBar(
                        isPlaying: isPlaying,
                        progress: isPlaying ? progress : 0.0,
                        onPlayPause: () async {
                          if (comment.audioUrl != null &&
                              comment.audioUrl!.isNotEmpty) {
                            if (isPlaying) {
                              await audioController.pause();
                            } else {
                              await audioController.play(comment.audioUrl!);
                            }
                          }
                        },
                        position: isPlaying ? position : Duration.zero,
                        duration: isPlaying
                            ? duration
                            : Duration(milliseconds: comment.duration ?? 0),
                        waveformData: waveformData,
                      ),
                    ],
                  ),
                ),
                if (showActions) _buildActionMenu(context),
                SizedBox(width: 10.w),
              ],
            ),
            SizedBox(height: 7.h),
            Row(
              children: [
                const Spacer(),
                Text(
                  _formatRelativeTime(),
                  style: TextStyle(
                    color: const Color(0xFFC4C4C4),
                    fontSize: 10.sp,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.40,
                  ),
                ),
                SizedBox(width: 12.w),
              ],
            ),
          ],
        );
      },
    );

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

  /// 사진/비디오 댓글 UI
  Widget _buildMediaRow(BuildContext context) {
    final profileUrl = comment.userProfileUrl ?? '';
    final userName = comment.nickname ?? '알 수 없는 사용자';
    final currentUserId = context.read<UserController>().currentUser?.userId;
    final showActions = _canShowActions(currentUserId);
    final mediaSource = _resolveMediaSource();

    if (mediaSource == null) {
      return _buildTextRow(context);
    }

    final isVideo = _isVideoMediaSource(mediaSource);
    final cacheKey = (comment.fileKey ?? '').trim().isEmpty
        ? mediaSource
        : comment.fileKey!;

    final content = Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileImage(profileUrl),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  _ApiCommentMediaPreview(
                    source: mediaSource,
                    isVideo: isVideo,
                    cacheKey: cacheKey,
                  ),
                  if ((comment.text ?? '').trim().isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    Text(
                      comment.text!.trim(),
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
            ),
            if (showActions) _buildActionMenu(context),
            SizedBox(width: 10.w),
          ],
        ),
        SizedBox(height: 7.h),
        Row(
          children: [
            const Spacer(),
            Text(
              _formatRelativeTime(),
              style: TextStyle(
                color: const Color(0xFFC4C4C4),
                fontSize: 10.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
                letterSpacing: -0.40,
              ),
            ),
            SizedBox(width: 12.w),
          ],
        ),
      ],
    );

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

  /// 프로필 이미지 빌더
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

  /// waveformData 문자열을 `List<double>`로 파싱
  List<double> _parseWaveformData(String? waveformString) {
    if (waveformString == null || waveformString.isEmpty) {
      return [];
    }

    // waveformString의 앞뒤 공백 제거
    final trimmed = waveformString.trim();
    if (trimmed.isEmpty) return [];

    try {
      // JSON 배열로 파싱 시도
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded.map((e) => (e as num).toDouble()).toList();
      }
    }
    // JSON 파싱 실패 시, 대괄호 및 공백 제거 후 쉼표/공백 기준으로 분리
    catch (e) {
      final sanitized = trimmed.replaceAll('[', '').replaceAll(']', '').trim();
      if (sanitized.isEmpty) return [];

      // 쉼표 또는 공백으로 분리
      final parts = sanitized
          .split(RegExp(r'[,\s]+'))
          .where((part) => part.isNotEmpty);

      try {
        // 각 부분을 double로 변환
        final values = parts.map((part) => double.parse(part)).toList();
        return values;
      } catch (_) {
        debugPrint('waveformData 파싱 실패: $e');
      }
    }

    return [];
  }

  /// 상대 시간 포맷 (createdAt이 없으므로 빈 문자열 반환)
  String _formatRelativeTime() {
    // Comment 모델에 createdAt이 없으므로 빈 문자열 반환
    // TODO: Comment 모델에 createdAt 추가 시 수정
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

  @override
  void initState() {
    super.initState();
    _refreshThumbnailFuture();
  }

  @override
  void didUpdateWidget(covariant _ApiCommentMediaPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.cacheKey != widget.cacheKey) {
      _refreshThumbnailFuture();
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

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 82.w,
        height: 82.w,
        child: widget.isVideo
            ? FutureBuilder<Uint8List?>(
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
              )
            : _buildImagePreview(),
      ),
    );
  }
}

/// API 버전 Waveform 재생 바
class _ApiWaveformPlaybackBar extends StatelessWidget {
  final bool isPlaying;
  final double progress;
  final Future<void> Function() onPlayPause;
  final Duration position;
  final Duration duration;
  final List<double> waveformData;

  const _ApiWaveformPlaybackBar({
    required this.isPlaying,
    required this.progress,
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
                    // 회색 배경 파형 (기본 흰색이지만 재생 시 회색으로)
                    GestureDetector(
                      onTap: onPlayPause,
                      child: _buildWaveformBase(
                        color: isPlaying
                            ? const Color(0xFF4A4A4A)
                            : Colors.white,
                        availableWidth: availableWidth,
                      ),
                    ),
                    // 흰색 진행 파형 (재생 중에만 표시)
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
      // 데이터가 없으면 기본 패턴 사용
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

    // 실제 waveformData 사용
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
