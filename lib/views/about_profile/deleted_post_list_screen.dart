import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shimmer/shimmer.dart';
import 'package:soi/api_firebase/controllers/auth_controller.dart';
import '../../api_firebase/controllers/photo_controller.dart';
import '../../api_firebase/models/photo_data_model.dart';

class DeletedPostListScreen extends StatefulWidget {
  const DeletedPostListScreen({super.key});

  @override
  State<DeletedPostListScreen> createState() => _DeletedPostListScreenState();
}

class _DeletedPostListScreenState extends State<DeletedPostListScreen> {
  List<MediaDataModel> _deletedPosts = [];
  List<MediaDataModel> selectedPosts = [];
  Map<MediaDataModel, bool> isSelected = {};
  bool _isLoading = true;
  String? _error;

  // Controllers 주입을 늦춰서 initState에서 초기화
  late final PhotoController _photoController;
  late final AuthController _authController;

  @override
  void initState() {
    super.initState();

    // 여기서 컨트롤러들을 초기화 하여서 해당 위젯에서만 컨트롤러를 사용하도록 한다.
    _photoController = PhotoController();
    _authController = AuthController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDeletedPosts();
    });
  }

  @override
  void dispose() {
    _photoController.dispose();
    _authController.dispose();
    super.dispose();
  }

  Future<void> _loadDeletedPosts() async {
    final user = _authController.currentUser;
    if (user == null) {
      setState(() {
        _error = '로그인이 필요합니다.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // PhotoController를 통해 삭제된 사진 로드
      await _photoController.loadDeletedPhotosByUser(user.uid);

      setState(() {
        _deletedPosts = _photoController.deletedPhotos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '게시물 복구',
              textAlign: TextAlign.start,
              style: TextStyle(
                color: const Color(0xFFF8F8F8),
                fontSize: 20.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          _buildBody(),
          Positioned(
            bottom: 40.h,

            child: SizedBox(
              width: 349.w,
              height: 50.h,
              child: ElevatedButton(
                onPressed: selectedPosts.isNotEmpty
                    ? _restoreSelectedPosts
                    : () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedPosts.isNotEmpty
                      ? Colors.white
                      : const Color(0xFF595959),

                  disabledBackgroundColor: const Color(0xFF595959),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26.90),
                  ),
                ),
                child: Text(
                  '게시물에 표시',
                  style: TextStyle(
                    color: selectedPosts.isNotEmpty
                        ? Colors.black
                        : Colors.white,
                    fontSize: 18,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '오류가 발생했습니다',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              _error!,
              style: TextStyle(
                color: const Color(0xFFB0B0B0),
                fontSize: 14.sp,
                fontFamily: 'Pretendard',
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _loadDeletedPosts,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_deletedPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64.sp,
              color: const Color(0xFF666666),
            ),
            SizedBox(height: 16.h),
            Text(
              '삭제한 게시물이 없습니다',
              style: TextStyle(
                color: const Color(0xFFB0B0B0),
                fontSize: 16.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(16.w),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 13.h,
          childAspectRatio: 175 / 233, // 175:233 비율
        ),
        itemCount: _deletedPosts.length,
        itemBuilder: (context, index) {
          return _buildDeletedPostItem(_deletedPosts[index], index);
        },
      ),
    );
  }

  Widget _buildDeletedPostItem(MediaDataModel photo, int index) {
    final bool isPhotoSelected = isSelected[photo] ?? false;

    return GestureDetector(
      onTap: () {
        _togglePhotoSelection(photo);
      },
      child: Container(
        width: 175,
        height: 233,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFF1C1C1C),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: photo.imageUrl,
                fit: BoxFit.cover,
                width: 175,
                height: 233,
                memCacheWidth: (175 * 2).round(),
                maxWidthDiskCache: (175 * 2).round(),
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: const Color(0xFF333333),
                  highlightColor: const Color(0xFF555555),
                  child: Container(
                    width: 175,
                    height: 233,
                    decoration: BoxDecoration(
                      color: const Color(0xFF333333),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: const Color(0xFF333333),
                  child: Icon(Icons.image, color: Colors.white54, size: 48.sp),
                ),
              ),
              // 선택 오버레이
              if (isPhotoSelected)
                Container(
                  width: 175,
                  height: 233,
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              // 체크마크
              if (isPhotoSelected)
                Positioned(
                  top: 8.h,
                  left: 8.w,
                  child: Container(
                    width: 24.w,
                    height: 24.h,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, color: Colors.white, size: 16.sp),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _togglePhotoSelection(MediaDataModel photo) {
    setState(() {
      final bool currentlySelected = isSelected[photo] ?? false;
      if (currentlySelected) {
        isSelected[photo] = false;
        selectedPosts.remove(photo);
      } else {
        isSelected[photo] = true;
        selectedPosts.add(photo);
      }
    });
  }

  Future<void> _restoreSelectedPosts() async {
    final user = _authController.currentUser;
    if (user == null) return;

    if (selectedPosts.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    int successCount = 0;
    int failCount = 0;

    for (final photo in selectedPosts) {
      try {
        final success = await _photoController.restorePhoto(
          categoryId: photo.categoryId,
          photoId: photo.id,
          userId: user.uid,
        );

        if (success) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        debugPrint('사진 복원 오류: $e');
        failCount++;
      }
    }
    // 선택 상태 초기화
    setState(() {
      selectedPosts.clear();
      isSelected.clear();
    });

    // 삭제된 사진 목록 다시 로드
    await _loadDeletedPosts();

    // 사용자에게 결과 알림
    if (mounted) {
      String message;
      if (failCount == 0) {
        message = '${successCount}개의 게시물이 복원되었습니다';
      } else if (successCount == 0) {
        message = '게시물 복원에 실패했습니다';
      } else {
        message = '${successCount}개 복원 성공, ${failCount}개 실패';
      }

      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.white,
        textColor: Colors.black,
        fontSize: 14.sp,
      );
    }
  }
}
