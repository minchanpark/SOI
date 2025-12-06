import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../api/controller/category_controller.dart' as api_category;
import '../../../api/controller/comment_controller.dart';
import '../../../api/controller/audio_controller.dart';
import '../../../api/controller/user_controller.dart';
import '../../../api/models/comment.dart';
import '../../../api/models/post.dart';
import '../../../api/models/user.dart' as api_user;
import '../../../utils/position_converter.dart';
import '../../about_archiving/screens/archive_detail/api_category_photos_screen.dart';
import '../../common_widget/abput_photo/category_label_widget.dart';
import '../../common_widget/abput_photo/first_line_ellipsis_text.dart';
import 'api_audio_control_widget.dart';
import 'api_voice_comment_list_sheet.dart';
import 'pending_api_voice_comment.dart';

/// Firebase 버전의 PhotoDisplayWidget 디자인을 API 버전에서도 동일하게 유지
class ApiPhotoDisplayWidget extends StatefulWidget {
  final Post post;
  final int categoryId;
  final String categoryName;
  final bool isArchive;
  final Map<int, List<Comment>> postComments;
  final Map<String, String> userProfileImages;
  final Map<String, bool> profileLoadingStates;
  final Function(int, Offset) onProfileImageDragged;
  final Function(Post) onToggleAudio;
  final Map<int, PendingApiVoiceComment> pendingVoiceComments;

  const ApiPhotoDisplayWidget({
    super.key,
    required this.post,
    required this.categoryId,
    required this.categoryName,
    this.isArchive = false,
    required this.postComments,
    required this.userProfileImages,
    required this.profileLoadingStates,
    required this.onProfileImageDragged,
    required this.onToggleAudio,
    this.pendingVoiceComments = const {},
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
  String? _uploaderProfileUrl;
  bool _isUploaderLoading = false;

  bool get _hasComments =>
      (widget.postComments[widget.post.id] ?? const <Comment>[]).isNotEmpty;

  bool get _hasCaption => widget.post.content?.isNotEmpty ?? false;

  @override
  void initState() {
    super.initState();
    _isShowingComments = _hasComments;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _resolveUploaderProfile();
      }
    });
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
    final previousProfile = oldWidget.userProfileImages[widget.post.nickName];
    final currentProfile = widget.userProfileImages[widget.post.nickName];
    if (oldWidget.post.nickName != widget.post.nickName ||
        previousProfile != currentProfile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _resolveUploaderProfile();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final waveformData = _parseWaveformData(widget.post.waveformData);
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
                  onTap: () => _handleBaseTap(),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _buildMediaContent(),
                      ),
                      if (_isShowingComments && !_showActionOverlay)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      if (_showActionOverlay)
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: _dismissOverlay,
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                      if (!widget.isArchive)
                        Positioned(
                          top: 12.h,
                          left: 12.w,
                          child: CategoryLabelWidget(
                            categoryName: widget.categoryName,
                            onTap: _navigateToCategory,
                          ),
                        ),
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
                      if (_hasComments)
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
                        ),
                      if (_hasCaption && !widget.post.hasAudio)
                        Positioned(
                          left: 16.w,
                          right: 16.w,
                          bottom: 18.h,
                          child: _buildCaptionOverlay(),
                        ),
                      ..._buildCommentAvatars(),
                      if (_isShowingComments) ..._buildPendingWidgets(),
                      if (_showActionOverlay) ..._buildDeletePopup(),
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

  Widget _buildMediaContent() {
    if (widget.post.hasImage) {
      return CachedNetworkImage(
        imageUrl: widget.post.imageUrl!,
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

    final comments = widget.postComments[widget.post.id] ?? const <Comment>[];
    final filteredComments = comments
        .where((c) => c.type == CommentType.text || c.type == CommentType.audio)
        .where((c) => c.hasLocation)
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

  List<Widget> _buildPendingWidgets() {
    final marker = _buildPendingMarker();
    if (marker == null) return const [];
    return [marker];
  }

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

  List<Widget> _buildDeletePopup() {
    final popup = _buildDeleteActionPopup();
    if (popup == null) return const [];
    return [popup];
  }

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
                Icon(Icons.delete, color: Colors.redAccent, size: 18.w),
                SizedBox(width: 12.w),
                Text(
                  '댓글 삭제',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.redAccent,
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
    final userKey = widget.post.nickName;
    final profileUrl = widget.userProfileImages[userKey] ?? _uploaderProfileUrl;
    final isLoading =
        widget.profileLoadingStates[userKey] ??
        (_isUploaderLoading && profileUrl == null);

    final captionStyle = TextStyle(
      color: Colors.white,
      fontSize: 14.sp,
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w400,
    );

    return GestureDetector(
      onTap: () {
        setState(() {
          _isCaptionExpanded = !_isCaptionExpanded;
        });
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
              child: ClipOval(
                child: isLoading
                    ? Shimmer.fromColors(
                        baseColor: Colors.grey[800]!,
                        highlightColor: Colors.grey[600]!,
                        child: Container(color: Colors.grey[700]),
                      )
                    : _buildCircleAvatar(imageUrl: profileUrl, size: 32.w),
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

  List<double>? _parseWaveformData(String? waveformString) {
    if (waveformString == null || waveformString.isEmpty) return null;
    try {
      final decoded = jsonDecode(waveformString);
      if (decoded is List) {
        return decoded.map((e) => (e as num).toDouble()).toList();
      }
    } catch (_) {}
    return null;
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
    final comments = widget.postComments[widget.post.id] ?? const <Comment>[];
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
      _selectedCommentKey = key;
      _selectedCommentId = commentId;
      _selectedCommentPosition = position;
      _showActionOverlay = true;
    });
  }

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

  void _resolveUploaderProfile() {
    final cached = widget.userProfileImages[widget.post.nickName];
    if (cached != null) {
      setState(() {
        _uploaderProfileUrl = cached;
        _isUploaderLoading = false;
      });
      return;
    }

    final userController = context.read<UserController?>();
    if (userController == null) return;

    setState(() {
      _isUploaderLoading = true;
    });

    Future<api_user.User?> fetchProfile() async {
      if (widget.post.nickName.isEmpty) return null;
      final numericId = int.tryParse(widget.post.nickName);
      if (numericId != null) {
        return userController.getUser(numericId);
      }
      return userController.getUserByNickname(widget.post.nickName);
    }

    fetchProfile()
        .then((user) {
          if (!mounted) return;
          setState(() {
            _uploaderProfileUrl = user?.profileImageUrlKey;
            _isUploaderLoading = false;
          });
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() {
            _isUploaderLoading = false;
          });
        });
  }
}
