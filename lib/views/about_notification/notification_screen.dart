import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../api/controller/notification_controller.dart' as api;
import '../../api/controller/category_controller.dart';
import '../../api/controller/post_controller.dart';
import '../../api/controller/user_controller.dart';
import '../../api/models/notification.dart';
import '../../api/models/post.dart';
import '../about_archiving/screens/archive_detail/api_category_photos_screen.dart';
import '../about_archiving/screens/archive_detail/api_photo_detail_screen.dart';
import 'widgets/api_notification_item_widget.dart';
import 'widgets/category_invite_confirm_sheet.dart';

/// 알림 메인 화면 (API 버전)
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late api.NotificationController _notificationController;
  late ScrollController _scrollController;

  bool _isLoading = false;
  bool _isFriendRequestLoading = false;
  String? _error;
  NotificationGetAllResult? _notificationResult;
  int? _friendRequestCount; // 친구추가 요청 개수

  String? _extractCategoryNameFromNotificationText(String? text) {
    if (text == null || text.isEmpty) return null;
    final quoted = RegExp(r'"([^"]+)"').firstMatch(text)?.group(1);
    if (quoted != null && quoted.isNotEmpty) return quoted;
    final curlyQuoted = RegExp(r'“([^”]+)”').firstMatch(text)?.group(1);
    if (curlyQuoted != null && curlyQuoted.isNotEmpty) return curlyQuoted;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFriendRequestCountFromGetFriendApi(); // 친구 요청 개수 로드(get-friend)
      _loadNotifications(); // 알림 로드
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // (배포버전 프리즈 방지) 전역 imageCache.clear()는 캐시가 큰 실사용 환경에서
    // dispose 타이밍에 수 초 프리즈를 만들 수 있어 제거합니다.
    super.dispose();
  }

  /// 알림 로드
  Future<void> _loadNotifications() async {
    final userController = context.read<UserController>();
    final user = userController.currentUser;

    if (user == null) {
      setState(() {
        _error = '로그인이 필요합니다';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _notificationController = context.read<api.NotificationController>();
      final result = await _notificationController.getAllNotifications(
        userId: user.id,
      );

      if (mounted) {
        setState(() {
          _notificationResult = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '알림을 불러올 수 없습니다: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// 친구 요청 개수 로드 (알림 리스트와 독립)
  Future<void> _loadFriendRequestCountFromGetFriendApi() async {
    final userController = context.read<UserController>();
    final user = userController.currentUser;

    if (user == null) {
      return;
    }

    setState(() {
      _isFriendRequestLoading = true;
    });

    try {
      final notificationController = context.read<api.NotificationController>();
      final friendNotifications = await notificationController
          .getAllFriendNotifications(userId: user.id);
      final uniqueKeys = <String>{};
      for (final n in friendNotifications) {
        final key = n.relatedId ?? n.id;
        if (key != null) {
          uniqueKeys.add(key.toString());
        }
      }
      final count = uniqueKeys.isNotEmpty
          ? uniqueKeys.length
          : friendNotifications.length;
      if (!mounted) return;
      setState(() {
        _friendRequestCount = count;
        _isFriendRequestLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isFriendRequestLoading = false;
      });
    }
  }

  /// 새로고침 처리
  Future<void> _onRefresh() async {
    final userController = context.read<UserController>();
    final user = userController.currentUser;

    if (user != null) {
      context.read<api.NotificationController>().invalidateCache();
      await _loadFriendRequestCountFromGetFriendApi();
      await _loadNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          SizedBox(height: 20.h),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  /// AppBar 구성
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: Color(0xffd9d9d9)),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '알림',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              color: const Color(0xFFF8F8F8),
              fontSize: 20.sp,
              fontFamily: 'Pretendard Variable',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// Body 구성
  Widget _buildBody() {
    // 친구 요청 섹션은 알림 데이터 로딩/에러/빈 상태와 상관없이 항상 노출
    final showNotificationList =
        _notificationResult != null && _notificationResult!.hasNotifications;

    Widget body;
    if (_isLoading && _notificationResult == null) {
      body = _buildLoadingState();
    } else if (_error != null) {
      body = _buildErrorState();
    } else if (!showNotificationList) {
      body = _buildEmptyState();
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 19.w),
            child: Text(
              "최근 7일",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.02.sp,
                fontFamily: 'Pretendard Variable',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: _buildNotificationList()),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFriendRequestSection(),
        SizedBox(height: 24.h),
        Expanded(child: body),
      ],
    );
  }

  /// 친구 요청 섹션
  Widget _buildFriendRequestSection() {
    final requestCount =
        _friendRequestCount ?? _notificationResult?.friendRequestCount ?? 0;
    final subtitle = _isFriendRequestLoading || _isLoading
        ? '불러오는 중...'
        : (requestCount > 0 ? '보류 중인 요청 $requestCount명' : '받은 요청이 없습니다');

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed('/friend_requests');
      },
      child: Padding(
        padding: EdgeInsets.only(left: 19.w),
        child: Container(
          width: 354.w,
          height: 66.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xff1c1c1c),
          ),
          child: Row(
            children: [
              SizedBox(width: 18.w),
              Image.asset(
                'assets/friend_request_icon.png',
                width: 43,
                height: 43,
              ),
              SizedBox(width: 8.w),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '친구 요청',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontFamily: 'Pretendard Variable',
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.08,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: const Color(0xFFCBCBCB),
                      fontSize: 13.sp,
                      fontFamily: 'Pretendard Variable',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (requestCount > 0) ...[
                Container(
                  width: 20.w,
                  height: 20.h,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      requestCount > 99 ? '99+' : '$requestCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
              ],
              Icon(Icons.arrow_forward_ios, color: Colors.white, size: 23.sp),
              SizedBox(width: 12.w),
            ],
          ),
        ),
      ),
    );
  }

  /// 로딩 상태
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xff634D45)),
          SizedBox(height: 16.h),
          Text(
            '알림을 불러오는 중...',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xff535252),
              fontSize: 16.sp,
            ),
          ),
        ],
      ),
    );
  }

  /// 에러 상태
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64.sp, color: Colors.red),
          SizedBox(height: 16.h),
          Text(
            '알림을 불러올 수 없습니다',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: Colors.white,
              fontSize: 20.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            _error ?? '알 수 없는 오류가 발생했습니다',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xff535252),
              fontSize: 16.sp,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          ElevatedButton(
            onPressed: _onRefresh,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff634D45),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
            ),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  /// 빈 상태
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64.sp,
            color: const Color(0xff535252).withValues(alpha: 0.5),
          ),
          SizedBox(height: 16.h),
          Text(
            '알림이 없습니다',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: const Color(0xff535252),
              fontSize: 20.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '새로운 알림이 오면 여기에 표시됩니다',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xff535252).withValues(alpha: 0.7),
              fontSize: 16.sp,
            ),
          ),
        ],
      ),
    );
  }

  /// 알림 목록
  Widget _buildNotificationList() {
    final notifications = _notificationResult?.notifications ?? [];

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xff634D45),
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xff1c1c1c),
            ),
            child: Column(
              children: [
                SizedBox(height: 22.h),
                for (int i = 0; i < notifications.length; i++)
                  ApiNotificationItemWidget(
                    notification: notifications[i],
                    profileUrl: notifications[i].userProfile,
                    imageUrl: notifications[i].imageUrl,
                    onTap: () => _onNotificationTap(notifications[i]),
                    onConfirm:
                        notifications[i].type ==
                            AppNotificationType.categoryInvite
                        ? () => _onNotificationTap(notifications[i])
                        : null,
                    isLast: i == notifications.length - 1,
                  ),
                SizedBox(height: 7.h),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 알림 탭 처리
  ///
  /// Parameters:
  ///   - [notification]: 탭된 알림 객체
  Future<void> _onNotificationTap(AppNotification notification) async {
    final userController = context.read<UserController>();
    final currentUser = userController.currentUser;
    if (currentUser == null) {
      _showSnackBar('로그인이 필요합니다.');
      return;
    }

    // 알림 타입을 받아온다.
    final type = notification.type;
    if (type == null) {
      _showSnackBar('알림 정보를 확인할 수 없습니다.');
      return;
    }

    // 친구 요청일 경우, 친구 요청 화면으로 이동
    if (type == AppNotificationType.friendRequest ||
        type == AppNotificationType.friendRespond) {
      Navigator.of(context).pushNamed('/friend_requests');
      return;
    }

    // 카테고리 초대 알림일 경우, 초대 수락/거절 모달 시트 표시
    if (type == AppNotificationType.categoryInvite) {
      final categoryId =
          notification.relatedId ?? notification.categoryIdForPost;
      if (categoryId == null) {
        _showSnackBar('카테고리 정보를 찾을 수 없습니다.');
        return;
      }

      final categoryController = context.read<CategoryController>();

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return CategoryInviteConfirmSheet(
            categoryName:
                _extractCategoryNameFromNotificationText(notification.text) ??
                '카테고리',
            categoryImageUrl: notification.imageUrl ?? '',
            invitees: const [],
            onAccept: () async {
              Navigator.of(sheetContext).pop();
              _showBlockingLoading();
              try {
                final ok = await categoryController.acceptInvite(
                  categoryId: categoryId,
                  userId: currentUser.id,
                );
                if (ok) {
                  await _onRefresh();
                  _showSnackBar('카테고리 초대를 수락했습니다.');
                } else {
                  _showSnackBar(
                    categoryController.errorMessage ?? '초대 수락에 실패했습니다.',
                  );
                }
              } finally {
                _hideBlockingLoading();
              }
            },
            onDecline: () async {
              Navigator.of(sheetContext).pop();
              _showBlockingLoading();
              try {
                final ok = await categoryController.declineInvite(
                  categoryId: categoryId,
                  userId: currentUser.id,
                );
                if (ok) {
                  await _onRefresh();
                  _showSnackBar('카테고리 초대를 거절했습니다.');
                } else {
                  _showSnackBar(
                    categoryController.errorMessage ?? '초대 거절에 실패했습니다.',
                  );
                }
              } finally {
                _hideBlockingLoading();
              }
            },
          );
        },
      );
      return;
    }

    // 카테고리 추가 알림일 경우, 해당 카테고리로 이동
    if (type == AppNotificationType.categoryAdded) {
      final categoryId =
          notification.relatedId ?? notification.categoryIdForPost;
      if (categoryId == null) {
        _showSnackBar('카테고리 정보를 찾을 수 없습니다.');
        return;
      }

      await _openCategory(categoryId: categoryId, userId: currentUser.id);
      return;
    }

    if (type == AppNotificationType.photoAdded ||
        type == AppNotificationType.commentAdded ||
        type == AppNotificationType.commentAudioAdded) {
      final postId = notification.relatedId;
      final categoryId = notification.categoryIdForPost;

      if (postId == null || categoryId == null) {
        _showSnackBar('게시물 정보를 찾을 수 없습니다.');
        return;
      }

      await _openPostDetail(
        categoryId: categoryId,
        postId: postId,
        userId: currentUser.id,
        notificationId: notification.id,
      );
      return;
    }

    debugPrint('지원하지 않는 알림 타입: ${type.value}');
    _showSnackBar('지원하지 않는 알림 타입입니다.');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xff1c1c1c),
      ),
    );
  }

  void _showBlockingLoading() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xff634D45)),
      ),
    );
  }

  void _hideBlockingLoading() {
    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Future<void> _openCategory({
    required int categoryId,
    required int userId,
  }) async {
    final categoryController = context.read<CategoryController>();

    _showBlockingLoading();
    try {
      await categoryController.loadCategories(userId);
    } finally {
      _hideBlockingLoading();
    }

    if (!mounted) return;

    final category = categoryController.getCategoryById(categoryId);
    if (category == null) {
      Navigator.of(context).pushNamed('/archiving');
      _showSnackBar('카테고리를 찾을 수 없습니다.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ApiCategoryPhotosScreen(category: category),
      ),
    );
  }

  Future<void> _openPostDetail({
    required int categoryId,
    required int postId,
    required int userId,
    int? notificationId,
  }) async {
    final categoryController = context.read<CategoryController>();
    final postController = context.read<PostController>();

    _showBlockingLoading();
    late final List<Post> posts;
    try {
      await categoryController.loadCategories(userId);
      posts = await postController.getPostsByCategory(
        categoryId: categoryId,
        userId: userId,
        notificationId: notificationId,
      );
    } finally {
      _hideBlockingLoading();
    }

    if (!mounted) return;

    final category = categoryController.getCategoryById(categoryId);
    if (category == null) {
      Navigator.of(context).pushNamed('/archiving');
      _showSnackBar('카테고리를 찾을 수 없습니다.');
      return;
    }

    final imagePosts = posts
        .where((post) => post.hasImage)
        .toList(growable: false);
    final initialIndex = imagePosts.indexWhere((post) => post.id == postId);

    if (initialIndex < 0) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ApiCategoryPhotosScreen(category: category),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ApiPhotoDetailScreen(
          allPosts: imagePosts,
          initialIndex: initialIndex,
          categoryName: category.name,
          categoryId: category.id,
        ),
      ),
    );
  }
}
