import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';

class PostManagementScreen extends StatefulWidget {
  const PostManagementScreen({super.key});

  @override
  State<PostManagementScreen> createState() => _PostManagementScreenState();
}

class _PostManagementScreenState extends State<PostManagementScreen> {
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 필요한 초기화 작업
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
              tr('post_management.title', context: context),
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
      body: SingleChildScrollView(child: _buildBody()),
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
              tr('common.error_occurred', context: context),
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
              onPressed: () {
                setState(() {
                  _error = null;
                  _isLoading = false;
                });
              },
              child: Text(tr('common.retry', context: context)),
            ),
          ],
        ),
      );
    }

    // 게시물 관리 메인 컨텐츠
    return Center(
      child: Column(
        children: [
          SizedBox(height: 29.h),
          /* ElevatedButton(
            onPressed: () {
              // 게시물 목록 보기 기능
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF1C1C1E),
              overlayColor: Color(0xffffffff).withValues(alpha: 0.1),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: SizedBox(
              width: 358.w,
              height: 62,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 19.w),
                  Image.asset(
                    "assets/saved_post_icon.png",
                    width: 26.w,
                    height: 26.h,
                    fit: BoxFit.cover,
                  ),
                  SizedBox(width: 28.w),
                  Text(
                    '보관된 게시물',
                    style: TextStyle(
                      color: const Color(0xFFF8F8F8),
                      fontSize: 17.sp,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),*/

          // SizedBox(height: 13.h),
          ElevatedButton(
            onPressed: () {
              // 아카이브 관리 기능
              Navigator.pushNamed(context, '/delete_photo');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF1C1C1E),
              overlayColor: Color(0xffffffff).withValues(alpha: 0.1),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: SizedBox(
              width: 358.w,
              height: 62,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 19.w),
                  Image.asset(
                    "assets/recover_icon.png",
                    width: 26.w,
                    height: 26.h,
                    fit: BoxFit.cover,
                  ),
                  SizedBox(width: 28.w),
                  Text(
                    tr('post_management.restore_deleted', context: context),
                    style: TextStyle(
                      color: const Color(0xFFF8F8F8),
                      fontSize: 17.sp,
                      fontFamily: 'Pretendard Variable',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
