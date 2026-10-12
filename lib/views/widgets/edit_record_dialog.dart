import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../engine/rsip_engine.dart';
import '../../models/focus_node_model.dart';

class EditRecordDialog extends StatefulWidget {
  final ProgressRecord record;
  final RsipEngine engine;

  const EditRecordDialog({
    super.key,
    required this.record,
    required this.engine,
  });

  @override
  State<EditRecordDialog> createState() => _EditRecordDialogState();
}

class _EditRecordDialogState extends State<EditRecordDialog> {
  late final TextEditingController _noteController;
  final _tagInputController = TextEditingController();
  final Map<String, TextEditingController> _attrControllers = {};
  late DateTime _selectedDate;

  final Set<String> _selectedTags = {};
  late List<String> _historicalTags;

  String _formatNum(double val) {
    return val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1);
  }

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.record.note ?? '');
    _selectedDate = widget.record.time;

    final isIncrease = widget.record.delta > 0;
    _historicalTags = widget.engine.getHistoricalTags(isIncrease: isIncrease);
    if (widget.record.tags != null) {
      _selectedTags.addAll(widget.record.tags!);
      for (final t in widget.record.tags!) {
        if (!_historicalTags.contains(t)) {
          _historicalTags.add(t);
        }
      }
    }

    final node = widget.engine.nodes.where((n) => n.id == widget.record.nodeId).firstOrNull;
    if (node != null) {
      for (final attr in node.numericAttributes) {
        final currentVal = widget.record.attributeDeltas?[attr.name];
        _attrControllers[attr.name] = TextEditingController(
          text: currentVal != null ? _formatNum(currentVal) : '',
        );
      }
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
    final node = widget.engine.nodes.where((n) => n.id == widget.record.nodeId).firstOrNull;
    final isIncrease = widget.record.delta > 0;
    final themeColor = isIncrease ? Colors.green.shade700 : Colors.red.shade700;
    final activeTagBg = isIncrease ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);

    return AlertDialog(
      backgroundColor: AppTheme.surfaceWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        '编辑记录 - ${widget.record.nodeTitle}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.deepNavy),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    const Text('归属日期：', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    Text(
                      _formatDate(_selectedDate),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.deepNavy),
                    ),
                    const Spacer(),
                    const Icon(Icons.edit_calendar_rounded, size: 16, color: Colors.black38),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('心得与反思：', style: TextStyle(fontSize: 12, color: Colors.black45)),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: '修改打卡心得或备注...',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.black38),
                filled: true,
                fillColor: AppTheme.bgCanvas,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),

            // 标签编辑
            Text(isIncrease ? '增加标签：' : '减少标签：', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.deepNavy)),
            const SizedBox(height: 6),
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

            if (node != null && node.numericAttributes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('数值属性：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.deepNavy)),
              const SizedBox(height: 6),
              ...node.numericAttributes.map((attr) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(attr.name, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _attrControllers[attr.name],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            isDense: true,
                            suffixText: attr.unit,
                            filled: true,
                            fillColor: AppTheme.bgCanvas,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
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
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('保存修改'),
          onPressed: () {
            final Map<String, double> deltas = {};
            for (final entry in _attrControllers.entries) {
              final val = double.tryParse(entry.value.text.trim());
              if (val != null) {
                deltas[entry.key] = val;
              }
            }

            widget.engine.updateRecord(
              recordId: widget.record.id,
              newDate: _selectedDate,
              newNote: _noteController.text,
              newTags: _selectedTags.toList(),
              newAttributeDeltas: deltas.isNotEmpty ? deltas : null,
            );
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}