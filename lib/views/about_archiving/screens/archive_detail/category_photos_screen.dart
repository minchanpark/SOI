import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:soi/api_firebase/controllers/category_controller.dart';
import 'package:provider/provider.dart';

import '../../../../api_firebase/controllers/auth_controller.dart';

import '../../../../api_firebase/controllers/media_controller.dart';
import '../../../../api_firebase/models/category_data_model.dart';
import '../../../../api_firebase/models/photo_data_model.dart';
import '../../../../theme/theme.dart';
import '../../widgets/photo_grid_item.dart';
import '../../widgets/category_members_bottom_sheet.dart';
import '../category_edit/category_editor_screen.dart';

/// 카테고리 내 사진들을 그리드 형식으로 보여주는 화면
/// 카테고리 멤버 수, 카테고리 이름 표시 및
/// 카테고리 멤버 목록 및 카테고리 편집 화면으로 이동하는 기능 포함
class CategoryPhotosScreen extends StatefulWidget {
  final CategoryDataModel category;

  const CategoryPhotosScreen({super.key, required this.category});

  @override
  State<CategoryPhotosScreen> createState() => _CategoryPhotosScreenState();
}

class _CategoryPhotosScreenState extends State<CategoryPhotosScreen> {
  @override
  void initState() {
    super.initState();
    _updateUserViewTime();
  }

  // 카테고리 내 사진 확인 시간을 업데이트
  void _updateUserViewTime() async {
    final authController = Provider.of<AuthController>(context, listen: false);
    final categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );
    final userId = authController.getUserId;

    if (userId != null) {
      await categoryController.updateUserViewTime(
        categoryId: widget.category.id,
        userId: userId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoController = Provider.of<PhotoController>(
      context,
      listen: false,
    );
    final categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );

    final userId =
        Provider.of<AuthController>(context, listen: false).getUserId ??
        '카테고리 이름 오류';

    return StreamBuilder<CategoryDataModel?>(
      stream: categoryController.streamSingleCategory(widget.category.id),
      builder: (context, categorySnapshot) {
        final currentCategory = categorySnapshot.data ?? widget.category;

        return Scaffold(
          backgroundColor: AppTheme.lightTheme.colorScheme.surface,
          appBar: AppBar(
            toolbarHeight: 90.h,
            iconTheme: IconThemeData(color: Colors.white),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  // 사용자별 커스텀 이름 우선 적용
                  currentCategory.getDisplayName(userId),
                  style: TextStyle(
                    color: const Color(0xFFD9D9D9),
                    fontSize: 20,
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Spacer(),
                InkWell(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (context) =>
                          CategoryMembersBottomSheet(category: currentCategory),
                    );
                  },
                  borderRadius: BorderRadius.circular(100),

                  child: SizedBox(
                    height: 50.h,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people, size: 25.sp, color: Colors.white),
                          SizedBox(width: 2.w),
                          // 카테고리에 있는 사용자의 숫자를 표시 (실시간 업데이트)
                          Text(
                            '${currentCategory.mates.length}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CategoryEditorScreen(category: currentCategory),
                      ),
                    );
                  },
                  icon: Icon(Icons.menu),
                ),
              ],
            ),
            backgroundColor: AppTheme.lightTheme.colorScheme.surface,
          ),
          body: StreamBuilder<List<MediaDataModel>>(
            stream: photoController.getPhotosByCategoryStream(
              currentCategory.id,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3.0,
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40.w),
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(color: Colors.white, fontSize: 16.sp),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final photos = snapshot.data ?? [];

              if (photos.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40.w),
                    child: Text(
                      '사진이 없습니다.',
                      style: TextStyle(color: Colors.white, fontSize: 16.sp),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12.w, // 피그마 디자인에 맞춤: 수평 간격
                  mainAxisSpacing: 15.h, // 피그마 디자인에 맞춤: 수직 간격
                  childAspectRatio: 175 / 233, // 피그마 디자인 비율: 175x233
                ),
                padding: EdgeInsets.only(
                  left: 15.w,
                  right: 15.w,
                  top: 20.h,
                  bottom: 30.h,
                ),

                itemCount: photos.length,
                itemBuilder: (context, index) {
                  final photo = photos[index];

                  return PhotoGridItem(
                    photo: photo,
                    allPhotos: photos,
                    currentIndex: index,
                    categoryName: currentCategory.name,
                    categoryId: currentCategory.id,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
