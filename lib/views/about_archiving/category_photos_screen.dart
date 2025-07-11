import 'package:flutter/material.dart';
import '../../controllers/category_controller.dart';
import 'package:provider/provider.dart';
import '../../theme/theme.dart';
import '../../models/photo_data_model.dart';
import 'photo_grid_item.dart'; // 상세 화면 임포트

class CategoryPhotosScreen extends StatelessWidget {
  final String categoryId; // 카테고리 ID를 외부에서 전달
  final String categoryName; // 카테고리 이름을 외부에서 전달

  const CategoryPhotosScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    final categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: Colors.white, //색변경
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(categoryName, style: const TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: categoryController.getPhotosStream(categoryId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // Convert Map data to PhotoModel objects using helper method
          final photos =
              (snapshot.data ?? [])
                  .map((photoMap) => PhotoDataModel.fromMapData(photoMap))
                  .toList();

          if (photos.isEmpty) {
            return const Center(
              child: Text('사진이 없습니다.', style: TextStyle(color: Colors.white)),
            );
          }

          // MasonryGridView를 사용하여 사진들을 다양한 높이로 배치
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.7,
            ),
            padding: const EdgeInsets.all(8.0),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photo = photos[index];
              // 랜덤 높이: 200 ~ 350 사이 (예시)

              return PhotoGridItem(
                photo: photo,
                allPhotos: photos,
                currentIndex: index,
                categoryName: categoryName,
                categoryId: categoryId,
              );
            },
          );
        },
      ),
    );
  }
}
