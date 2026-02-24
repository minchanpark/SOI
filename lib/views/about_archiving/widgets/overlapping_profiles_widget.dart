import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:soi/api/models/selected_friend_model.dart';
import '../../../api/controller/media_controller.dart';

/// 선택된 친구들의 프로필 이미지를 겹쳐서 표시하는 위젯
/// 최대 4개의 프로필 이미지를 표시합니다.
class OverlappingProfilesWidget extends StatelessWidget {
  final List<SelectedFriendModel> selectedFriends;
  final VoidCallback? onAddPressed;
  final double profileSize;
  final double overlapDistance;
  final bool showAddButton;

  const OverlappingProfilesWidget({
    super.key,
    required this.selectedFriends,
    this.onAddPressed,
    this.profileSize = 27.0,
    this.overlapDistance = 16.0,
    this.showAddButton = false,
  });

  @override
  Widget build(BuildContext context) {
    // 최대 4개의 프로필만 표시
    final displayFriends = selectedFriends.take(3).toList();

    // 전체 너비 계산: 첫 번째 프로필(profileSize) + 겹치는 부분들(overlapDistance * 개수) + (+ 버튼이 있다면 추가)
    final totalProfiles =
        displayFriends.length +
        (showAddButton && displayFriends.length < 4 ? 1 : 0);
    final containerWidth = profileSize + (totalProfiles - 1) * overlapDistance;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Color(0xFF323232),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 겹쳐지는 프로필 이미지들
          SizedBox(
            height: profileSize,
            width: containerWidth,
            child: Stack(
              children: [
                // 친구 프로필들
                ...displayFriends.asMap().entries.map((entry) {
                  final index = entry.key;
                  final friend = entry.value;

                  return Positioned(
                    left: (index * overlapDistance).w,
                    child: _ProfileAvatar(
                      size: profileSize,
                      imageUrl: friend.profileImageUrl,
                    ),
                  );
                }),

                // + 버튼 (showAddButton이 true일 때만 표시)
                if (showAddButton && onAddPressed != null)
                  Positioned(
                    left: (displayFriends.length * overlapDistance).w,
                    child: GestureDetector(
                      onTap: onAddPressed,
                      child: Container(
                        width: profileSize,
                        height: profileSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF5a5a5a),
                        ),
                        child: Image.asset("assets/plus_container.png"),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final double size;
  final String? imageUrl;

  const _ProfileAvatar({required this.size, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    if (!hasImage) {
      return _buildDefault();
    }

    final raw = imageUrl!;
    final uri = Uri.tryParse(raw);
    final isHttpUrl = uri != null && uri.hasScheme;

    if (!isHttpUrl) {
      // profileImageUrlKey 같은 S3 Key가 들어오는 케이스를 위해 presigned URL로 변환
      return FutureBuilder<String?>(
        future: context.read<MediaController>().getPresignedUrl(raw),
        builder: (context, snapshot) {
          final resolvedUrl = snapshot.data;
          if (resolvedUrl == null || resolvedUrl.isEmpty) {
            return _buildDefault();
          }
          return _buildNetworkAvatar(resolvedUrl);
        },
      );
    }

    return _buildNetworkAvatar(raw);
  }

  Widget _buildNetworkAvatar(String url) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          memCacheWidth: (size * 5).round(),
          maxWidthDiskCache: (size * 5).round(),
          placeholder: (context, url) => _buildShimmer(),
          errorWidget: (context, url, error) => _buildDefault(),
        ),
      ),
    );
  }

  Widget _buildDefault() {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFd9d9d9),
      ),
      child: Icon(
        Icons.person,
        color: Colors.white,
        size: (size * 0.45).clamp(14.0, 26.0),
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade600,
      highlightColor: Colors.grey.shade300,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
      ),
    );
  }
}
