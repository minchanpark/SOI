import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:soi/views/about_feed/feed_home.dart';
import '../theme/theme.dart';
import 'about_archiving/screens/api_archive_main_screen.dart';
import 'about_camera/camera_screen.dart';
import 'package:antdesign_icons/antdesign_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomePageNavigationBar extends StatefulWidget {
  final int currentPageIndex;

  const HomePageNavigationBar({super.key, required this.currentPageIndex});

  @override
  State<HomePageNavigationBar> createState() => _HomePageNavigationBarState();
}

class _HomePageNavigationBarState extends State<HomePageNavigationBar> {
  late int _currentPageIndex;

  @override
  void initState() {
    super.initState();
    _currentPageIndex = widget.currentPageIndex;
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
            _currentPageIndex == 1 ? const CameraScreen() : Container(),
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
