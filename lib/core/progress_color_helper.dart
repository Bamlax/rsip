import 'package:flutter/material.dart';

class ProgressColorHelper {
  /// 进度主色调：从清透明快的浅绿 (#22C55E / #16A34A) 平滑过渡至沉稳墨绿 (#064E3B)
  static Color getColor(int progress) {
    if (progress > 0) {
      final ratio = ((progress - 1) / 14.0).clamp(0.0, 1.0);
      return Color.lerp(
        const Color(0xFF22C55E), // 浅绿
        const Color(0xFF064E3B), // 深绿
        ratio,
      )!;
    } else if (progress < 0) {
      final ratio = (((-progress) - 1) / 14.0).clamp(0.0, 1.0);
      return Color.lerp(
        const Color(0xFFF87171), // 浅红
        const Color(0xFF7F1D1D), // 深红
        ratio,
      )!;
    }
    return const Color(0xFF64748B);
  }

  /// 进度背景底色：从淡透浅绿 (#F0FDF4) 随进度加深过渡至浅嫩草绿 (#BBF7D0)
  static Color getBgColor(int progress) {
    if (progress > 0) {
      final ratio = ((progress - 1) / 14.0).clamp(0.0, 1.0);
      return Color.lerp(
        const Color(0xFFF0FDF4), // 极淡浅绿
        const Color(0xFFBBF7D0), // 稍深浅绿底色
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

  /// 增加次数徽章文字色：从鲜明浅绿过渡到深邃墨绿
  static Color getIncreaseColor(int count) {
    if (count <= 0) return const Color(0xFF22C55E);
    final ratio = ((count - 1) / 19.0).clamp(0.0, 1.0);
    return Color.lerp(
      const Color(0xFF22C55E), // 浅绿
      const Color(0xFF064E3B), // 深绿
      ratio,
    )!;
  }

  /// 增加次数徽章背景色：从极浅绿到淡绿底
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