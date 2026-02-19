import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 카메라 줌 컨트롤 위젯
/// 카메라 줌 레벨을 선택하고 줌 관련한 UI를 담은 위젯입니다.
class CameraZoomControls extends StatelessWidget {
  const CameraZoomControls({
    required this.zoomLevels,
    required this.currentZoomValue,
    required this.onZoomSelected,
    super.key,
  });

  final List<Map<String, dynamic>> zoomLevels;
  final double currentZoomValue;
  final void Function(double value, String label) onZoomSelected;

  @override
  Widget build(BuildContext context) {
    if (zoomLevels.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 147.w,
      height: 50.h,
      decoration: BoxDecoration(
        color: const Color(0xff000000).withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < zoomLevels.length; i++) ...[
            SizedBox(
              width: 45.w,
              height: 45.h,
              child: GestureDetector(
                onTap: () => onZoomSelected(
                  zoomLevels[i]['value'] as double,
                  zoomLevels[i]['label'] as String,
                ),
                child: Center(
                  child: Container(
                    width: _isCurrent(i) ? 45.w : 29.w,
                    height: _isCurrent(i) ? 45.h : 29.h,
                    decoration: const BoxDecoration(
                      color: Color(0xff2c2c2c),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        zoomLevels[i]['label'] as String,
                        style: TextStyle(
                          color: _isCurrent(i)
                              ? Colors.yellow
                              : const Color(0xffffffff),
                          fontSize: _isCurrent(i) ? 14.36.sp : 12.36.sp,
                          fontWeight: _isCurrent(i)
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontFamily: 'Pretendard Variable',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isCurrent(int index) {
    return (zoomLevels[index]['value'] as double) == currentZoomValue;
  }
}
