import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../api/models/post.dart';
import '../../../api/models/comment.dart';
import '../../../api/controller/audio_controller.dart';
import '../../../utils/position_converter.dart';
import 'api_photo_card_widget.dart';
import 'api_audio_control_widget.dart';
import 'api_voice_comment_list_sheet.dart';

/// API 기반 사진 표시 위젯
///
/// Firebase 버전의 PhotoDisplayWidget과 동일한 디자인을 유지하면서
/// Post 모델을 사용합니다.
class ApiPhotoDisplayWidget extends StatefulWidget {
  final Post post;
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
  // 상수
  static const double _avatarSize = 27.0;
  static const double _avatarRadius = 13.5;
  static const double _imageWidth = 354.0;
  static const double _imageHeight = 500.0;

  // 선택된 댓글 관련 상태
  String? _selectedCommentId;
  //Offset? _selectedCommentPosition;
  bool _showActionOverlay = false;
  bool _isShowingComments = false;
  bool _isCaptionExpanded = false;

  @override
  void initState() {
    super.initState();
    // 댓글이 있으면 자동으로 표시
    final comments = widget.postComments[widget.post.id] ?? [];
    if (comments.isNotEmpty) {
      _isShowingComments = true;
    }
  }

  @override
  void didUpdateWidget(covariant ApiPhotoDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 댓글이 새로 생기면 자동으로 표시
    final comments = widget.postComments[widget.post.id] ?? [];
    if (comments.isNotEmpty && !_isShowingComments) {
      setState(() {
        _isShowingComments = true;
      });
    }
  }

  /// 공통 Circle Avatar 빌더
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
      avatarContent = CachedNetworkImage(
        imageUrl: imageUrl,
        imageBuilder: (context, imageProvider) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          ),
        ),
        placeholder: (context, url) => Shimmer.fromColors(
          baseColor: Colors.grey.shade800,
          highlightColor: Colors.grey.shade700,
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xffd9d9d9),
          ),
          child: Icon(Icons.person, color: Colors.white, size: size * 0.6),
        ),
      );
    } else {
      avatarContent = Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xffd9d9d9),
        ),
        child: Icon(Icons.person, color: Colors.white, size: size * 0.6),
      );
    }

    if (showBorder) {
      avatarContent = Container(
        padding: EdgeInsets.all(borderWidth),
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

  /// 댓글 아바타 리스트 빌드
  List<Widget> _buildCommentAvatars() {
    if (!_isShowingComments) return [];

    final comments = widget.postComments[widget.post.id] ?? [];
    // 텍스트/오디오 댓글만 필터링 (sheet와 동일한 필터)
    final filteredComments = comments
        .where((c) => c.type == CommentType.text || c.type == CommentType.audio)
        .toList();
    final commentsWithPosition = filteredComments
        .where((c) => c.hasLocation)
        .toList();

    final actualImageSize = Size(_imageWidth.w, _imageHeight.h);

    return commentsWithPosition.map((comment) {
      // filteredComments에서의 인덱스 찾기 (sheet와 동일한 인덱스)
      final indexInFiltered = filteredComments.indexOf(comment);
      final commentId = '${indexInFiltered}_${comment.hashCode}';

      final relativePosition = Offset(
        comment.locationX ?? 0.5,
        comment.locationY ?? 0.5,
      );
      final absolutePosition = PositionConverter.toAbsolutePosition(
        relativePosition,
        actualImageSize,
      );

      final isSelected = _selectedCommentId == commentId;

      return Positioned(
        left: absolutePosition.dx - _avatarRadius,
        top: absolutePosition.dy - _avatarRadius,
        child: GestureDetector(
          onTap: () async {
            // 댓글 클릭 시 sheet 열기 (해당 댓글로 스크롤)
            if (!mounted) return;
            try {
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (sheetContext) => ChangeNotifierProvider(
                  create: (_) => AudioController(),
                  child: SizedBox(
                    height: 480.h,
                    child: ApiVoiceCommentListSheet(
                      postId: widget.post.id,
                      comments: filteredComments,
                      selectedCommentId: commentId,
                    ),
                  ),
                ),
              );
            } catch (e) {
              debugPrint('댓글 팝업 표시 실패: $e');
            }
          },
          onLongPress: () {
            setState(() {
              _selectedCommentId = commentId;
              _showActionOverlay = true;
            });
          },
          child: _buildCircleAvatar(
            imageUrl: comment.userProfile,
            size: _avatarSize,
            showBorder: isSelected,
            borderColor: Colors.blue,
          ),
        ),
      );
    }).toList();
  }

  /// Pending 마커 빌드
  Widget? _buildPendingMarker() {
    final pending = widget.pendingVoiceComments[widget.post.id];
    if (pending == null || pending.relativePosition == null) return null;

    final actualImageSize = Size(_imageWidth.w, _imageHeight.h);
    final absolutePosition = PositionConverter.toAbsolutePosition(
      pending.relativePosition!,
      actualImageSize,
    );
    final clampedPosition = PositionConverter.clampPosition(
      absolutePosition,
      actualImageSize,
    );

    return Positioned(
      left: clampedPosition.dx - _avatarRadius,
      top: clampedPosition.dy - _avatarRadius,
      child: _buildCircleAvatar(
        imageUrl: pending.profileImageUrl,
        size: _avatarSize,
        showBorder: true,
        borderColor: Colors.green,
      ),
    );
  }

  /// 파형 데이터 파싱
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

  @override
  Widget build(BuildContext context) {
    final waveformData = _parseWaveformData(widget.post.waveformData);

    return Center(
      child: SizedBox(
        width: _imageWidth.w,
        height: _imageHeight.h,
        // DragTarget으로 감싸서 프로필 이미지 드롭 지원
        child: Builder(
          builder: (builderContext) {
            return DragTarget<String>(
              onWillAcceptWithDetails: (details) {
                return details.data.isNotEmpty;
              },
              onAcceptWithDetails: (details) {
                // 드롭된 좌표를 사진 내 상대 좌표로 변환
                final RenderBox renderBox =
                    builderContext.findRenderObject() as RenderBox;
                final localPosition = renderBox.globalToLocal(details.offset);

                // 프로필 크기(64)의 반지름만큼 보정하여 중심점으로 조정
                final adjustedPosition = Offset(
                  localPosition.dx + 32,
                  localPosition.dy + 32,
                );

                widget.onProfileImageDragged(widget.post.id, adjustedPosition);
              },
              builder: (context, candidateData, rejectedData) {
                return GestureDetector(
                  onTap: () {
                    if (_showActionOverlay) {
                      setState(() {
                        _showActionOverlay = false;
                        _selectedCommentId = null;
                      });
                    } else {
                      widget.onToggleAudio(widget.post);
                    }
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 사진/비디오 표시
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: widget.post.hasImage
                            ? CachedNetworkImage(
                                imageUrl: widget.post.imageUrl!,
                                width: _imageWidth.w,
                                height: _imageHeight.h,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    Shimmer.fromColors(
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
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.grey[600],
                                    size: 50.w,
                                  ),
                                ),
                              )
                            : Container(
                                width: _imageWidth.w,
                                height: _imageHeight.h,
                                color: Colors.grey[800],
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey[600],
                                  size: 50.w,
                                ),
                              ),
                      ),

                      // 카테고리 라벨 (Archive가 아닌 경우)
                      if (!widget.isArchive)
                        Positioned(
                          top: 12.h,
                          left: 12.w,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              widget.categoryName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.sp,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                      // 오디오 컨트롤 (오디오가 있는 경우)
                      if (widget.post.hasAudio)
                        Positioned(
                          bottom: 12.h,
                          left: 12.w,
                          right: 12.w,
                          child: ApiAudioControlWidget(
                            post: widget.post,
                            waveformData: waveformData,
                          ),
                        ),

                      // 캡션 표시 (있는 경우)
                      if (widget.post.content != null &&
                          widget.post.content!.isNotEmpty)
                        Positioned(
                          bottom: widget.post.hasAudio ? 70.h : 12.h,
                          left: 12.w,
                          right: 12.w,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isCaptionExpanded = !_isCaptionExpanded;
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 6.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                widget.post.content!,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.sp,
                                  fontFamily: 'Pretendard',
                                ),
                                maxLines: _isCaptionExpanded ? null : 2,
                                overflow: _isCaptionExpanded
                                    ? TextOverflow.visible
                                    : TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),

                      // 댓글 아바타들
                      ..._buildCommentAvatars(),

                      // Pending 마커
                      if (_buildPendingMarker() != null) _buildPendingMarker()!,
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
