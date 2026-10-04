import 'package:flutter/material.dart';
import 'app_theme.dart';

class ProgressColorHelper {
  /// 主题主色（边框与文字）
  static Color getColor(int progress) {
    if (progress > 0) {
      if (progress >= 7) return const Color(0xFF1B5E20); // 深浓绿
      if (progress >= 4) return const Color(0xFF2E7D32); // 森林绿
      if (progress >= 2) return const Color(0xFF388E3C); // 翠绿
      return const Color(0xFF4CAF50);                     // 青绿
    } else if (progress < 0) {
      final abs = progress.abs();
      if (abs >= 7) return const Color(0xFFB71C1C);     // 深浓红
      if (abs >= 4) return const Color(0xFFC62828);     // 猩红
      if (abs >= 2) return const Color(0xFFD32F2F);     // 亮红
      return const Color(0xFFE53935);                     // 桃粉红
    }
    return AppTheme.primaryBlue; // 0 为中性经典蓝
  }

  /// 浅色底衬背景色
  static Color getBgColor(int progress) {
    if (progress > 0) {
      final alpha = (0.05 + (progress * 0.02)).clamp(0.05, 0.22);
      return Colors.green.withValues(alpha: alpha);
    } else if (progress < 0) {
      final alpha = (0.05 + (progress.abs() * 0.02)).clamp(0.05, 0.22);
      return Colors.red.withValues(alpha: alpha);
    }
    return AppTheme.surfaceWhite;
  }
}