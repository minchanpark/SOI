import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../../api/models/category.dart' as api;
import '../../../../widgets/archive_card_widget/api_archive_profile_row_widget.dart';

/// 카테고리 사진 화면의 헤더를 구성하는 위젯
/// 스크롤에 따라 크기가 변하는 SliverPersistentHeader로 구현되어, 카테고리 이름과 사진, 멤버 수 등을 보여줌
///
/// Parameters:
///   - [category]: 카테고리 정보(이름, 사진 URL, 멤버 수 등)를 담고 있는 객체
///   - [collapsedHeight]: 헤더가 완전히 축소되었을 때의 높이
///   - [expandedHeight]: 헤더가 완전히 확장되었을 때의 높이
///   - [onBackPressed]: 뒤로 가기 버튼이 눌렸을 때 호출되는 콜백 함수
///   - [onMembersPressed]: 멤버 목록 버튼이 눌렸을 때 호출되는 콜백 함수
///   - [onMenuPressed]: 메뉴 버튼이 눌렸을 때 호출되는 콜백 함수
///
/// Returns:
///   - SliverPersistentHeader를 사용하여, 스크롤에 따라 크기가 변하는 헤더를 구현
class ApiCategoryPhotosHeader extends StatelessWidget {
  final api.Category category;
  final String? backgroundImageUrl;
  final String? backgroundImageCacheKey;
  final String? heroTag;
  final double collapsedHeight;
  final double expandedHeight;
  final VoidCallback onBackPressed;
  final VoidCallback onMembersPressed;
  final VoidCallback onMenuPressed;

  const ApiCategoryPhotosHeader({
    super.key,
    required this.category,
    this.backgroundImageUrl,
    this.backgroundImageCacheKey,
    this.heroTag,
    required this.collapsedHeight,
    required this.expandedHeight,
    required this.onBackPressed,
    required this.onMembersPressed,
    required this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _CategoryPhotosHeaderDelegate(
        category: category,
        backgroundImageUrl: backgroundImageUrl,
        backgroundImageCacheKey: backgroundImageCacheKey,
        heroTag: heroTag,
        collapsedHeight: collapsedHeight,
        expandedHeight: expandedHeight,
        onBackPressed: onBackPressed,
        onMembersPressed: onMembersPressed,
        onMenuPressed: onMenuPressed,
      ),
    );
  }
}

class _CategoryPhotosHeaderDelegate extends SliverPersistentHeaderDelegate {
  static const double _kHeroEnabledMaxCollapse = 0.92;

  final api.Category category;
  final String? backgroundImageUrl;
  final String? backgroundImageCacheKey;
  final String? heroTag;
  final double collapsedHeight;
  final double expandedHeight;
  final VoidCallback onBackPressed;
  final VoidCallback onMembersPressed;
  final VoidCallback onMenuPressed;

  const _CategoryPhotosHeaderDelegate({
    required this.category,
    required this.backgroundImageUrl,
    required this.backgroundImageCacheKey,
    required this.heroTag,
    required this.collapsedHeight,
    required this.expandedHeight,
    required this.onBackPressed,
    required this.onMembersPressed,
    required this.onMenuPressed,
  });

  @override
  double get minExtent => collapsedHeight;

  @override
  double get maxExtent => math.max(expandedHeight, collapsedHeight);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final collapseRange = (maxExtent - minExtent).clamp(1.0, double.infinity);
    final t = (shrinkOffset / collapseRange).clamp(0.0, 1.0);
    final eased = Curves.easeInOutCubic.transform(t);
    final backgroundOpacity = (1.0 - Curves.easeOut.transform(t)).clamp(
      0.0,
      1.0,
    );
    final expandedInfoOpacity = (1.0 - Curves.easeIn.transform(t)).clamp(
      0.0,
      1.0,
    );
    final compactTitleOpacity = Curves.easeIn.transform(t);
    final toolbarOverlayOpacity = (Curves.easeIn.transform(t) * 0.94).clamp(
      0.0,
      1.0,
    );
    final toolbarTop = minExtent - kToolbarHeight;
    final toolbarCenterY = toolbarTop + (kToolbarHeight / 2);
    final horizontalPadding = lerpDouble(20.w, 16.w, eased) ?? 16.w;
    final expandedTitleTop = maxExtent - 76.h;
    final compactTitleTop = toolbarCenterY - 12.h;
    final titleTop = lerpDouble(expandedTitleTop, compactTitleTop, eased) ?? 0;
    final largeTitleScale = lerpDouble(1.0, 0.86, eased) ?? 1.0;
    final titleFontSize = 26.sp;
    final topBarItemTop = toolbarCenterY - 20.h;
    final hasBackgroundImage =
        backgroundImageUrl != null && backgroundImageUrl!.isNotEmpty;
    final heroEnabled = t < _kHeroEnabledMaxCollapse;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final decodeWidth = math.max(1, (viewportWidth * devicePixelRatio).round());
    final headerBackground = hasBackgroundImage
        ? CachedNetworkImage(
            key: ValueKey(
              'header_${category.id}_${backgroundImageCacheKey ?? backgroundImageUrl}',
            ),
            imageUrl: backgroundImageUrl!,
            cacheKey: backgroundImageCacheKey,
            useOldImageOnUrlChange: true,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            memCacheWidth: decodeWidth,
            maxWidthDiskCache: decodeWidth,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: const Color(0xFF202020)),
            errorWidget: (_, __, ___) =>
                Container(color: const Color(0xFF202020)),
          )
        : Container(color: const Color(0xFF202020));
    final backgroundWithHero = heroTag != null && hasBackgroundImage
        ? HeroMode(
            enabled: heroEnabled,
            child: Hero(
              tag: heroTag!,
              createRectTween: (begin, end) =>
                  MaterialRectArcTween(begin: begin, end: end),
              transitionOnUserGestures: true,
              child: headerBackground,
            ),
          )
        : headerBackground;

    return RepaintBoundary(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: backgroundOpacity,
                child: backgroundWithHero,
              ),
            ),
            // 배경 이미지 위에 그라데이션 오버레이 추가 (밝은 부분을 어둡게 만들어 글자 가독성 향상)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0.40),
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
            ),
            // 축소된 헤더의 배경에 어두운 오버레이 추가 (글자 가독성 향상)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: minExtent,
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: toolbarOverlayOpacity),
                ),
              ),
            ),
            // 축소된 헤더의 왼쪽 상단에 뒤로 가기 버튼과 카테고리 이름 표시
            Positioned(
              left: 4.w,
              top: topBarItemTop,
              child: Row(
                children: [
                  _HeaderIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: onBackPressed,
                  ),
                  Opacity(
                    opacity: compactTitleOpacity,
                    child: Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFFF2F2F2),
                        fontSize: 20.sp,
                        fontFamily: GoogleFonts.inter().fontFamily,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // "확장된 헤더와 축소된 헤더"의 오른쪽 상단에 멤버 수와 메뉴 버튼 표시
            Positioned(
              right: 8.w,
              top: topBarItemTop,
              child: Row(
                children: [
                  _HeaderMembersAction(
                    count: category.totalUserCount,
                    onTap: onMembersPressed,
                  ),
                  SizedBox(width: 6.w),
                  _HeaderIconButton(icon: Icons.menu, onTap: onMenuPressed),
                ],
              ),
            ),

            // 확장된 헤더 중앙에 카테고리 이름과 멤버 수를 표시
            Positioned(
              left: horizontalPadding,
              right: horizontalPadding,
              top: titleTop,
              child: Opacity(
                opacity: expandedInfoOpacity,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 카테고리 이름
                    Expanded(
                      child: Transform.scale(
                        scale: largeTitleScale,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFFF9F9F9),
                            fontSize: titleFontSize,
                            fontFamily: "Pretendard Variable",
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    // 멤버 수가 0보다 클 때만 멤버 아이콘과 숫자 표시
                    if (category.totalUserCount > 0) SizedBox(width: 12.w),
                    if (category.totalUserCount > 0)
                      ApiArchiveProfileRowWidget(
                        avatarSize: (26.94).sp,
                        profileUrlKeys: category.usersProfileKey,
                        totalUserCount: category.totalUserCount,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CategoryPhotosHeaderDelegate oldDelegate) {
    return oldDelegate.collapsedHeight != collapsedHeight ||
        oldDelegate.expandedHeight != expandedHeight ||
        oldDelegate.backgroundImageUrl != backgroundImageUrl ||
        oldDelegate.backgroundImageCacheKey != backgroundImageCacheKey ||
        oldDelegate.heroTag != heroTag ||
        oldDelegate.category.name != category.name ||
        oldDelegate.category.totalUserCount != category.totalUserCount ||
        !listEquals(
          oldDelegate.category.usersProfileKey,
          category.usersProfileKey,
        );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 40.w,
          height: 40.h,
          child: Icon(icon, color: Colors.white, size: 23.sp),
        ),
      ),
    );
  }
}

class _HeaderMembersAction extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _HeaderMembersAction({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 6.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people, size: 21.sp, color: Colors.white),
              SizedBox(width: 2.w),
              Text(
                '$count',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
