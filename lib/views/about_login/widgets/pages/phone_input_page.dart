import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../common/page_title.dart';
import '../common/custom_text_field.dart';

/// 전화번호 입력 페이지 위젯
class PhoneInputPage extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final String selectedCountryCode;
  final ValueChanged<String> onCountryChanged;
  final PageController? pageController;

  const PhoneInputPage({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.selectedCountryCode,
    required this.onCountryChanged,
    required this.pageController,
  });

  @override
  Widget build(BuildContext context) {
    // 키보드 높이 계산
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final verticalOffset = keyboardHeight > 0 ? -30.0 : 0.0; // 키보드가 올라올 때 위로 이동

    return Stack(
      children: [
        Positioned(
          top: 60.h,
          left: 20.w,
          child: IconButton(
            onPressed: () {
              pageController?.previousPage(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
        ),

        // 전화번호 입력 UI 임시 숨김
        Align(
          alignment: Alignment.center,
          child: Transform.translate(
            offset: Offset(0, verticalOffset),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const PageTitle(title: 'SOI 접속을 위해 전화번호를 입력해주세요.'),
                SizedBox(height: 16.h),
                _CountrySelector(
                  selectedCountryCode: selectedCountryCode,
                  onChanged: onCountryChanged,
                ),
                SizedBox(height: 16.h),
                CustomTextField(
                  controller: controller,
                  hintText: '전화번호',
                  keyboardType: TextInputType.phone,
                  textAlign: TextAlign.start,
                  prefixIcon: Icon(
                    SolarIconsOutline.phone,
                    color: const Color(0xffC0C0C0),
                    size: 24.sp,
                  ),
                  onChanged: onChanged,
                ),
                SizedBox(height: 24.h),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CountryOption {
  final String code;
  final String label;
  final String dialCode;

  const _CountryOption({
    required this.code,
    required this.label,
    required this.dialCode,
  });
}

class _CountrySelector extends StatelessWidget {
  final String selectedCountryCode;
  final ValueChanged<String> onChanged;

  const _CountrySelector({
    required this.selectedCountryCode,
    required this.onChanged,
  });

  static const _options = [
    _CountryOption(code: 'KR', label: 'South Korea', dialCode: '+82'),
    _CountryOption(code: 'US', label: 'United States', dialCode: '+1'),
    _CountryOption(code: 'MX', label: 'Mexico', dialCode: '+52'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 239.w,
      height: 44,
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: const Color(0xff323232),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.centerLeft,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCountryCode,
          dropdownColor: const Color(0xff323232),
          iconEnabledColor: const Color(0xFFF8F8F8),
          style: TextStyle(
            color: const Color(0xFFF8F8F8),
            fontSize: 14.sp,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w500,
          ),
          items: _options.map((option) {
            return DropdownMenuItem<String>(
              value: option.code,
              child: Text('${option.label} (${option.dialCode})'),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }
}
