import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/focus_node_model.dart';

class ProgressSubmitData {
  final String? note;
  final Map<String, double> attributeDeltas;

  ProgressSubmitData({this.note, required this.attributeDeltas});
}

class ProgressNoteDialog extends StatefulWidget {
  final String nodeTitle;
  final int delta;
  final List<NumericAttribute> attributes;

  const ProgressNoteDialog({
    super.key,
    required this.nodeTitle,
    required this.delta,
    required this.attributes,
  });

  @override
  State<ProgressNoteDialog> createState() => _ProgressNoteDialogState();
}

class _ProgressNoteDialogState extends State<ProgressNoteDialog> {
  final _noteController = TextEditingController();
  final Map<String, TextEditingController> _attrControllers = {};

  @override
  void initState() {
    super.initState();
    for (final attr in widget.attributes) {
      _attrControllers[attr.name] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    for (final c in _attrControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIncrease = widget.delta > 0;
    final themeColor = isIncrease ? Colors.green.shade700 : Colors.red.shade700;

    return AlertDialog(
      backgroundColor: AppTheme.surfaceWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isIncrease
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isIncrease ? '进度 +1' : '进度 -1',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: themeColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.nodeTitle,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.deepNavy,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 【内容/心得在数值上方】
            const Text(
              '写下心得或反思（可选）：',
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              autofocus: true,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: isIncrease ? '例如：按时完成，状态良好...' : '例如：受到干扰导致中断...',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.black38),
                filled: true,
                fillColor: AppTheme.bgCanvas,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 2. 【数值录入在下方】
            if (widget.attributes.isNotEmpty) ...[
              const Text(
                '本次记录属性数值：',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.deepNavy),
              ),
              const SizedBox(height: 8),
              ...widget.attributes.map((attr) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          attr.name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _attrControllers[attr.name],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: '本次数值',
                            suffixText: attr.unit,
                            isDense: true,
                            hintStyle: const TextStyle(fontSize: 12),
                            filled: true,
                            fillColor: AppTheme.bgCanvas,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('取消', style: TextStyle(color: Colors.black45)),
          onPressed: () => Navigator.pop(context, null),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: themeColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('确认记录'),
          onPressed: () {
            final Map<String, double> deltas = {};
            for (final entry in _attrControllers.entries) {
              final val = double.tryParse(entry.value.text.trim());
              if (val != null) {
                deltas[entry.key] = val;
              }
            }

            Navigator.pop(
              context,
              ProgressSubmitData(
                note: _noteController.text.trim(),
                attributeDeltas: deltas,
              ),
            );
          },
        ),
      ],
    );
  }
}