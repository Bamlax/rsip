import 'package:flutter/material.dart';

class DiffHelper {
  /// 生成差异文本 Span：删除的内容用红删除线划掉，新增的内容加粗高亮
  static List<TextSpan> buildDiffSpans(String oldText, String newText) {
    if (oldText == newText) {
      return [TextSpan(text: newText, style: const TextStyle(color: Colors.black87))];
    }
    if (oldText.isEmpty) {
      return [
        TextSpan(
          text: newText,
          style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
        ),
      ];
    }
    if (newText.isEmpty) {
      return [
        TextSpan(
          text: oldText,
          style: TextStyle(
            decoration: TextDecoration.lineThrough,
            decorationColor: Colors.red.shade400,
            decorationThickness: 2.0,
            color: Colors.red.shade400,
          ),
        ),
      ];
    }

    final a = oldText.characters.toList();
    final b = newText.characters.toList();
    final m = a.length;
    final n = b.length;

    // 针对极长文本的平稳保底降级
    if (m * n > 160000) {
      return [
        TextSpan(
          text: oldText,
          style: TextStyle(
            decoration: TextDecoration.lineThrough,
            decorationColor: Colors.red.shade400,
            decorationThickness: 2.0,
            color: Colors.red.shade400,
          ),
        ),
        const TextSpan(text: '  ➔  ', style: TextStyle(color: Colors.black38)),
        TextSpan(
          text: newText,
          style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
        ),
      ];
    }

    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        if (a[i] == b[j]) {
          dp[i + 1][j + 1] = dp[i][j] + 1;
        } else {
          dp[i + 1][j + 1] = dp[i + 1][j] > dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1];
        }
      }
    }

    int i = m;
    int j = n;
    final List<({int type, String text})> rawOps = [];

    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && a[i - 1] == b[j - 1]) {
        rawOps.add((type: 0, text: a[i - 1]));
        i--;
        j--;
      } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
        rawOps.add((type: 1, text: b[j - 1]));
        j--;
      } else if (i > 0 && (j == 0 || dp[i][j - 1] < dp[i - 1][j])) {
        rawOps.add((type: -1, text: a[i - 1]));
        i--;
      }
    }

    final ops = rawOps.reversed.toList();
    final List<TextSpan> spans = [];
    int? currentType;
    final buffer = StringBuffer();

    void flush() {
      if (buffer.isEmpty || currentType == null) return;
      final str = buffer.toString();
      if (currentType == -1) {
        // 删除的内容：划删除线
        spans.add(
          TextSpan(
            text: str,
            style: TextStyle(
              decoration: TextDecoration.lineThrough,
              decorationColor: Colors.red.shade400,
              decorationThickness: 2.0,
              color: Colors.red.shade400,
            ),
          ),
        );
      } else if (currentType == 1) {
        // 新增/修改的内容：加粗深色
        spans.add(
          TextSpan(
            text: str,
            style: TextStyle(
              color: Colors.green.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: str,
            style: const TextStyle(color: Colors.black87),
          ),
        );
      }
      buffer.clear();
    }

    for (final op in ops) {
      if (op.type != currentType) {
        flush();
        currentType = op.type;
      }
      buffer.write(op.text);
    }
    flush();

    return spans;
  }
}