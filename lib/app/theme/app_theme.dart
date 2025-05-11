import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    primaryColor: Colors.black54,
    highlightColor: Colors.orange.shade900,
    disabledColor: const Color(0xFF767676),
    colorScheme: ColorScheme.light(
      primary: Colors.black54,
      secondary: Colors.orange.shade100,
    ),
    scaffoldBackgroundColor: const Color(0xFFF2F3F8),
    appBarTheme: const AppBarTheme(
      color: Colors.white,
      titleTextStyle: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Colors.black54),
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(fontSize: 72.0, fontWeight: FontWeight.bold, color: Colors.black54),
      titleLarge: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Colors.black54),
      titleMedium: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Colors.black54),
      titleSmall: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.black54.withValues(alpha: 0.6)),
      bodyLarge: TextStyle(fontSize: 18.0, color: Colors.grey.shade700),
      bodyMedium: TextStyle(fontSize: 16.0, color: Colors.grey.shade700),
      bodySmall: TextStyle(fontSize: 14.0, color: Colors.grey.shade700),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      labelStyle: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Colors.black54),
    ),
    chipTheme: ChipThemeData(
        color: WidgetStateProperty.all(Color(0xFFF2F3F8)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
          side: BorderSide.none, // 테두리 완전 제거
        ),
        side: BorderSide.none
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.orange,
          shadowColor: Colors.black54,
          elevation: 2.0,
          padding: const EdgeInsets.fromLTRB(16, 4.0, 16, 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0), // 둥근 모서리
          ),
          textStyle: const TextStyle(fontSize: 16.0, color: Colors.white),
          minimumSize: const Size(80, 48)),
    ),
    buttonTheme: const ButtonThemeData(
      buttonColor: Colors.orange, // 다크 브라운 버튼 색상
      textTheme: ButtonTextTheme.primary,
    ),
    dialogTheme: DialogTheme(
        backgroundColor: Colors.white, // 대화 상자 배경색
        titleTextStyle: const TextStyle(
          fontSize: 20.0,
          fontWeight: FontWeight.bold,
          color: Colors.black54, // 다크 브라운 텍스트 색상
        ),
        contentTextStyle: const TextStyle(
          fontSize: 18.0,
          color: Colors.black54, // 다크 브라운 본문 텍스트 색상
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0), // 둥근 모서리
        ),
        insetPadding: const EdgeInsets.all(8.0)),
    dividerTheme: DividerThemeData(
      color: Colors.grey[400], // Divider 색상
      thickness: 1, // Divider 두께
      indent: 0, // 시작 여백
      endIndent: 0, // 끝 여백
    ),
    toggleButtonsTheme: ToggleButtonsThemeData(
      fillColor: Colors.orange, // Background color when selected
      selectedColor: Colors.white, // Text color when selected
      borderColor: Colors.grey[400], // Border color
      selectedBorderColor: Colors.grey[400], // Border color when selected
      borderRadius: BorderRadius.circular(8.0), // Rounded corners
      borderWidth: 1.0, // Border width
      color: Colors.black, // Text color when not selected
      disabledColor: Colors.grey, // Text color when disabled
      constraints: const BoxConstraints(
        minHeight: 40.0,
        minWidth: 50.0,
      ),
    ),
    tabBarTheme: TabBarTheme(
      labelColor: Colors.black54, // 선택된 탭의 텍스트 색상
      dividerColor: Colors.grey[400],
      unselectedLabelColor: Color(0xFF767676), // 선택되지 않은 탭의 텍스트 색상
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(
          color: Colors.black54, // 밑줄 색상
          width: 4.0, // 밑줄 두께
        ),
        insets: EdgeInsets.symmetric(horizontal: 8.0), // 밑줄의 가로 여백 조정
      ),
      labelStyle: TextStyle(
        fontSize: 18.0,
        fontWeight: FontWeight.bold,
      ), // 선택된 탭의 텍스트 스타일
      unselectedLabelStyle: TextStyle(
        fontSize: 16.0,
      ), // 선택되지 않은 탭의 텍스트 스타일
    ),
  );

  static ThemeData darkTheme = ThemeData(
    primaryColor: Colors.white,
    highlightColor: const Color(0xFFBEBEBE),
    disabledColor: const Color(0xFF404040),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF767676), // 주요 색상
      secondary: Color(0xFFBB86FC), // 보조 강조 색상
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      color: Color(0xFF121212),
      titleTextStyle: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Colors.white),
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(fontSize: 72.0, fontWeight: FontWeight.bold, color: Colors.white),
      titleLarge: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Colors.white),
      titleMedium: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Colors.white),
      titleSmall: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.6)),
      bodyLarge: TextStyle(fontSize: 18.0, color: Colors.white),
      bodyMedium: TextStyle(fontSize: 16.0, color: Colors.white),
      bodySmall: TextStyle(fontSize: 14.0, color: Colors.white),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      labelStyle: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: const Color(0xFF121212),
          shadowColor: Colors.black,
          elevation: 2.0,
          padding: const EdgeInsets.fromLTRB(16, 4.0, 16, 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          textStyle: const TextStyle(fontSize: 16.0, color: Colors.white),
          minimumSize: const Size(80, 48)),
    ),
    buttonTheme: const ButtonThemeData(
      buttonColor: Color(0xFF121212), // 버튼 색상
      textTheme: ButtonTextTheme.primary,
    ),
    dialogTheme: DialogTheme(
        backgroundColor: Color(0xFF222222),
        titleTextStyle: const TextStyle(
          fontSize: 20.0,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 18.0,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        insetPadding: const EdgeInsets.all(8.0)),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF3C2F2F), // Divider 색상
      thickness: 1,
      indent: 0,
      endIndent: 0,
    ),
    toggleButtonsTheme: ToggleButtonsThemeData(
      fillColor: Color(0xFF121212),
      selectedColor: Colors.white,
      borderColor: Colors.grey[800],
      selectedBorderColor: Colors.white,
      borderRadius: BorderRadius.circular(8.0),
      borderWidth: 1.0,
      color: Colors.white.withValues(alpha: 0.7),
      disabledColor: Colors.grey,
      constraints: const BoxConstraints(
        minHeight: 40.0,
        minWidth: 50.0,
      ),
    ),
    tabBarTheme: const TabBarTheme(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.grey,
      indicator: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: Colors.white,
            width: 4.0,
          ),
        ),
      ),
      labelStyle: TextStyle(
        fontSize: 18.0,
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelStyle: TextStyle(
        fontSize: 16.0,
      ),
    ),
  );
}
