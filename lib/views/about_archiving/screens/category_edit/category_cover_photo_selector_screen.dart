import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:soi/api_firebase/controllers/category_cover_photo_controller.dart';
import '../../../../api_firebase/controllers/media_controller.dart';
import '../../../../api_firebase/models/category_data_model.dart';

/// 카테고리 표지사진 선택 화면
class CategoryCoverPhotoSelectorScreen extends StatefulWidget {
  final CategoryDataModel category;

  const CategoryCoverPhotoSelectorScreen({super.key, required this.category});

  @override
  State<CategoryCoverPhotoSelectorScreen> createState() =>
      _CategoryCoverPhotoSelectorScreenState();
}

class _CategoryCoverPhotoSelectorScreenState
    extends State<CategoryCoverPhotoSelectorScreen> {
  String? selectedPhotoUrl;

  @override
  void initState() {
    super.initState();
    // 카테고리 사진들 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PhotoController>().loadPhotosByCategory(widget.category.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        title: Text(
          '표지사진 변경',
          style: TextStyle(
            color: Colors.white,
            fontSize: (20).sp,
            fontWeight: FontWeight.w600,
            fontFamily: 'Pretendard Variable',
          ),
        ),
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Consumer<PhotoController>(
            builder: (context, photoController, child) {
              if (photoController.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFffffff)),
                );
              }

              if (photoController.photos.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 64.sp,
                        color: Colors.grey[600],
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        '아직 사진이 없습니다',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16.sp,
                          fontFamily: 'Pretendard Variable',
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8.w, // 가로 간격
                    mainAxisSpacing: 8.h, // 세로 간격
                    childAspectRatio: 175 / 232,
                  ),
                  itemCount: photoController.photos.length,
                  itemBuilder: (context, index) {
                    final photo = photoController.photos[index];
                    final isSelected = selectedPhotoUrl == photo.imageUrl;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedPhotoUrl = isSelected ? null : photo.imageUrl;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(
                                  color: Colors.white, // 흰색 테두리
                                )
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              // 사진
                              CachedNetworkImage(
                                imageUrl: photo.imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                memCacheWidth: (175 * 2).round(),
                                maxWidthDiskCache: (175 * 2).round(),
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.error,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),

                              // 선택 표시 - 체크 이모지
                              if (isSelected)
                                Positioned(
                                  top: 8.h,
                                  left: 8.w,
                                  child: Container(
                                    width: 24.w,
                                    height: 24.h,
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        '✓', // 체크 이모지
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: (14).sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                width: 349.w,
                height: 50.h,

                child: ElevatedButton(
                  onPressed: _updateCoverPhoto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (selectedPhotoUrl == null)
                        ? const Color(0xFF5a5a5a)
                        : const Color(0xFFf9f9f9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26.9),
                    ),
                  ),
                  child: Text(
                    '확인',
                    style: TextStyle(
                      color: (selectedPhotoUrl == null)
                          ? Colors.white
                          : Colors.black,
                      fontSize: (16).sp,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Pretendard Variable',
                    ),
                  ),
                ),
              ),
              SizedBox(height: 30.h),
            ],
          ),
        ],
      ),
    );
  }

  /// 표지사진 업데이트
  void _updateCoverPhoto() async {
    if (selectedPhotoUrl == null) return;

    final categoryPhotoController = context
        .read<CategoryCoverPhotoController>();

    final success = await categoryPhotoController.updateCoverPhotoFromCategory(
      categoryId: widget.category.id,
      photoUrl: selectedPhotoUrl!,
    );

    if (success && mounted) {
      Navigator.pop(context, selectedPhotoUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('표지사진이 변경되었습니다.'),
          backgroundColor: Color(0xFF5a5a5a),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(categoryPhotoController.error ?? '표지사진 변경에 실패했습니다.'),
          backgroundColor: const Color(0xFF5a5a5a),
        ),
      );
    }
  }
}
