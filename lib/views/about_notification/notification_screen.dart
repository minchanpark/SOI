import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:soi/api_firebase/controllers/photo_controller.dart';
import 'package:soi/views/about_archiving/screens/archive_detail/category_photos_screen.dart';
import 'package:provider/provider.dart';
import '../../api_firebase/controllers/category_controller.dart';
import '../../api_firebase/controllers/notification_controller.dart';
import '../../api_firebase/controllers/auth_controller.dart';
import '../../api_firebase/controllers/friend_request_controller.dart';
import '../../api_firebase/models/notification_model.dart';
import '../../api_firebase/models/photo_data_model.dart';
import '../about_archiving/screens/archive_detail/photo_detail_screen.dart';
import '../../api_firebase/repositories/auth_repository.dart';
import 'widgets/category_invite_confirm_sheet.dart';
import 'widgets/category_invite_friend_list_sheet.dart';
import 'widgets/category_invitee_preview.dart';
import 'widgets/notification_item_widget.dart';

/// 알림 메인 화면
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late NotificationController _notificationController;
  late ScrollController _scrollController;
  late CategoryController _categoryController;
  late PhotoController _photoController;
  final AuthRepository _authRepository = AuthRepository();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _categoryController = context.read<CategoryController>();
    _photoController = context.read<PhotoController>();

    // 알림 실시간 구독 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotifications();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    PaintingBinding.instance.imageCache.clear();
    super.dispose();
  }

  /// 알림 초기화
  void _initializeNotifications() {
    final authController = context.read<AuthController>();
    final user = authController.currentUser;

    if (user != null) {
      _notificationController.startListening(user.uid);

      // 친구 요청 컨트롤러도 초기화
      try {
        final friendRequestController = context.read<FriendRequestController>();
        if (!friendRequestController.isInitialized) {
          friendRequestController.initialize();
        }
      } catch (e) {
        debugPrint('FriendRequestController 초기화 실패: $e');
      }
    }
  }

  /// 스크롤 이벤트 처리 (무한 스크롤)
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      final authController = context.read<AuthController>();
      final user = authController.currentUser;

      if (user != null) {
        _notificationController.loadMoreNotifications(user.uid);
      }
    }
  }

  /// 새로고침 처리
  Future<void> _onRefresh() async {
    final authController = context.read<AuthController>();
    final user = authController.currentUser;

    if (user != null) {
      // 새로고침과 함께 오래된 알림 정리도 수행
      await Future.wait([
        _notificationController.refreshNotifications(user.uid),
        _notificationController.cleanupOldNotifications(user.uid),
      ]);
    }
  }

  Future<List<String>> _loadUnknownMembers(
    NotificationModel notification,
  ) async {
    final authController = context.read<AuthController>();
    final currentUser = authController.currentUser;
    if (currentUser == null) {
      return [];
    }

    if (notification.pendingCategoryMemberIds != null &&
        notification.pendingCategoryMemberIds!.isNotEmpty) {
      return notification.pendingCategoryMemberIds!;
    }

    return _notificationController.getUnknownCategoryMembers(
      notification: notification,
      currentUserId: currentUser.uid,
    );
  }

  Future<List<CategoryInviteePreview>> _fetchInviteeInfos(
    List<String> userIds,
  ) async {
    final List<CategoryInviteePreview> results = [];

    for (final uid in userIds) {
      try {
        final user = await _authRepository.getUser(uid);
        if (user != null) {
          final displayName = user.name.isNotEmpty
              ? user.name
              : (user.id.isNotEmpty ? user.id : uid);
          final handle = user.id.isNotEmpty ? user.id : uid;
          results.add(
            CategoryInviteePreview(
              uid: uid,
              displayName: displayName,
              id: handle,
              profileImageUrl: user.profileImage,
            ),
          );
          continue;
        }
      } catch (_) {
        // 무시하고 기본 정보로 대체
        debugPrint('사용자 정보 로드 실패: $uid');
      }

      results.add(
        CategoryInviteePreview(
          uid: uid,
          displayName: uid,
          id: uid,
          profileImageUrl: '',
        ),
      );
    }

    return results;
  }

  Future<void> _handleCategoryInviteConfirm(
    NotificationModel notification,
  ) async {
    final authController = context.read<AuthController>();
    final currentUser = authController.currentUser;
    if (currentUser == null) {
      _showErrorSnackBar('로그인이 필요합니다');
      return;
    }

    await _notificationController.onNotificationTap(notification);

    try {
      final List<String> unknownMembers =
          notification.pendingCategoryMemberIds != null
          ? List<String>.from(notification.pendingCategoryMemberIds!)
          : await _notificationController.getUnknownCategoryMembers(
              notification: notification,
              currentUserId: currentUser.uid,
            );

      if (unknownMembers.isEmpty && !notification.requiresAcceptance) {
        _navigateToCategory(notification);
        return;
      }

      final categoryId = notification.categoryId;
      if (categoryId == null || categoryId.isEmpty) {
        _showErrorSnackBar('카테고리 정보를 찾을 수 없습니다');
        return;
      }

      final category = await _categoryController.getCategory(categoryId);
      if (category == null) {
        _showErrorSnackBar('카테고리를 찾을 수 없습니다');
        return;
      }

      final memberIds = category.mates.toSet().toList();
      final inviteeTargets = memberIds.isNotEmpty ? memberIds : unknownMembers;

      final inviteeInfos = await _fetchInviteeInfos(inviteeTargets);

      if (!mounted) {
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return CategoryInviteConfirmSheet(
            categoryName: notification.categoryName ?? category.name,
            categoryImageUrl: category.categoryPhotoUrl ?? '',
            invitees: inviteeInfos,
            onAccept: () async {
              Navigator.of(sheetContext).pop();
              if (notification.requiresAcceptance) {
                await _acceptCategoryInvite(notification, currentUser.uid);
              } else {
                _navigateToCategory(notification);
              }
            },
            onDecline: () async {
              Navigator.of(sheetContext).pop();
              if (notification.requiresAcceptance) {
                await _declineCategoryInvite(notification, currentUser.uid);
              } else {
                await _notificationController.deleteNotification(
                  notification.id,
                );
                _showSuccessSnackBar('초대를 거절했습니다.');
              }
            },
            onViewFriends: inviteeInfos.isEmpty
                ? null
                : () => _showInviteeListSheet(sheetContext, inviteeInfos),
          );
        },
      );
    } catch (e) {
      _showErrorSnackBar('카테고리 정보를 불러오지 못했습니다');
      debugPrint('❌ 카테고리 초대 확인 실패: $e');
    }
  }

  Future<void> _showInviteeListSheet(
    BuildContext context,
    List<CategoryInviteePreview> invitees,
  ) async {
    if (invitees.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (listContext) {
        return CategoryInviteFriendListSheet(
          invitees: invitees,
          onInviteeTap: (invitee) {
            Navigator.of(listContext).pop();
          },
        );
      },
    );
  }

  Future<void> _acceptCategoryInvite(
    NotificationModel notification,
    String currentUserId,
  ) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xff634D45)),
      ),
    );

    final result = await _notificationController.acceptCategoryInvite(
      notification: notification,
      currentUserId: currentUserId,
    );

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (!mounted) return;

    if (result.isSuccess) {
      _showSuccessSnackBar('카테고리에 참여했습니다.');
      await Future.delayed(const Duration(milliseconds: 200));
      _navigateToCategory(notification);
    } else {
      _showErrorSnackBar(result.error ?? '초대 수락 중 문제가 발생했습니다');
    }
  }

  Future<void> _declineCategoryInvite(
    NotificationModel notification,
    String currentUserId,
  ) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xff634D45)),
      ),
    );

    final result = await _notificationController.declineCategoryInvite(
      notification: notification,
      currentUserId: currentUserId,
    );

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (!mounted) return;

    if (result.isSuccess) {
      _showSuccessSnackBar('초대를 거절했습니다.');
    } else {
      _showErrorSnackBar(result.error ?? '초대 거절 중 문제가 발생했습니다');
    }
  }

  /// 알림 탭 처리 - 타입별 적절한 화면으로 이동
  void _onNotificationTap(NotificationModel notification) {
    _notificationController.onNotificationTap(notification);

    // 알림 타입별 네비게이션
    switch (notification.type) {
      case NotificationType.categoryInvite:
        if (notification.requiresAcceptance) {
          _handleCategoryInviteConfirm(notification);
        } else {
          _navigateToCategory(notification);
        }
        break;
      case NotificationType.photoAdded:
        _navigateToPhoto(notification);
        break;
      case NotificationType.voiceCommentAdded:
        _navigateToPhoto(notification); // 사진으로 이동 (댓글 포함)
        break;
      case NotificationType.friendRequest:
        Navigator.of(context).pushNamed('/friend_requests');
        break;
    }
  }

  /// 카테고리 화면으로 이동
  void _navigateToCategory(NotificationModel notification) async {
    final categoryId = notification.categoryId;
    if (categoryId == null) {
      debugPrint('카테고리 ID가 없습니다');
      return;
    }

    try {
      final category = await _categoryController.getCategory(categoryId);
      if (category == null) {
        debugPrint('카테고리를 찾을 수 없습니다: $categoryId');
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            return CategoryPhotosScreen(category: category);
          },
        ),
      );
      debugPrint('카테고리로 이동: $categoryId');
    } catch (e) {
      debugPrint('카테고리 로드 실패: $e');
    }
  }

  /// 사진 화면으로 이동 - photoAdded, voiceCommentAdded 공통 처리
  void _navigateToPhoto(NotificationModel notification) async {
    final categoryId = notification.categoryId;
    final photoId = notification.photoId;

    if (categoryId == null || categoryId.isEmpty) {
      _showErrorSnackBar('카테고리 정보를 찾을 수 없습니다');
      return;
    }

    if (photoId == null || photoId.isEmpty) {
      _showErrorSnackBar('사진 정보를 찾을 수 없습니다');
      return;
    }

    try {
      // 로딩 인디케이터 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xff634D45)),
        ),
      );

      List<MediaDataModel> photos = [];
      int initialIndex = -1;
      int retryCount = 0;
      const maxRetries = 5;
      const retryDelay = Duration(milliseconds: 500);

      // 먼저 특정 사진이 존재하는지 직접 확인
      debugPrint('🔍 1단계: 특정 사진 직접 조회 시도 - photoId: $photoId');
      final targetPhoto = await _photoController.getPhotoById(
        categoryId: categoryId,
        photoId: photoId,
      );

      if (targetPhoto != null) {
        debugPrint('✅ 특정 사진을 직접 찾았습니다: ${targetPhoto.id}');
      } else {
        debugPrint('❌ 특정 사진을 직접 찾지 못했습니다');
      }

      // 2단계: 스트림으로 재시도하며 사진 목록 가져오기
      debugPrint('🔍 2단계: 스트림으로 재시도');
      // 최대 5번 재시도하며 사진을 찾습니다
      while (retryCount < maxRetries && initialIndex == -1) {
        // Stream에서 최신 사진 목록 가져오기
        final photosStream = _photoController.getPhotosByCategoryStream(
          categoryId,
        );
        photos = await photosStream.first;

        if (photos.isNotEmpty) {
          // 특정 photoId에 해당하는 인덱스 찾기
          initialIndex = photos.indexWhere((photo) => photo.id == photoId);

          if (initialIndex != -1) {
            debugPrint('✅ Stream에서 사진을 찾았습니다: $photoId (인덱스: $initialIndex)');
            break;
          }
        }

        retryCount++;
        if (retryCount < maxRetries) {
          debugPrint('사진을 찾지 못했습니다. ${retryDelay.inMilliseconds}ms 후 재시도...');
          await Future.delayed(retryDelay);
        }
      }

      // 로딩 인디케이터 제거
      Navigator.of(context).pop();

      if (photos.isEmpty) {
        _showErrorSnackBar('카테고리에 사진이 없습니다');
        return;
      }

      // 특정 사진을 찾지 못한 경우 첫 번째 사진으로 대체
      if (initialIndex == -1) {
        initialIndex = 0;
        debugPrint('해당 사진을 찾을 수 없어 첫 번째 사진을 표시합니다: $photoId');
        _showErrorSnackBar('해당 사진을 찾을 수 없어 첫 번째 사진을 보여드립니다');
      }

      // 카테고리 이름 가져오기
      final categoryName =
          notification.categoryName ??
          await _categoryController.getCategoryName(categoryId);

      // PhotoDetailScreen으로 이동
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PhotoDetailScreen(
            photos: photos,
            initialIndex: initialIndex,
            categoryName: categoryName,
            categoryId: categoryId,
          ),
        ),
      );

      debugPrint('사진 상세로 이동: $photoId (인덱스: $initialIndex)');
      if (notification.commentId != null) {
        debugPrint('관련 댓글 ID: ${notification.commentId}');
      }
    } catch (e) {
      debugPrint('사진 로드 실패: $e');
      _showErrorSnackBar('사진을 불러오는 중 오류가 발생했습니다');
    }
  }

  /// 에러 메시지 표시
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2ECC71),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NotificationController(),
      builder: (context, child) {
        _notificationController = context.watch<NotificationController>();

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
      },
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
    if (_notificationController.isLoading &&
        _notificationController.notifications.isEmpty) {
      return _buildLoadingState();
    }

    if (_notificationController.error != null) {
      return _buildErrorState();
    }

    if (_notificationController.notifications.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Consumer로 친구 요청 개수를 확인하여 조건부 렌더링
        Consumer<FriendRequestController>(
          builder: (context, friendRequestController, child) {
            final requestCount =
                friendRequestController.receivedRequests.length;

            return GestureDetector(
              onTap: () {
                // 친구 요청 페이지로 이동
                Navigator.of(context).pushNamed('/friend_requests');
              },
              child: Padding(
                padding: EdgeInsets.only(left: 19.w),
                child: Container(
                  width: 354.w,
                  height: 66.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Color(0xff1c1c1c),
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
                            requestCount > 0
                                ? '보류 중인 요청 $requestCount명'
                                : '받은 요청이 없습니다',
                            style: TextStyle(
                              color: const Color(0xFFCBCBCB),
                              fontSize: 13.sp,
                              fontFamily: 'Pretendard Variable',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      Spacer(),
                      // 친구 요청이 있을 때만 알림 뱃지 표시
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
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 23.sp,
                      ),
                      SizedBox(width: 12.w),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        SizedBox(height: 24.h),
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

  /// 로딩 상태
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: const Color(0xff634D45)),
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
            _notificationController.error ?? '알 수 없는 오류가 발생했습니다',
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
            child: Text('다시 시도'),
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
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xff634D45),

      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        children: [
          // 전체 알림을 감싸는 컨테이너
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Color(0xff1c1c1c),
            ),
            child: Column(
              children: [
                SizedBox(height: 22.h),
                // 알림 아이템들
                for (
                  int i = 0;
                  i < _notificationController.notifications.length;
                  i++
                )
                  NotificationItemWidget(
                    notification: _notificationController.notifications[i],
                    onTap: () => _onNotificationTap(
                      _notificationController.notifications[i],
                    ),
                    onDelete: () => _notificationController.deleteNotification(
                      _notificationController.notifications[i].id,
                    ),
                    loadUnknownMembers:
                        _notificationController.notifications[i].type ==
                            NotificationType.categoryInvite
                        ? () => _loadUnknownMembers(
                            _notificationController.notifications[i],
                          )
                        : null,
                    onConfirm:
                        _notificationController.notifications[i].type ==
                            NotificationType.categoryInvite
                        ? () => _handleCategoryInviteConfirm(
                            _notificationController.notifications[i],
                          )
                        : null,
                    isLast:
                        i == _notificationController.notifications.length - 1 &&
                        !_notificationController.hasMore,
                  ),

                SizedBox(height: 7.h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
