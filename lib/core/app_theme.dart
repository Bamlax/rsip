import 'package:flutter/material.dart';

class AppTheme {
  // 基础蓝白色调
  static const Color bgCanvas = Color(0xFFF3F7FA); // 冰蓝浅灰底色
  static const Color surfaceWhite = Color(0xFFFFFFFF); // 纯白卡片底
  static const Color borderLight = Color(0xFFE1EBF2); // 极淡蓝灰边框

  // 品牌蓝色梯阶
  static const Color primaryBlue = Color(0xFF1E88E5); // 经典海蓝
  static const Color skyBlue = Color(0xFF4FC3F7); // 天空青蓝
  static const Color deepNavy = Color(0xFF1A2B49); // 沉稳蓝黑文字
  static const Color subtleFill = Color(0xFFE8F3FC); // 浅水蓝填充块

  // 状态机色标 (浅色系调谐)
  static const Color stateActive = Color(0xFF0288D1); // 活跃：明蓝
  static const Color stateFrozen = Color(0xFF90CAF9); // 水密冻结：冰霜蓝
  static const Color stateInHand = Color(0xFF90A4AE); // 待机手牌：蓝灰
  static const Color stateInternalized = Color(0xFF00897B); // 已内化基石：海碧绿

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgCanvas,
      primaryColor: primaryBlue,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        surface: surfaceWhite,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceWhite,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        iconTheme: IconThemeData(color: deepNavy),
        titleTextStyle: TextStyle(
          color: deepNavy,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderLight, width: 1),
        ),
      ),
    );
  }
}
