import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:soi/views/about_feed/feed_home.dart';
import '../theme/theme.dart';
import 'about_archiving/screens/api_archive_main_screen.dart';
import 'about_camera/camera_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'about_friends/friend_management_screen.dart';
import 'about_profile/profile_screen.dart';
import '../api/services/camera_service.dart';

class HomePageNavigationBar extends StatefulWidget {
  final int currentPageIndex;

  /// 전역에서 홈 탭(Archive/Feed/Camera/Friend/Profile)을 바꾸기 위한 키입니다.
  ///
  /// (배포버전 프리즈 방지) `pushAndRemoveUntil`로 홈을 "새로" 만드는 대신,
  /// 기존 홈을 유지한 채 탭만 바꾸도록 유도합니다.
  static final GlobalKey<_HomePageNavigationBarState> _globalKey =
      GlobalKey<_HomePageNavigationBarState>();

  /// `MaterialApp.routes` 등에서 주입할 루트 키 (외부에는 `Key`로만 노출).
  static Key get rootKey => _globalKey;

  /// 현재 살아있는 홈이 있으면 탭만 변경합니다. (없으면 아무 것도 하지 않음)
  static void requestTab(int index) {
    _globalKey.currentState?._setCurrentPageIndex(index);
  }

  const HomePageNavigationBar({super.key, required this.currentPageIndex});

  @override
  State<HomePageNavigationBar> createState() => _HomePageNavigationBarState();
}

class _HomePageNavigationBarState extends State<HomePageNavigationBar> {
  late int _currentPageIndex;
  static const _inactiveColor = Color(0xff535252);
  static const _activeColor = Color(0xffffffff);

  void _setCurrentPageIndex(int index) {
    if (!mounted) return;
    if (_currentPageIndex == index) return;
    setState(() {
      _currentPageIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _currentPageIndex = widget.currentPageIndex;
    unawaited(CameraService.instance.prepareSessionIfPermitted());
  }

  // 잘못된 프로필 이미지 URL을 확인하고 정리하는 함수

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      bottomNavigationBar: Container(
        margin: EdgeInsets.only(top: 10.h),
        height: 70.h,
        child: NavigationBarTheme(
          data: NavigationBarThemeData(backgroundColor: Colors.black),
          child: NavigationBar(
            indicatorColor: Colors.transparent,
            backgroundColor: AppTheme.lightTheme.colorScheme.surface,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            onDestinationSelected: (int index) {
              if (index == 2) {
                unawaited(CameraService.instance.activateSession());
              }

              setState(() {
                _currentPageIndex = index;
              });
            },
            selectedIndex: _currentPageIndex,
            destinations: <Widget>[
              NavigationDestination(
                icon: _buildNavSvgIcon(
                  'assets/home_navi.svg',
                  _inactiveColor,
                  width: 26.sp,
                  height: 23.sp,
                ),
                selectedIcon: _buildNavSvgIcon(
                  'assets/home_navi.svg',
                  _activeColor,
                  width: 26.sp,
                  height: 23.sp,
                ),
                label: '',
              ),
              NavigationDestination(
                icon: _buildNavSvgIcon(
                  'assets/update_navi.svg',
                  _inactiveColor,
                ),
                selectedIcon: _buildNavSvgIcon(
                  'assets/update_navi.svg',
                  _activeColor,
                ),
                label: '',
              ),
              NavigationDestination(
                icon: _buildNavSvgIcon('assets/add_navi.svg', _inactiveColor),
                selectedIcon: _buildNavSvgIcon(
                  'assets/add_navi.svg',
                  _activeColor,
                ),
                label: '',
              ),
              NavigationDestination(
                icon: _buildNavSvgIcon(
                  'assets/friend_navi.svg',
                  _inactiveColor,
                  width: 29.sp,
                  height: 22.sp,
                ),
                selectedIcon: _buildNavSvgIcon(
                  'assets/friend_navi.svg',
                  _activeColor,
                  width: 29.sp,
                  height: 22.sp,
                ),
                label: '',
              ),
              NavigationDestination(
                icon: _buildNavSvgIcon(
                  'assets/profile_navi.svg',
                  _inactiveColor,
                  width: 28.sp,
                  height: 28.sp,
                ),
                selectedIcon: _buildNavSvgIcon(
                  'assets/profile_navi.svg',
                  _activeColor,
                  width: 28.sp,
                  height: 28.sp,
                ),
                label: '',
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentPageIndex,
        children: [
          _buildPage(0, const APIArchiveMainScreen()),
          _buildPage(1, const FeedHomeScreen()),
          _buildPage(2, CameraScreen(isActive: _currentPageIndex == 2)),
          _buildPage(3, const FriendManagementScreen()),
          _buildPage(4, const ProfileScreen()),
        ],
      ),
    );
  }

  Widget _buildNavSvgIcon(
    String assetPath,
    Color color, {
    double? width,
    double? height,
  }) {
    return SvgPicture.asset(
      assetPath,
      width: width ?? 25.sp,
      height: height ?? 25.sp,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  Widget _buildPage(int index, Widget child) {
    return TickerMode(enabled: _currentPageIndex == index, child: child);
  }
}
