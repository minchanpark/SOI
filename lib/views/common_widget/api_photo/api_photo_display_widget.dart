import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../api/controller/category_controller.dart' as api_category;
import '../../../api/controller/comment_controller.dart';
import '../../../api/controller/audio_controller.dart';
import '../../../api/models/comment.dart';
import '../../../api/models/post.dart';
import '../../../utils/position_converter.dart';
import '../../about_archiving/screens/archive_detail/api_category_photos_screen.dart';
import '../../common_widget/abput_photo/category_label_widget.dart';
import '../../common_widget/abput_photo/first_line_ellipsis_text.dart';
import 'api_audio_control_widget.dart';
import 'api_voice_comment_list_sheet.dart';
import 'pending_api_voice_comment.dart';
import 'package:soi/api/controller/media_controller.dart';

/// Firebase 버전의 PhotoDisplayWidget 디자인을 API 버전에서도 동일하게 유지
class ApiPhotoDisplayWidget extends StatefulWidget {
  final Post post;
  final int categoryId;
  final String categoryName;
  final bool isArchive;
  final Map<int, List<Comment>> postComments;
  final Function(int, Offset) onProfileImageDragged;
  final Function(Post) onToggleAudio;
  final Map<int, PendingApiVoiceComment> pendingVoiceComments;
  final Future<void> Function(int postId)? onCommentsReloadRequested;

  const ApiPhotoDisplayWidget({
    super.key,
    required this.post,
    required this.categoryId,
    required this.categoryName,
    this.isArchive = false,
    required this.postComments,
    required this.onProfileImageDragged,
    required this.onToggleAudio,
    this.pendingVoiceComments = const {},
    this.onCommentsReloadRequested,
  });

  @override
  State<ApiPhotoDisplayWidget> createState() => _ApiPhotoDisplayWidgetState();
}

class _ApiPhotoDisplayWidgetState extends State<ApiPhotoDisplayWidget> {
  static const double _avatarSize = 27.0;
  static const double _avatarRadius = 13.5;
  static const double _imageWidth = 354.0;
  static const double _imageHeight = 500.0;

  String? _selectedCommentKey;
  int? _selectedCommentId;
  Offset? _selectedCommentPosition;
  bool _showActionOverlay = false;
  bool _isShowingComments = false;
  bool _autoOpenedOnce = false;
  bool _isCaptionExpanded = false;
  String? _uploaderProfileImageUrl;
  bool _isProfileLoading = false;
  late final MediaController _mediaController;

  List<Comment> get _postComments =>
      widget.postComments[widget.post.id] ?? const <Comment>[];

  bool get _hasComments => _postComments.isNotEmpty;

  bool get _hasCaption => widget.post.content?.isNotEmpty ?? false;

  String? postImageUrl;

  @override
  void initState() {
    super.initState();
    _isShowingComments = _hasComments;
    _mediaController = Provider.of<MediaController>(context, listen: false);
    _scheduleProfileLoad(widget.post.userProfileImageKey);
    if (widget.post.postFileKey?.isNotEmpty ?? false) {
      _loadPostImage(widget.post.postFileKey!);
    } else {
      postImageUrl = null;
    }
  }

  @override
  void didUpdateWidget(covariant ApiPhotoDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_hasComments && !_autoOpenedOnce) {
      setState(() {
        _isShowingComments = true;
        _autoOpenedOnce = true;
      });
    }
    if (oldWidget.post.userProfileImageKey != widget.post.userProfileImageKey) {
      _scheduleProfileLoad(widget.post.userProfileImageKey);
    }
    if (oldWidget.post.postFileKey != widget.post.postFileKey) {
      _loadPostImage(widget.post.postFileKey!);
    }
  }

  Future<void> _loadPostImage(String key) async {
    if (widget.post.postFileKey == null || widget.post.postFileKey!.isEmpty) {
      setState(() {
        postImageUrl = null;
      });
      return;
    }

    try {
      final url = await _mediaController.getPresignedUrl(key);
      if (!mounted) return;
      setState(() {
        postImageUrl = url;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        postImageUrl = null;
      });
    }
  }

  List<double>? _parseWaveformData(String? waveformString) {
    if (waveformString == null || waveformString.isEmpty) {
      return null;
    }

    final trimmed = waveformString.trim();
    if (trimmed.isEmpty) return null;

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded.map((e) => (e as num).toDouble()).toList();
      }
    } catch (_) {
      final sanitized = trimmed.replaceAll('[', '').replaceAll(']', '').trim();
      if (sanitized.isEmpty) return null;
      final parts = sanitized
          .split(RegExp(r'[,\s]+'))
          .where((part) => part.isNotEmpty);
      try {
        final values = parts.map((part) => double.parse(part)).toList();
        return values.isEmpty ? null : values;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> _loadProfileImage(String? key) async {
    if (key == null || key.isEmpty) {
      setState(() {
        _uploaderProfileImageUrl = null;
        _isProfileLoading = false;
      });
      return;
    }

    setState(() => _isProfileLoading = true);
    try {
      final url = await _mediaController.getPresignedUrl(key);
      if (!mounted) return;
      setState(() {
        _uploaderProfileImageUrl = url;
        _isProfileLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uploaderProfileImageUrl = null;
        _isProfileLoading = false;
      });
    }
  }

  void _scheduleProfileLoad(String? key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadProfileImage(key);
      }
    });
  }

  /// 미디어(이미지 또는 비디오) 콘텐츠 빌드
  Widget _buildMediaContent() {
    if (widget.post.hasImage) {
      return CachedNetworkImage(
        imageUrl: postImageUrl ?? '',
        width: _imageWidth.w,
        height: _imageHeight.h,
        fit: BoxFit.cover,
        memCacheWidth: (354 * 2).round(),
        maxWidthDiskCache: (354 * 2).round(),
        placeholder: (context, url) => Shimmer.fromColors(
          baseColor: Colors.grey[800]!,
          highlightColor: Colors.grey[600]!,
          child: Container(
            width: _imageWidth.w,
            height: _imageHeight.h,
            color: Colors.grey[800],
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: _imageWidth.w,
          height: _imageHeight.h,
          color: Colors.grey[800],
          child: Icon(Icons.broken_image, color: Colors.grey[600], size: 50.w),
        ),
      );
    }

    return Container(
      width: _imageWidth.w,
      height: _imageHeight.h,
      color: Colors.grey[800],
      child: Icon(
        Icons.image_not_supported,
        color: Colors.grey[600],
        size: 50.w,
      ),
    );
  }

  /// 댓글의 프로필 이미지를 위치에 맞게 배치
  List<Widget> _buildCommentAvatars() {
    if (!_isShowingComments) return const [];

    final filteredComments = _postComments
        .where(
          (c) =>
              (c.type == CommentType.text || c.type == CommentType.audio) &&
              c.hasLocation,
        )
        .toList();

    final actualSize = Size(_imageWidth.w, _imageHeight.h);

    return List<Widget>.generate(filteredComments.length, (index) {
      final comment = filteredComments[index];
      final key = '${index}_${comment.hashCode}';
      final relative = Offset(
        comment.locationX ?? 0.5,
        comment.locationY ?? 0.5,
      );
      final absolute = PositionConverter.toAbsolutePosition(
        relative,
        actualSize,
      );
      final clamped = PositionConverter.clampPosition(absolute, actualSize);
      final hideOther =
          _showActionOverlay &&
          _selectedCommentKey != null &&
          key != _selectedCommentKey;
      if (hideOther) {
        return const SizedBox.shrink();
      }

      final isSelected = _selectedCommentKey == key;

      return Positioned(
        left: clamped.dx - _avatarRadius,
        top: clamped.dy - _avatarRadius,
        child: GestureDetector(
          onTap: () => _openCommentSheet(key),
          onLongPress: () => _handleCommentLongPress(
            key: key,
            commentId: comment.id,
            position: clamped,
          ),
          child: _buildCircleAvatar(
            imageUrl: comment.userProfile,
            size: _avatarSize,
            showBorder: isSelected,
            borderColor: Colors.white,
          ),
        ),
      );
    });
  }

  /// 업로드 중인 음성 댓글 마커 빌드
  Widget? _buildPendingMarker() {
    final pending = widget.pendingVoiceComments[widget.post.id];
    if (pending == null || pending.relativePosition == null) {
      return null;
    }

    final actualSize = Size(_imageWidth.w, _imageHeight.h);
    final absolute = PositionConverter.toAbsolutePosition(
      pending.relativePosition!,
      actualSize,
    );
    final clamped = PositionConverter.clampPosition(absolute, actualSize);

    return Positioned(
      left: clamped.dx - _avatarRadius,
      top: clamped.dy - _avatarRadius,
      child: IgnorePointer(
        child: _buildCircleAvatar(
          imageUrl: pending.profileImageUrl,
          size: _avatarSize,
          showBorder: true,
          borderColor: Colors.greenAccent,
          opacity: 0.85,
        ),
      ),
    );
  }

  /// 댓글 삭제 액션 팝업 빌드
  Widget? _buildDeleteActionPopup() {
    if (!_showActionOverlay ||
        _selectedCommentPosition == null ||
        _selectedCommentId == null) {
      return null;
    }

    final popupWidth = 180.0;
    double left = _selectedCommentPosition!.dx;
    double top = _selectedCommentPosition!.dy + 20;
    final imageWidth = _imageWidth.w;

    if (left + popupWidth > imageWidth) {
      left = imageWidth - popupWidth - 8;
    }

    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 173.w,
          height: 45.h,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(14),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _deleteSelectedComment,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(width: 14.w),
                Padding(
                  padding: EdgeInsets.only(bottom: 1.h),
                  child: Image.asset(
                    'assets/trash_red.png',
                    width: (12.2).w,
                    height: (13.6).w,
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  '댓글 삭제',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFFF0000),
                    fontFamily: 'Pretendard',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptionOverlay() {
    final captionStyle = TextStyle(
      color: Colors.white,
      fontSize: 14.sp,
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w400,
    );

    return GestureDetector(
      onTap: () {
        setState(() => _isCaptionExpanded = !_isCaptionExpanded);
      },
      child: Container(
        width: 278.w,
        constraints: BoxConstraints(
          minHeight: 48.h,
          maxHeight: _isCaptionExpanded ? 260.h : 48.h,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(15),
        ),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        child: Row(
          crossAxisAlignment: _isCaptionExpanded
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Container(
              width: 32.w,
              height: 32.w,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: _isProfileLoading
                  ? Shimmer.fromColors(
                      baseColor: Colors.grey[800]!,
                      highlightColor: Colors.grey[600]!,
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF2A2A2A),
                        ),
                      ),
                    )
                  : _buildCircleAvatar(
                      imageUrl: _uploaderProfileImageUrl,
                      size: 32.w,
                    ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _isCaptionExpanded
                  ? ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.05, 0.95, 1.0],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 6.h),
                          child: Text(
                            widget.post.content!,
                            style: captionStyle,
                          ),
                        ),
                      ),
                    )
                  : FirstLineEllipsisText(
                      text: widget.post.content!,
                      style: captionStyle,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleAvatar({
    required String? imageUrl,
    double size = 27.0,
    bool showBorder = false,
    Color? borderColor,
    double borderWidth = 1.5,
    double opacity = 1.0,
  }) {
    Widget avatarContent;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      avatarContent = ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          memCacheWidth: (size * 4).round(),
          maxWidthDiskCache: (size * 4).round(),
          placeholder: (context, url) => Shimmer.fromColors(
            baseColor: const Color(0xFF2A2A2A),
            highlightColor: const Color(0xFF3A3A3A),
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF2A2A2A),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: Color(0xffd9d9d9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white),
          ),
        ),
      );
    } else {
      avatarContent = Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xffd9d9d9),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person, color: Colors.white),
      );
    }

    if (showBorder) {
      avatarContent = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? Colors.white,
            width: borderWidth,
          ),
        ),
        child: avatarContent,
      );
    }

    return opacity < 1.0
        ? Opacity(opacity: opacity, child: avatarContent)
        : avatarContent;
  }

  void _handleBaseTap() {
    if (_showActionOverlay) {
      _dismissOverlay();
      return;
    }
    if (_hasComments) {
      setState(() {
        _isShowingComments = !_isShowingComments;
      });
    }
  }

  void _dismissOverlay() {
    setState(() {
      _showActionOverlay = false;
      _selectedCommentKey = null;
      _selectedCommentId = null;
      _selectedCommentPosition = null;
    });
  }

  void _openCommentSheet(String selectedKey) {
    final comments = _postComments;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ChangeNotifierProvider(
          create: (_) => AudioController(),
          child: SizedBox(
            height: 480.h,
            child: ApiVoiceCommentListSheet(
              postId: widget.post.id,
              comments: comments,
              selectedCommentId: selectedKey,
            ),
          ),
        );
      },
    );
  }

  /// 댓글 길게 눌렀을 때, 삭제 액션 오버레이 표시
  ///
  /// Parameters:
  ///   - [key]: 선택된 댓글의 고유 키
  ///   - [commentId]: 선택된 댓글의 ID
  ///   - [position]: 댓글 아바타의 절대 위치
  void _handleCommentLongPress({
    required String key,
    required int? commentId,
    required Offset position,
  }) {
    if (commentId == null) {
      _showSnackBar('삭제할 수 없는 댓글입니다.');
      return;
    }
    setState(() {
      // 선택된 댓글 정보 저장
      _selectedCommentKey = key;

      // 댓글 ID와 위치 저장
      _selectedCommentId = commentId;

      // 댓글 아바타의 위치 저장
      _selectedCommentPosition = position;

      // 액션 오버레이 표시
      _showActionOverlay = true;
    });
  }

  /// 댓글 삭제 처리
  Future<void> _deleteSelectedComment() async {
    final targetId = _selectedCommentId;
    if (targetId == null) return;
    try {
      final commentController = Provider.of<CommentController>(
        context,
        listen: false,
      );
      final success = await commentController.deleteComment(targetId);
      if (!mounted) return;
      if (success) {
        _removeCommentFromCache(targetId);
        await widget.onCommentsReloadRequested?.call(widget.post.id);
        _showSnackBar('댓글이 삭제되었습니다.');
        _dismissOverlay();
      } else {
        _showSnackBar('댓글 삭제에 실패했습니다.');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('댓글 삭제 중 오류가 발생했습니다.');
    }
  }

  /// 댓글 캐시에서 제거
  /// 댓글 삭제 후 UI 즉시 반영을 위해 사용
  ///
  /// Parameters:
  ///   - [commentId]: 삭제할 댓글의 ID
  void _removeCommentFromCache(int commentId) {
    final updated = List<Comment>.from(
      widget.postComments[widget.post.id] ?? const <Comment>[],
    )..removeWhere((comment) => comment.id == commentId);
    widget.postComments[widget.post.id] = updated;
    setState(() {});
  }

  /// 카테고리 화면으로 네비게이트
  void _navigateToCategory() {
    final controller = context.read<api_category.CategoryController?>();
    final category = controller?.getCategoryById(widget.categoryId);
    if (category == null) {
      _showSnackBar('카테고리 정보를 불러오지 못했습니다.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApiCategoryPhotosScreen(category: category),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final waveformData = _parseWaveformData(widget.post.waveformData);
    final pendingMarker = _isShowingComments ? _buildPendingMarker() : null;
    final deletePopup = _showActionOverlay ? _buildDeleteActionPopup() : null;

    return Center(
      child: SizedBox(
        width: _imageWidth.w,
        height: _imageHeight.h,
        child: Builder(
          builder: (builderContext) {
            return DragTarget<String>(
              onWillAcceptWithDetails: (details) => details.data.isNotEmpty,
              onAcceptWithDetails: (details) {
                final renderBox =
                    builderContext.findRenderObject() as RenderBox?;
                if (renderBox == null) return;
                final localPosition = renderBox.globalToLocal(details.offset);
                final adjusted = Offset(
                  localPosition.dx + 32,
                  localPosition.dy + 32,
                );
                widget.onProfileImageDragged(widget.post.id, adjusted);
              },
              builder: (context, candidateData, rejectedData) {
                return GestureDetector(
                  onTap: _handleBaseTap,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _buildMediaContent(),
                      ),

                      // 댓글 액션 오버레이
                      if (_showActionOverlay)
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: _dismissOverlay,
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.6),
                            ),
                          ),
                        ),

                      // 카테고리 라벨
                      if (!widget.isArchive)
                        Positioned(
                          top: 11.h,
                          child: CategoryLabelWidget(
                            categoryName: widget.categoryName,
                            onTap: _navigateToCategory,
                          ),
                        ),

                      // 오디오 컨트롤 위젯
                      if (widget.post.hasAudio)
                        Positioned(
                          left: 18.w,
                          right: 18.w,
                          bottom: _hasCaption ? 82.h : 22.h,
                          child: ApiAudioControlWidget(
                            post: widget.post,
                            waveformData: waveformData,
                            onPressed: () => widget.onToggleAudio(widget.post),
                          ),
                        ),
                      /* if (_hasComments)
                        Positioned(
                          bottom: 18.h,
                          right: 18.w,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isShowingComments = !_isShowingComments;
                              });
                            },
                            child: Container(
                              width: 42.w,
                              height: 42.w,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isShowingComments
                                    ? Icons.close
                                    : Icons.chat_bubble_outline,
                                color: Colors.white,
                                size: 20.w,
                              ),
                            ),
                          ),
                        ),*/
                      if (_hasCaption && !widget.post.hasAudio)
                        Positioned(
                          left: 16.w,
                          right: 16.w,
                          bottom: 18.h,
                          child: _buildCaptionOverlay(),
                        ),
                      ..._buildCommentAvatars(),
                      if (pendingMarker != null) pendingMarker,
                      if (deletePopup != null) deletePopup,
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
