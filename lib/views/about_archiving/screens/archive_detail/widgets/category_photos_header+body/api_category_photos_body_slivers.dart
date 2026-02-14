import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../../api/models/post.dart';
import '../../../../widgets/api_photo_grid_item.dart';
import '../../../../widgets/archive_card_widget/archive_card_placeholders.dart';

/// 카테고리 사진 화면의 본문을 구성하는 다양한 위젯(로딩, 에러, 빈 상태, 그리드 등)을 정의하는 파일
/// 각 위젯은 Sliver 형태로 구현되어, CustomScrollView 내에서 사용될 수 있도록 설계됨
///
/// Parameters:
///   - [padding]: 그리드나 에러 메시지 등에서 사용할 패딩
///   - [gridDelegate]: 사진 그리드의 레이아웃을 정의하는 SliverGridDelegate
///
/// Returns:
///   - [ApiCategoryPhotosLoadingSliver]: 로딩 상태를 나타내는 슬리버
///   : SliverPadding과 SliverGrid를 사용하여, 그리드 형태로 로딩 플레이스홀더를 표시
class ApiCategoryPhotosLoadingSliver extends StatelessWidget {
  final EdgeInsets padding;
  final SliverGridDelegate gridDelegate;

  const ApiCategoryPhotosLoadingSliver({
    super.key,
    required this.padding,
    required this.gridDelegate,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: SliverGrid(
        gridDelegate: gridDelegate,
        delegate: SliverChildBuilderDelegate((context, index) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return ShimmerOnceThenFallbackIcon(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                borderRadius: 8,
                shimmerCycles: 2,
              );
            },
          );
        }, childCount: 6),
      ),
    );
  }
}

/// 카테고리 사진 화면에서 에러가 발생했을 때 보여주는 슬리버
///
/// Parameters:
///   - [errorMessageKey]: 에러 메시지의 로컬라이즈된 키
///   - [onRetry]: 재시도 버튼이 눌렸을 때 호출되는 콜백 함수
///
/// Returns:
///   - SliverFillRemaining을 사용하여 화면 중앙에 에러 메시지와 재시도 버튼을 표시
class ApiCategoryPhotosErrorSliver extends StatelessWidget {
  final String errorMessageKey;
  final Future<void> Function() onRetry;

  const ApiCategoryPhotosErrorSliver({
    super.key,
    required this.errorMessageKey,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                errorMessageKey,
                style: TextStyle(color: Colors.white, fontSize: 16.sp),
                textAlign: TextAlign.center,
              ).tr(),
              SizedBox(height: 16.h),
              ElevatedButton(
                onPressed: () {
                  onRetry();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white24,
                ),
                child: Text(
                  'common.retry',
                  style: TextStyle(color: Colors.white),
                ).tr(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 카테고리 사진 화면에서 사진이 하나도 없을 때 보여주는 슬리버
///
/// Parameters:
///   - 없음
///
/// Returns:
///   - SliverFillRemaining을 사용하여 화면 중앙에 빈 상태 메시지를 표시
class ApiCategoryPhotosEmptySliver extends StatelessWidget {
  const ApiCategoryPhotosEmptySliver({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.w),
          child: Text(
            'archive.empty_photos',
            style: TextStyle(color: Colors.white, fontSize: 16.sp),
            textAlign: TextAlign.center,
          ).tr(),
        ),
      ),
    );
  }
}

/// 카테고리 사진 화면에서 실제 사진 그리드를 보여주는 슬리버
///
/// Parameters:
///   - [posts]: 그리드에 표시할 포스트 목록
///   - [categoryName]: 현재 카테고리의 이름 (포스트 상세 화면에서 사용)
///   - [categoryId]: 현재 카테고리의 ID (포스트 상세 화면에서 사용)
///   - [padding]: 그리드 주변에 적용할 패딩
///   - [gridDelegate]: 사진 그리드의 레이아웃을 정의하는 SliverGridDelegate
///   - [onPostsDeleted]: 포스트가 삭제되었을 때 호출되는 콜백 함수, 삭제된 포스트의 ID 목록을 인자로 받음
///
/// Returns:
///   - SliverPadding과 SliverGrid를 사용하여, 그리드 형태로 포스트를 표시.
///     각 그리드 아이템은 ApiPhotoGridItem 위젯
class ApiCategoryPhotosGridSliver extends StatelessWidget {
  final List<Post> posts;
  final String categoryName;
  final int categoryId;
  final EdgeInsets padding;
  final SliverGridDelegate gridDelegate;
  final ValueChanged<List<int>> onPostsDeleted;

  const ApiCategoryPhotosGridSliver({
    super.key,
    required this.posts,
    required this.categoryName,
    required this.categoryId,
    required this.padding,
    required this.gridDelegate,
    required this.onPostsDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: SliverGrid(
        gridDelegate: gridDelegate,
        delegate: SliverChildBuilderDelegate((context, index) {
          final post = posts[index];
          return ApiPhotoGridItem(
            post: post,
            postUrl: post.postFileUrl ?? '',
            allPosts: posts,
            currentIndex: index,
            categoryName: categoryName,
            categoryId: categoryId,
            initialCommentCount: post.commentCount ?? 0,
            onPostsDeleted: onPostsDeleted,
          );
        }, childCount: posts.length),
      ),
    );
  }
}
