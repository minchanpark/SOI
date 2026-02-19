import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../about_archiving/widgets/archive_card_widget/animated_menu_overlay.dart';

/// 피드 더보기 메뉴 (삭제 전 확인 다이얼로그 표시)
/// Scale + Fade 애니메이션으로 부드럽게 나타나는 팝업 메뉴
class MoreMenuButton extends StatefulWidget {
  final VoidCallback? onDeletePressed;
  const MoreMenuButton({super.key, this.onDeletePressed});

  @override
  State<MoreMenuButton> createState() => _MoreMenuButtonState();
}

class _MoreMenuButtonState extends State<MoreMenuButton>
    with SingleTickerProviderStateMixin {
  // 애니메이션 컨트롤러
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // 오버레이 관련
  OverlayEntry? _overlayEntry;
  final GlobalKey _buttonKey = GlobalKey();
  bool _isMenuOpen = false;
  bool _isDeleteActionInFlight = false;

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

    if (renderBox == null) return;

    final Offset buttonPosition = renderBox.localToGlobal(Offset.zero);
    final Size buttonSize = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => AnimatedMenuOverlay(
        scaleAnimation: _scaleAnimation,
        fadeAnimation: _fadeAnimation,
        buttonPosition: buttonPosition,
        buttonSize: buttonSize,
        menuWidget: _buildMenuContent(),
        onDismiss: _closeMenu,
        menuWidth: 173,
        menuHeight: 45,
      ),
    );

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
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Icon(
          Icons.more_vert,
          size: 25.sp,
          color: const Color(0xfff9f9f9),
        ),
      ),
    );
  }

  /// 메뉴 콘텐츠 빌드
  Widget _buildMenuContent() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 173.w,
        height: 45.h,
        decoration: BoxDecoration(
          color: const Color(0xFF323232),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: GestureDetector(
          onTap: () {
            unawaited(_handleDeleteAction());
          },
          child: Container(
            padding: EdgeInsets.only(left: (13.96).w),
            child: Row(
              children: [
                Image.asset(
                  'assets/trash_red.png',
                  width: (11.16).sp,
                  height: (12.56).sp,
                  color: Colors.red,
                ),
                SizedBox(width: 10.w),
                Text(
                  '삭제',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: (15.35).sp,
                    fontFamily: 'Pretendard Variable',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 삭제 액션 처리
  Future<void> _handleDeleteAction() async {
    if (_isDeleteActionInFlight) return;
    _isDeleteActionInFlight = true;

    try {
      await _closeMenu();
      await _showDeleteConfirmation(widget.onDeletePressed);
    } finally {
      _isDeleteActionInFlight = false;
    }
  }

  /// 삭제 확인 바텀시트 표시
  Future<void> _showDeleteConfirmation(VoidCallback? onDeletePressed) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xff323232),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 17.h),
              Text(
                '사진 삭제',
                style: TextStyle(
                  color: const Color(0xFFF8F8F8),
                  fontSize: 19.78.sp,
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Text(
                  '사진 삭제 시 해당 카테고리에서 확인할 수 없으며,\n30일 이내에 복구가 가능합니다',
                  style: TextStyle(
                    color: const Color(0xFFF8F8F8),
                    fontSize: 14.sp,
                    fontFamily: 'Pretendard Variable',
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 12.h),
              SizedBox(
                height: 38.h,
                width: 344.w,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xfff5f5f5),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.2.r),
                    ),
                  ),
                  child: Text(
                    '삭제',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      fontSize: 17.8.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 13.h),
              SizedBox(
                height: 38.h,
                width: 344.w,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF323232),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.2.r),
                    ),
                  ),
                  child: Text(
                    '취소',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w500,
                      fontSize: 17.8.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 30.h),
            ],
          ),
        );
      },
    );

    if (confirmed == true) {
      if (!mounted) return;
      onDeletePressed?.call();
    }
  }
}
