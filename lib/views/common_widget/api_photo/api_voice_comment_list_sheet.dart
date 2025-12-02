import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../api/models/comment.dart';
import '../../../api/controller/api_comment_audio_controller.dart';

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

    // 필터링된 댓글 리스트에서 인덱스 찾기
    final filteredComments = widget.comments
        .where((c) => c.type == CommentType.text || c.type == CommentType.audio)
        .toList();

    int? targetIndex;
    for (int i = 0; i < filteredComments.length; i++) {
      // selectedCommentId는 "index_hashCode" 형식
      final commentId = '${i}_${filteredComments[i].hashCode}';
      if (commentId == widget.selectedCommentId) {
        targetIndex = i;
        break;
      }
    }

    if (targetIndex != null && _scrollController.hasClients) {
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
    // 이모지 제외하고 텍스트/오디오 댓글만 필터링
    final filteredComments = widget.comments
        .where((c) => c.type == CommentType.text || c.type == CommentType.audio)
        .toList();

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
          final commentId = '${index}_${comment.hashCode}';
          final isHighlighted = commentId == widget.selectedCommentId;
          return _ApiCommentRow(comment: comment, isHighlighted: isHighlighted);
        },
      ),
    );
  }
}

/// API 댓글 행 위젯
class _ApiCommentRow extends StatelessWidget {
  final Comment comment;
  final Map<String, String> userProfileImages;
  final Map<String, String> userNames;
  final bool isLoadingUser;
  final bool isHighlighted;

  const _ApiCommentRow({
    required this.comment,
    this.isHighlighted = false,
    this.userProfileImages = const {},
    this.userNames = const {},
    this.isLoadingUser = false,
  });

  @override
  Widget build(BuildContext context) {
    switch (comment.type) {
      case CommentType.emoji:
        return const SizedBox.shrink(); // 이모지는 표시하지 않음
      case CommentType.text:
        return _buildTextRow(context);
      case CommentType.audio:
        return _buildAudioRow(context);
    }
  }

  /// 텍스트 댓글 UI
  Widget _buildTextRow(BuildContext context) {
    // userProfile은 프로필 이미지 URL
    final profileUrl = comment.userProfile ?? '';
    final userName = userNames[comment.userProfile] ?? '이름을 가지고 오지 못하였습니다.';

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
                    '$userName',
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
        color: const Color(0xff000000).withOpacity(0.23),
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
    final profileUrl = comment.userProfile ?? '';
    final userName = userNames[comment.userProfile] ?? '이름을 가지고 오지 못하였습니다.';

    // waveformData 파싱 (String -> List<double>)
    final waveformData = _parseWaveformData(comment.waveformData);

    final content = Consumer<ApiCommentAudioController>(
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
        color: const Color(0xff000000).withOpacity(0.23),
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

  /// waveformData 문자열을 List<double>로 파싱
  List<double> _parseWaveformData(String? waveformString) {
    if (waveformString == null || waveformString.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(waveformString);
      if (decoded is List) {
        return decoded.map((e) => (e as num).toDouble()).toList();
      }
    } catch (e) {
      debugPrint('waveformData 파싱 실패: $e');
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
        color: const Color(0xFF000000).withOpacity(0.4),
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
