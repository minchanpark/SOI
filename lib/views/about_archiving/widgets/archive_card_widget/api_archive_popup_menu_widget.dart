import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../../api/controller/category_controller.dart';
import '../../../../api/controller/user_controller.dart';
import '../../../../api/models/category.dart';
import '../archive_category_dialogs.dart';
import 'animated_menu_overlay.dart';

/// REST API 기반 아카이브 팝업 메뉴 위젯
/// 카테고리 카드의 더보기 메뉴를 담당합니다.
/// 부드러운 scale + fade 애니메이션 적용
class ApiArchivePopupMenuWidget extends StatefulWidget {
  final Category category;
  final VoidCallback? onEditName;
  final Widget child;

  const ApiArchivePopupMenuWidget({
    super.key,
    required this.category,
    required this.child,
    this.onEditName,
  });

  @override
  State<ApiArchivePopupMenuWidget> createState() =>
      _ApiArchivePopupMenuWidgetState();
}

class _ApiArchivePopupMenuWidgetState extends State<ApiArchivePopupMenuWidget>
    with SingleTickerProviderStateMixin {
  // 애니메이션 컨트롤러
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // 오버레이 관련
  OverlayEntry? _overlayEntry;
  final GlobalKey _buttonKey = GlobalKey();
  bool _isMenuOpen = false;

  CategoryController? categoryController;
  UserController? userController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // Scale 애니메이션: 0.8 → 1.0 (easeOutBack으로 자연스러운 탄성 효과)
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    // Fade 애니메이션: 0.0 → 1.0
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _closeMenu();
    _animationController.dispose();
    super.dispose();
  }

  /// 메뉴 열기
  void _openMenu() {
    if (_isMenuOpen) return;

    // 버튼 위치 및 크기 가져오기
    final RenderBox? renderBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;

    // 렌더박스가 없으면 종료
    if (renderBox == null) return;

    // 버튼 위치
    final Offset buttonPosition = renderBox.localToGlobal(Offset.zero);

    // 버튼 크기
    final Size buttonSize = renderBox.size;

    _overlayEntry = OverlayEntry(
      // 애니메이션이 적용된 메뉴 오버레이 위젯 사용
      // 메뉴 팝업이 Scale + Fade 애니메이션으로 부드럽게 나타남
      builder: (context) => AnimatedMenuOverlay(
        scaleAnimation: _scaleAnimation,
        fadeAnimation: _fadeAnimation,
        buttonPosition: buttonPosition,
        buttonSize: buttonSize,
        menuWidget: _buildMenuContent(),
        onDismiss: _closeMenu,
      ),
    );

    // 오버레이 삽입
    // 현재 컨텍스트의 오버레이에 메뉴 오버레이를 삽입하여 화면에 표시
    Overlay.of(context).insert(_overlayEntry!);
    _isMenuOpen = true;
    _animationController.forward();
  }

  /// 메뉴 닫기
  Future<void> _closeMenu() async {
    if (!_isMenuOpen) return;

    await _animationController.reverse();
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isMenuOpen = false;
  }

  /// 메뉴 토글
  void _toggleMenu() {
    if (_isMenuOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _buttonKey,
      onTap: _toggleMenu,
      child: widget.child,
    );
  }

  /// 메뉴 콘텐츠 빌드
  Widget _buildMenuContent() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 151.w,
        decoration: BoxDecoration(
          color: const Color(0xFF323232),
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8.0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _buildMenuItems(),
        ),
      ),
    );
  }

  /// 메뉴 아이템들 생성
  List<Widget> _buildMenuItems() {
    final isPinnedForCurrentUser = widget.category.isPinned;

    return [
      // 이름 수정 메뉴
      _buildCustomMenuItem(
        icon: 'assets/category_edit.png',
        text: '이름 수정',
        textColor: Colors.white,
        onPressed: () => _handleMenuAction('edit_name'),
      ),

      // 구분선
      Divider(color: const Color(0xff5a5a5a), height: 1.h),

      // 고정/고정 해제 메뉴
      _buildCustomMenuItem(
        icon: 'assets/pin.png',
        text: isPinnedForCurrentUser ? '고정 해제' : '고정',
        textColor: Colors.white,
        onPressed: () =>
            _handleMenuAction(isPinnedForCurrentUser ? 'unpin' : 'pin'),
      ),

      // 구분선
      Divider(color: const Color(0xff5a5a5a), height: 1.h),

      // 나가기 메뉴
      _buildCustomMenuItem(
        icon: 'assets/category_delete.png',
        text: '나가기',
        textColor: Color(0xFFFF0000),
        onPressed: () => _handleMenuAction('leave'),
      ),
    ];
  }

  /// 커스텀 메뉴 아이템 생성
  Widget _buildCustomMenuItem({
    required String icon,
    required String text,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 151.w,
        height: (36.1).h,
        padding: EdgeInsets.only(left: 10.w),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(0),
        ),
        child: Row(
          children: [
            // 아이콘
            Image.asset(icon, width: 10.w, height: 10.h),
            SizedBox(width: 10.w),
            // 텍스트
            Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: (13.4).sp,
                fontWeight: FontWeight.w400,
                fontFamily: 'Pretendard Variable',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 메뉴 액션 처리
  Future<void> _handleMenuAction(String action) async {
    // 메뉴 먼저 닫기 (완료될 때까지 대기)
    await _closeMenu();

    // 위젯이 언마운트되었으면 중단
    if (!mounted) return;

    // 액션 처리
    switch (action) {
      case 'edit_name':
        if (widget.onEditName != null) {
          widget.onEditName!();
        }
        break;
      case 'pin':
      case 'unpin':
        userController = Provider.of<UserController>(context, listen: false);
        categoryController = Provider.of<CategoryController>(
          context,
          listen: false,
        );
        final userId = userController!.currentUser?.id;
        if (userId == null) return;

        // API 호출 - toggleCategoryPin은 항상 성공하면 새 상태를 반환
        // true = 고정됨, false = 고정 해제됨 (둘 다 성공)
        try {
          await categoryController!.toggleCategoryPin(
            categoryId: widget.category.id,
            userId: userId,
          );

          categoryController!.invalidateCache();

          // 모든 필터의 카테고리를 순차적으로 로드
          await categoryController!.loadCategories(
            userId,
            filter: CategoryFilter.all,
            forceReload: true,
          );
          await categoryController!.loadCategories(
            userId,
            filter: CategoryFilter.public_,
            forceReload: true,
          );
          await categoryController!.loadCategories(
            userId,
            filter: CategoryFilter.private_,
            forceReload: true,
          );
        } catch (e) {
          debugPrint('[Pin] API 호출 실패: $e');
        }
        break;
      case 'leave':
        // ArchiveCategoryDialogs 사용
        ArchiveCategoryDialogs.showLeaveCategoryBottomSheetApi(
          context,
          widget.category,
          onConfirm: _leaveCategory,
        );
        break;
    }
  }

  Future<void> _leaveCategory() async {
    try {
      userController = Provider.of<UserController>(context, listen: false);
      categoryController = Provider.of<CategoryController>(
        context,
        listen: false,
      );

      final userId = userController!.currentUser?.id;
      if (userId == null) {
        _showSnackBar('로그인이 필요합니다.');
        return;
      }

      // API 호출 - 카테고리 나가기
      final success = await categoryController!.leaveCategory(
        userId: userId,
        categoryId: widget.category.id,
      );

      if (success) {
        await categoryController!.loadCategories(userId, forceReload: true);
        _showSnackBar('카테고리에서 나갔습니다.');
      } else {
        _showSnackBar('카테고리 나가기에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('[LeaveCategory] 실패: $e');
      _showSnackBar('카테고리 나가기에 실패했습니다.');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }
}
