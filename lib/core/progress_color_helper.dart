import 'package:flutter/material.dart';

class ProgressColorHelper {
  /// 0 ~ 100 分习惯打分文字与边框色：随分数升高从浅绿平滑渐变至深墨绿
  static Color getScoreColor(double score) {
    if (score <= 0.1) return const Color(0xFF64748B);
    final ratio = (score / 100.0).clamp(0.0, 1.0);
    return Color.lerp(
      const Color(0xFF22C55E), // 浅绿 (起步)
      const Color(0xFF064E3B), // 深墨绿 (巅峰)
      ratio,
    )!;
  }

  /// 0 ~ 100 分习惯打分背景底色：随分数升高从极淡绿过渡至柔和深绿底
  static Color getScoreBgColor(double score) {
    if (score <= 0.1) return const Color(0xFFF1F5F9);
    final ratio = (score / 100.0).clamp(0.0, 1.0);
    return Color.lerp(
      const Color(0xFFF0FDF4), // 极浅绿底
      const Color(0xFFA7F3D0), // 浓郁浅绿底
      ratio,
    )!;
  }

  /// 兼容历史净值颜色
  static Color getColor(int progress) {
    if (progress > 0) {
      final ratio = ((progress - 1) / 14.0).clamp(0.0, 1.0);
      return Color.lerp(
        const Color(0xFF22C55E),
        const Color(0xFF064E3B),
        ratio,
      )!;
    } else if (progress < 0) {
      final ratio = (((-progress) - 1) / 14.0).clamp(0.0, 1.0);
      return Color.lerp(
        const Color(0xFFF87171),
        const Color(0xFF7F1D1D),
        ratio,
      )!;
    }
    return const Color(0xFF64748B);
  }

  static Color getBgColor(int progress) {
    if (progress > 0) {
      final ratio = ((progress - 1) / 14.0).clamp(0.0, 1.0);
      return Color.lerp(
        const Color(0xFFF0FDF4),
        const Color(0xFFBBF7D0),
        ratio,
      )!;
    } else if (progress < 0) {
      final ratio = (((-progress) - 1) / 14.0).clamp(0.0, 1.0);
      return Color.lerp(
        const Color(0xFFFEF2F2),
        const Color(0xFFFECACA),
        ratio,
      )!;
    }
    return Colors.white;
  }

  static Color getIncreaseColor(int count) {
    if (count <= 0) return const Color(0xFF22C55E);
    final ratio = ((count - 1) / 19.0).clamp(0.0, 1.0);
    return Color.lerp(
      const Color(0xFF22C55E),
      const Color(0xFF064E3B),
      ratio,
    )!;
  }

  static Color getIncreaseBgColor(int count) {
    if (count <= 0) return const Color(0xFFF0FDF4);
    final ratio = ((count - 1) / 19.0).clamp(0.0, 1.0);
    return Color.lerp(
      const Color(0xFFF0FDF4),
      const Color(0xFFBBF7D0),
      ratio,
    )!;
  }
}