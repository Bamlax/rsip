import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../engine/rsip_engine.dart';
import '../../models/focus_node_model.dart';

class ProgressSubmitData {
  final String? note;
  final List<String> tags;
  final Map<String, double> attributeDeltas;
  final DateTime date;

  ProgressSubmitData({
    this.note,
    required this.tags,
    required this.attributeDeltas,
    required this.date,
  });
}

class ProgressNoteDialog extends StatefulWidget {
  final String nodeTitle;
  final int delta;
  final List<NumericAttribute> attributes;
  final RsipEngine engine;

  const ProgressNoteDialog({
    super.key,
    required this.nodeTitle,
    required this.delta,
    required this.attributes,
    required this.engine,
  });

  @override
  State<ProgressNoteDialog> createState() => _ProgressNoteDialogState();
}

class _ProgressNoteDialogState extends State<ProgressNoteDialog> {
  final _noteController = TextEditingController();
  final _tagInputController = TextEditingController();
  final Map<String, TextEditingController> _attrControllers = {};
  DateTime _selectedDate = DateTime.now();

  final Set<String> _selectedTags = {};
  late List<String> _historicalTags;

  @override
  void initState() {
    super.initState();
    // 增加和减少的标签完全分开读取
    final isIncrease = widget.delta > 0;
    _historicalTags = widget.engine.getHistoricalTags(isIncrease: isIncrease);

    for (final attr in widget.attributes) {
      _attrControllers[attr.name] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _tagInputController.dispose();
    for (final c in _attrControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  void _addNewTag() {
    final text = _tagInputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _selectedTags.add(text);
      if (!_historicalTags.contains(text)) {
        _historicalTags.add(text);
      }
      _tagInputController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isIncrease = widget.delta > 0;
    final themeColor = isIncrease ? Colors.green.shade700 : Colors.red.shade700;
    final activeTagBg = isIncrease ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);

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
            // 1. 日期选择
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.bgCanvas,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.primaryBlue),
                    const SizedBox(width: 8),
                    const Text('记录日期：', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    Text(
                      _formatDate(_selectedDate),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.deepNavy,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.edit_calendar_rounded, size: 16, color: Colors.black38),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 2. 心得反思输入框
            const Text('写下心得或反思（可选）：', style: TextStyle(fontSize: 12, color: Colors.black45)),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: isIncrease ? '例如：按时完成，状态良好...' : '例如：受到干扰导致中断...',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.black38),
                filled: true,
                fillColor: AppTheme.bgCanvas,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),

            // 3. 【新增：标签功能（位于心得反思下方）】
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isIncrease ? '增加标签：' : '减少标签：',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.deepNavy),
                ),
                if (_historicalTags.isNotEmpty)
                  Text(
                    '可点击下方历史标签快速勾选',
                    style: TextStyle(fontSize: 10, color: Colors.black38),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // 历史标签列表（点击选择/取消）
            if (_historicalTags.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _historicalTags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text('#$tag'),
                    selected: isSelected,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? themeColor : Colors.black87,
                    ),
                    backgroundColor: AppTheme.bgCanvas,
                    selectedColor: activeTagBg,
                    side: BorderSide(
                      color: isSelected ? themeColor.withValues(alpha: 0.4) : AppTheme.borderLight,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    visualDensity: VisualDensity.compact,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),

            const SizedBox(height: 6),
            // 添加新标签输入框
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagInputController,
                    decoration: InputDecoration(
                      hintText: '输入新标签...',
                      isDense: true,
                      hintStyle: const TextStyle(fontSize: 11),
                      filled: true,
                      fillColor: AppTheme.bgCanvas,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _addNewTag(),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppTheme.primaryBlue, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: '添加标签',
                  onPressed: _addNewTag,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 4. 数字属性数值录入
            if (widget.attributes.isNotEmpty) ...[
              const Text('本次记录属性数值：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.deepNavy)),
              const SizedBox(height: 8),
              ...widget.attributes.map((attr) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(attr.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
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
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
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
                tags: _selectedTags.toList(),
                attributeDeltas: deltas,
                date: _selectedDate,
              ),
            );
          },
        ),
      ],
    );
  }
}