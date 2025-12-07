import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:soi/api/controller/media_controller.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/api/controller/friend_controller.dart';

/// REST API 기반 프로필 이미지 행 위젯
///
/// Category 객체에서 직접 프로필 URL 키 리스트와 총 인원수를 받아 표시합니다.
/// 최대 3개의 프로필을 표시하고, 초과 인원은 +N 배지로 표시합니다.
class ApiArchiveProfileRowWidget extends StatefulWidget {
  final List<String> profileUrlKeys;
  final int totalUserCount;

  const ApiArchiveProfileRowWidget({
    super.key,
    required this.profileUrlKeys,
    this.totalUserCount = 0,
  });

  @override
  State<ApiArchiveProfileRowWidget> createState() =>
      _ApiArchiveProfileRowWidgetState();
}

class _ApiArchiveProfileRowWidgetState
    extends State<ApiArchiveProfileRowWidget> {
  // Presigned URL 캐시 (키 -> URL)
  final Map<String, String> _presignedUrlCache = {};
  UserController? _userController;
  FriendController? _friendController;

  // userController 리스너 --> 프로필 업데이트 처리
  VoidCallback? _userListener;

  // friendController 리스너 --> 프로필 업데이트 처리
  VoidCallback? _friendListener;

  @override
  void initState() {
    super.initState();
    _loadPresignedUrls();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final userController = Provider.of<UserController>(context, listen: false);

    // UserController 리스너 등록
    if (_userController != userController) {
      if (_userListener != null) {
        // 이전 리스너 제거
        _userController?.removeListener(_userListener!);
      }
      _userController = userController;

      // 리스너 콜백 설정 --> 프로필 변경 감지를 해서 프로필을 업데이트
      _userListener ??= _handleProfileUpdates;

      // 리스너 등록 --> 프로필 변경 감지
      _userController?.addListener(_userListener!);
    }

    final friendController = Provider.of<FriendController>(
      context,
      listen: false,
    );
    // FriendController 리스너 등록
    if (_friendController != friendController) {
      if (_friendListener != null) {
        // 이전 리스너 제거
        _friendController?.removeListener(_friendListener!);
      }
      _friendController = friendController;

      // 리스너 콜백 설정 --> 프로필 변경 감지를 해서 프로필을 업데이트
      _friendListener ??= _handleProfileUpdates;

      // 리스너 등록 --> 프로필 변경 감지
      _friendController?.addListener(_friendListener!);
    }
  }

  @override
  void didUpdateWidget(ApiArchiveProfileRowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final keysChanged = !listEquals(
      oldWidget.profileUrlKeys,
      widget.profileUrlKeys,
    );
    final countChanged = oldWidget.totalUserCount != widget.totalUserCount;

    if (keysChanged || countChanged) {
      _presignedUrlCache.clear();
      _loadPresignedUrls(forceReload: true);
    }
  }

  @override
  void dispose() {
    if (_userListener != null) {
      // UserController 리스너 제거
      _userController?.removeListener(_userListener!);
    }
    if (_friendListener != null) {
      // FriendController 리스너 제거
      _friendController?.removeListener(_friendListener!);
    }
    super.dispose();
  }

  Future<void> _loadPresignedUrls({bool forceReload = false}) async {
    final mediaController = context.read<MediaController>();
    final displayCount = widget.totalUserCount.clamp(1, 3);

    // 표시할 프로필 키들만 로드 (최대 3개)
    final keysToLoad = widget.profileUrlKeys.take(displayCount).toList();

    for (final key in keysToLoad) {
      if (key.isEmpty) continue;
      if (!forceReload && _presignedUrlCache.containsKey(key)) continue;

      final url = await mediaController.getPresignedUrl(key);
      if (url != null && mounted) {
        setState(() {
          _presignedUrlCache[key] = url;
          debugPrint("프로필 이미지 캐시: ${_presignedUrlCache[key]}");
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayCount = widget.totalUserCount.clamp(1, 3);
    final remainingCount = widget.totalUserCount > 3
        ? widget.totalUserCount - 3
        : 0;

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
            // displayCount개 프로필 표시
            ...List.generate(displayCount, (index) {
              // 키가 있고, presigned URL이 캐시에 있으면 사용
              final key = index < widget.profileUrlKeys.length
                  ? widget.profileUrlKeys[index]
                  : '';
              final imageUrl = _presignedUrlCache[key] ?? '';

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

  void _handleProfileUpdates() {
    if (!mounted) return;
    // 프로필 이미지 키가 변경되었을 수 있으므로 캐시 초기화
    _presignedUrlCache.clear();
    // 프로필 이미지 URL 재로딩
    _loadPresignedUrls(forceReload: true);
  }
}
