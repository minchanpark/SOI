import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:soi/views/about_feed/feed_home.dart';
import '../theme/theme.dart';
import 'about_archiving/screens/api_archive_main_screen.dart';
import 'about_camera/camera_screen.dart';
import 'package:antdesign_icons/antdesign_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../api/services/camera_service.dart';

class HomePageNavigationBar extends StatefulWidget {
  final int currentPageIndex;

  /// 전역에서 홈 탭(Feed/Camera/Archive)을 바꾸기 위한 키입니다.
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
              if (index == 1) {
                unawaited(CameraService.instance.activateSession());
              }

              setState(() {
                _currentPageIndex = index;
              });
            },
            selectedIndex: _currentPageIndex,
            destinations: <Widget>[
              NavigationDestination(
                selectedIcon: Icon(
                  AntIcons.homeFilled,
                  size: 31.sp,
                  color: Color(0xffffffff),
                ),
                icon: Icon(
                  AntIcons.homeFilled,
                  size: 31.sp,
                  color: Color(0xff535252),
                ),
                label: '',
              ),
              NavigationDestination(
                icon: SvgPicture.asset(
                  'assets/camera_icon.svg',
                  width: 31.sp,
                  height: 31.sp,
                  colorFilter: ColorFilter.mode(
                    Color(0xff535252),
                    BlendMode.srcIn,
                  ),
                ),
                selectedIcon: SvgPicture.asset(
                  'assets/camera_icon.svg',
                  width: 31.sp,
                  height: 31.sp,
                  colorFilter: ColorFilter.mode(
                    Color(0xffffffff),
                    BlendMode.srcIn,
                  ),
                ),
                label: '',
              ),
              NavigationDestination(
                icon: SvgPicture.asset(
                  'assets/archive_icon.svg',
                  width: 28.sp,
                  height: 25.sp,
                  colorFilter: ColorFilter.mode(
                    Color(0xff535252),
                    BlendMode.srcIn,
                  ),
                ),
                selectedIcon: SvgPicture.asset(
                  'assets/archive_icon.svg',
                  width: 28.sp,
                  height: 25.sp,
                  colorFilter: ColorFilter.mode(
                    Color(0xffffffff),
                    BlendMode.srcIn,
                  ),
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
          _buildPage(0, const FeedHomeScreen()),
          _buildPage(
            1,
            CameraScreen(isActive: _currentPageIndex == 1),
          ),
          _buildPage(2, const APIArchiveMainScreen()),
        ],
      ),
    );
  }

  Widget _buildPage(int index, Widget child) {
    return TickerMode(enabled: _currentPageIndex == index, child: child);
  }
}
