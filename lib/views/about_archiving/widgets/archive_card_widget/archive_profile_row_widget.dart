import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../api_firebase/controllers/auth_controller.dart';

/// 프로필 이미지 행 위젯 (Figma 디자인 기준)
///
/// 두 가지 모드 지원:
/// 1. [profileImages]가 제공되면 해당 데이터 사용 (권장 - 성능 최적화)
/// 2. [profileImages]가 null이면 내부 스트림으로 조회 (레거시 호환)
class ArchiveProfileRowWidget extends StatefulWidget {
  final List<String> mates;

  /// 미리 로드된 프로필 이미지 맵 (userId: imageUrl)
  /// 카테고리 데이터와 함께 로드되어 전달됨
  final Map<String, String>? profileImages;

  const ArchiveProfileRowWidget({
    super.key,
    required this.mates,
    this.profileImages,
  });

  @override
  State<ArchiveProfileRowWidget> createState() =>
      _ArchiveProfileRowWidgetState();
}

class _ArchiveProfileRowWidgetState extends State<ArchiveProfileRowWidget>
    with AutomaticKeepAliveClientMixin {
  Stream<Map<String, String>>? _profileImagesStream;
  AuthController? _authController;

  /// profileImages가 외부에서 제공되는지 여부
  bool get _hasExternalProfileImages => widget.profileImages != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 외부 프로필 이미지가 없을 때만 스트림 초기화
    if (!_hasExternalProfileImages) {
      _authController ??= Provider.of<AuthController>(context, listen: false);
      _initializeStream();
    }
  }

  @override
  void didUpdateWidget(covariant ArchiveProfileRowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 외부 프로필 이미지가 없고 mates가 변경된 경우에만 스트림 재초기화
    if (!_hasExternalProfileImages &&
        !listEquals(oldWidget.mates, widget.mates)) {
      _initializeStream();
    }
  }

  void _initializeStream() {
    // 외부 프로필 이미지가 있으면 스트림 불필요
    if (_hasExternalProfileImages) return;

    final auth = _authController;
    if (auth == null || widget.mates.isEmpty) return;

    // 최대 3명만 표시하므로 3명의 프로필만 가져옴
    final displayMates = widget.mates.take(3).toList();
    _profileImagesStream = auth.getMultipleUserProfileImagesStream(
      displayMates,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.mates.isEmpty) {
      return _buildEmptyShimmer();
    }

    final displayMates = widget.mates.take(3).toList();

    // 외부에서 프로필 이미지가 제공된 경우 - 스트림 없이 바로 렌더링
    if (_hasExternalProfileImages) {
      return _buildProfileStack(displayMates, widget.profileImages!);
    }

    // 레거시 모드 - 내부 스트림 사용
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: 19,
        width: (displayMates.length - 1) * 12.0 + 19.0,
        child: StreamBuilder<Map<String, String>>(
          stream: _profileImagesStream,
          builder: (context, snapshot) {
            // 로딩 중
            if (!snapshot.hasData &&
                snapshot.connectionState == ConnectionState.waiting) {
              return Stack(
                children: displayMates.asMap().entries.map<Widget>((entry) {
                  final index = entry.key;
                  return Positioned(
                    left: index * 12.0,
                    child: _buildShimmerCircle(),
                  );
                }).toList(),
              );
            }

            // 프로필 이미지 Map 가져오기
            final profileImages = snapshot.data ?? {};

            return _buildProfileStackContent(displayMates, profileImages);
          },
        ),
      ),
    );
  }

  /// 프로필 이미지 스택 빌드 (컨테이너 포함)
  Widget _buildProfileStack(
    List<String> displayMates,
    Map<String, String> profileImages,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: 19,
        width: (displayMates.length - 1) * 12.0 + 19.0,
        child: _buildProfileStackContent(displayMates, profileImages),
      ),
    );
  }

  /// 프로필 이미지 스택 내용 빌드
  Widget _buildProfileStackContent(
    List<String> displayMates,
    Map<String, String> profileImages,
  ) {
    return Stack(
      children: displayMates.asMap().entries.map<Widget>((entry) {
        final index = entry.key;
        final mateUid = entry.value;
        final imageUrl = profileImages[mateUid] ?? '';

        return Positioned(
          left: index * 12.0,
          child: imageUrl.isEmpty
              ? _buildDefaultCircle()
              : ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    width: 19,
                    height: 19,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    useOldImageOnUrlChange: true,
                    memCacheWidth: (19 * 5).round(),
                    maxWidthDiskCache: (19 * 5).round(),
                    placeholder: (context, url) => _buildShimmerCircle(),
                    errorWidget: (context, url, error) => _buildDefaultCircle(),
                  ),
                ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[400]!,
      highlightColor: Colors.white,
      child: Container(
        width: 19,
        height: 19,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildShimmerCircle() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade600,
      highlightColor: Colors.grey.shade400,
      child: Container(
        width: 19,
        height: 19,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDefaultCircle() {
    return Container(
      width: 19,
      height: 19,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xffd9d9d9),
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 14),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
