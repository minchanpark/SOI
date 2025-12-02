import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

/// REST API 기반 프로필 이미지 행 위젯
///
/// Category 객체에서 직접 프로필 URL 리스트와 총 인원수를 받아 표시합니다.
/// 최대 3개의 프로필을 표시하고, 초과 인원은 +N 배지로 표시합니다.
class ApiArchiveProfileRowWidget extends StatelessWidget {
  final List<String> profileUrls;
  final int totalUserCount;

  const ApiArchiveProfileRowWidget({
    super.key,
    required this.profileUrls,
    this.totalUserCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    // totalUserCount에 +1 (기본값 0이므로 최소 1명 보장)
    final effectiveUserCount = totalUserCount + 1;

    // 빈 문자열을 제외한 실제 프로필 URL만 필터링
    final validProfileUrls = profileUrls
        .where((url) => url.isNotEmpty)
        .toList();

    // 표시할 프로필 수: effectiveUserCount 기준 (최대 3개)
    final displayCount = effectiveUserCount.clamp(1, 3);
    // 남은 인원: 총 인원 - 표시된 프로필 수
    final remainingCount = effectiveUserCount > 3 ? effectiveUserCount - 3 : 0;

    // +N 배지 포함 시 너비 계산
    final badgeCount = remainingCount > 0 ? 1 : 0;
    final totalWidth = (displayCount - 1 + badgeCount) * 12.0 + 19.0;

    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: 19,
        width: totalWidth,
        child: Stack(
          children: [
            // effectiveUserCount 기준으로 displayCount개 표시
            ...List.generate(displayCount, (index) {
              // validProfileUrls에 해당 인덱스가 있으면 이미지, 없으면 기본 아바타
              final imageUrl = index < validProfileUrls.length
                  ? validProfileUrls[index]
                  : '';

              return Positioned(
                left: index * 12.0,
                child: imageUrl.isEmpty
                    ? _buildDefaultAvatar()
                    : _buildProfileImage(imageUrl),
              );
            }),
            // +N 배지 표시 (3명 초과 시)
            if (remainingCount > 0)
              Positioned(
                left: displayCount * 12.0,
                child: _buildRemainingBadge(remainingCount),
              ),
          ],
        ),
      ),
    );
  }

  /// 기본 아바타 (이미지 없을 때)
  Widget _buildDefaultAvatar() {
    return Container(
      width: 19,
      height: 19,
      decoration: BoxDecoration(
        color: Colors.grey.shade700,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF1C1C1C), width: 1.5),
      ),
      child: const Icon(Icons.person, size: 12, color: Colors.white54),
    );
  }

  /// 프로필 이미지 빌드
  Widget _buildProfileImage(String imageUrl) {
    return Container(
      width: 19,
      height: 19,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF1C1C1C), width: 1.5),
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: 19,
          height: 19,
          fit: BoxFit.cover,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholder: (context, url) => Shimmer.fromColors(
            baseColor: Colors.grey.shade800,
            highlightColor: Colors.grey.shade700,
            child: Container(
              width: 19,
              height: 19,
              color: Colors.grey.shade800,
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: 19,
            height: 19,
            color: Colors.grey.shade700,
            child: const Icon(Icons.person, size: 12, color: Colors.white54),
          ),
        ),
      ),
    );
  }

  /// 남은 인원수 배지 (+N)
  Widget _buildRemainingBadge(int count) {
    return Container(
      width: 19,
      height: 19,
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A3A),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF1C1C1C), width: 1.5),
      ),
      child: Center(
        child: Text(
          '+$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
