import 'package:flutter/material.dart';

class AppTheme {
  // 라이트 테마 정의
  static ThemeData lightTheme = ThemeData(
    colorScheme: _colorScheme,
    useMaterial3: true,
  );

  // 다크 테마 정의
  static ThemeData darkTheme = ThemeData(
    colorScheme: _darkColorScheme,
    useMaterial3: true,
  );

  static ThemeData textTheme = ThemeData(
    textTheme: _textTheme,
    useMaterial3: true,
  );

  // Light Mode 색상 정의
  static const ColorScheme _colorScheme = ColorScheme(
    primary: Color(0xff634D45), // 키 컬러
    secondary: Color(0xFFffffff), // 보조 키 컬러
    surface: Color(0xff000000), // 백그라운드 색상
    error: Color(0xFFB00020), // 에러 색상
    onPrimary: Color(0xFFd9d9d9), // 키 컬러 위 텍스트 색상
    onSecondary: Color(0xFFcfcfcf), // 배경 위 텍스트 색상
    onSurface: Color(0xFF000000), // 표면 위 텍스트 색상
    onError: Color(0xFFFFFFFF), // 에러 위 텍스트 색상
    brightness: Brightness.light, // 밝기 설정 (라이트 모드)
  );

  // Dark Mode 색상 정의
  static const ColorScheme _darkColorScheme = ColorScheme(
    primary: Color(0xff622223), // 키 컬러
    secondary: Color(0xFFEAD8CA), // 보조 키 컬러
    surface: Color(0xFF232121), // 다크 모드 표면 색상
    error: Color(0xFFCF6679), // 다크 모드 에러 색상
    onPrimary: Color(0xFFEAD8CA), // 키 컬러 위 텍스트 색상 (다크 모드)
    onSecondary: Color(0xFF000000), // 보조 컬러 위 텍스트 색상 (다크 모드)
    onSurface: Color(0xFFFFFFFF), // 표면 위 텍스트 색상 (다크 모드)
    onError: Color(0xFF000000), // 에러 위 텍스트 색상 (다크 모드)
    brightness: Brightness.dark, // 밝기 설정 (다크 모드)
  );

  // TextTheme 정의
  static const TextTheme _textTheme = TextTheme(
    displayMedium: TextStyle(
      fontSize: 20,
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w600,
      color: Color(0xff232121), // 기본 색상
    ),
    displayLarge: TextStyle(
      fontSize: 20,
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w700,
      color: Color(0xff232121), // 기본 색상
    ),
    labelMedium: TextStyle(
      fontSize: 16,
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w500,
      color: Color(0xff535252), // 기본 색상
    ),
    labelSmall: TextStyle(
      fontSize: 12,
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w700,
      color: Color(0xff232121), // 기본 색상
    ),
  );
}
