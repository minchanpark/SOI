import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ReportResult {
  final String reason;
  final String? detail;

  const ReportResult({required this.reason, this.detail});
}

class ReportBottomSheet {
  static Future<ReportResult?> show(BuildContext context) async {
    final reasons = <String>[
      '스팸',
      '괴롭힘/혐오',
      '부적절한 콘텐츠',
      '기타',
    ];
    String? selectedReason;
    final detailController = TextEditingController();

    return showModalBottomSheet<ReportResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF323232),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
            ),
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            child: StatefulBuilder(
              builder: (context, setState) {
                final canSubmit = selectedReason != null;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5A5A5A),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      '신고',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                    SizedBox(height: 12.h),
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      dropdownColor: const Color(0xFF323232),
                      iconEnabledColor: Colors.white,
                      items: reasons
                          .map(
                            (reason) => DropdownMenuItem(
                              value: reason,
                              child: Text(
                                reason,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.sp,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => selectedReason = value);
                      },
                      decoration: InputDecoration(
                        labelText: '사유 선택',
                        labelStyle: TextStyle(
                          color: const Color(0xFFB0B0B0),
                          fontSize: 13.sp,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color(0xFF5A5A5A),
                          ),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Colors.white,
                          ),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    TextField(
                      controller: detailController,
                      maxLines: 3,
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
                      decoration: InputDecoration(
                        hintText: '추가 설명 (선택)',
                        hintStyle: TextStyle(
                          color: const Color(0xFFB0B0B0),
                          fontSize: 13.sp,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color(0xFF5A5A5A),
                          ),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Colors.white,
                          ),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    SizedBox(
                      width: double.infinity,
                      height: 40.h,
                      child: ElevatedButton(
                        onPressed: canSubmit
                            ? () {
                                final detail = detailController.text.trim();
                                Navigator.of(sheetContext).pop(
                                  ReportResult(
                                    reason: selectedReason!,
                                    detail: detail.isEmpty ? null : detail,
                                  ),
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: const Color(0xFF5A5A5A),
                          disabledForegroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          '신고하기',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Pretendard',
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
