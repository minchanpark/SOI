import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart';

/// 프로필 이미지 선택 페이지
class SelectProfileImagePage extends StatefulWidget {
  final ValueChanged<String?>? onImageSelected; // 이미지 경로 콜백 추가
  final PageController? pageController;
  final VoidCallback? onSkip;

  const SelectProfileImagePage({
    super.key,
    this.onImageSelected,
    required this.pageController,
    this.onSkip,
  });

  @override
  State<SelectProfileImagePage> createState() => _SelectProfileImagePageState();
}

class _SelectProfileImagePageState extends State<SelectProfileImagePage> {
  String? _profileImagePath; // 로컬 파일 경로 저장
  final ImagePicker _imagePicker = ImagePicker();
  bool _isSelecting = false; // 이미지 선택 중 상태

  /// 갤러리에서 이미지 선택
  Future<void> _selectImageFromGallery() async {
    if (_isSelecting) return;

    setState(() {
      _isSelecting = true;
    });

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // 적당한 품질로 설정
        maxWidth: 800, // 최대 너비 제한
        maxHeight: 800, // 최대 높이 제한
      );

      if (pickedFile != null && mounted) {
        setState(() {
          _profileImagePath = pickedFile.path;
        });

        // 부모 컴포넌트에 선택된 이미지 경로 전달
        widget.onImageSelected?.call(pickedFile.path);

        debugPrint('프로필 이미지 선택됨: ${pickedFile.path}');
      }
    } catch (e) {
      debugPrint('이미지 선택 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('register.profile_image_error', context: context)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSelecting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // 이미지 파일 경로 정리
    _profileImagePath = null;

    // 진행 중인 이미지 선택 작업이 있으면 상태 초기화
    _isSelecting = false;

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 60.h,
          left: 20.w,
          child: IconButton(
            onPressed: () {
              widget.pageController?.previousPage(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
        ),

        Align(
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                tr('register.profile_image_title', context: context),
                style: TextStyle(
                  color: const Color(0xFFF8F8F8),
                  fontSize: 18,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 24.h),
              // 프로필 이미지 선택 UI
              Stack(
                children: [
                  GestureDetector(
                    onTap: _selectImageFromGallery,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFD9D9D9),
                      ),
                      child: ClipOval(
                        child: _profileImagePath != null
                            ? Image.file(
                                File(_profileImagePath!),
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 96,
                                    height: 96,
                                    color: const Color(0xFFD9D9D9),
                                    child: Icon(
                                      Icons.person,
                                      size: 48.sp,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              )
                            : Container(
                                width: 96,
                                height: 96,
                                color: const Color(0xFFD9D9D9),
                                child: Icon(
                                  Icons.person,
                                  size: 48.sp,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                  // 편집 아이콘
                  Positioned(
                    right: 0.w,
                    bottom: 4.h,
                    child: GestureDetector(
                      onTap: _selectImageFromGallery,
                      child: Container(
                        padding: EdgeInsets.all(4.w),

                        child: Image.asset(
                          'assets/pencil.png',
                          width: 18,
                          height: 18,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  // 선택 중일 때 로딩 표시
                  if (_isSelecting)
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.0,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
