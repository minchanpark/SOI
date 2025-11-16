import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../api_firebase/controllers/auth_controller.dart';

// 프로필 이미지 행 위젯 (Figma 디자인 기준)
class ArchiveProfileRowWidget extends StatefulWidget {
  final List<String> mates;

  const ArchiveProfileRowWidget({super.key, required this.mates});

  @override
  State<ArchiveProfileRowWidget> createState() =>
      _ArchiveProfileRowWidgetState();
}

class _ArchiveProfileRowWidgetState extends State<ArchiveProfileRowWidget>
    with AutomaticKeepAliveClientMixin {
  Stream<Map<String, String>>? _profileImagesStream;
  AuthController? _authController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authController ??= Provider.of<AuthController>(context, listen: false);
    _initializeStream();
  }

  @override
  void didUpdateWidget(covariant ArchiveProfileRowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.mates, widget.mates)) {
      _initializeStream();
    }
  }

  void _initializeStream() {
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
                            placeholder: (context, url) =>
                                _buildShimmerCircle(),
                            errorWidget: (context, url, error) =>
                                _buildDefaultCircle(),
                          ),
                        ),
                );
              }).toList(),
            );
          },
        ),
      ),
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
