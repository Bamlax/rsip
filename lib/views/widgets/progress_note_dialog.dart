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
  final bool isSkip;
  final List<NumericAttribute> attributes;
  final RsipEngine engine;

  const ProgressNoteDialog({
    super.key,
    required this.nodeTitle,
    required this.delta,
    this.isSkip = false,
    required this.attributes,
    required this.engine,
  });

  @override
  State<ProgressNoteDialog> createState() => _ProgressNoteDialogState();
}

class _ProgressNoteDialogState extends State<ProgressNoteDialog> {
  final _noteController = TextEditingController();
  final _tagController = TextEditingController();
  final Map<String, TextEditingController> _attrControllers = {};
  final Set<String> _selectedTags = {};
  late DateTime _selectedDate;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.engine.getEffectiveDate(DateTime.now());
    if (!widget.isSkip) {
      for (final attr in widget.attributes) {
        _attrControllers[attr.name] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _tagController.dispose();
    for (final c in _attrControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _addCustomTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty) {
      setState(() {
        _selectedTags.add(tag);
        _tagController.clear();
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _submit() {
    final noteText = _noteController.text.trim();
    if (widget.isSkip && noteText.isEmpty) {
      setState(() => _errorText = '请填写跳过原因');
      return;
    }

    final Map<String, double> attrDeltas = {};
    if (!widget.isSkip) {
      for (final entry in _attrControllers.entries) {
        final val = double.tryParse(entry.value.text.trim());
        if (val != null && val != 0) {
          attrDeltas[entry.key] = val;
        }
      }
    }

    // 若用户选择了今天，保留当前精确时间戳以适配跨天延后逻辑；若补签往日，使用选中日期
    final nowEffective = widget.engine.getEffectiveDate(DateTime.now());
    final isToday = _selectedDate.year == nowEffective.year &&
        _selectedDate.month == nowEffective.month &&
        _selectedDate.day == nowEffective.day;
    final finalTime = isToday ? DateTime.now() : _selectedDate;

    Navigator.pop(
      context,
      ProgressSubmitData(
        note: noteText.isEmpty ? null : noteText,
        tags: _selectedTags.toList(),
        attributeDeltas: attrDeltas,
        date: finalTime,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGain = widget.delta > 0;
    final Color themeColor = widget.isSkip
        ? Colors.blueGrey.shade700
        : (isGain ? Colors.green.shade700 : Colors.red.shade700);

    final String dialogTitle = widget.isSkip
        ? '跳过 · ${widget.nodeTitle}'
        : (isGain ? '完成打卡 · ${widget.nodeTitle}' : '断签反思 · ${widget.nodeTitle}');

    final historicalTags = widget.engine.getHistoricalTags(
      isIncrease: isGain,
      isSkip: widget.isSkip,
    );
    final allDisplayTags = {...historicalTags, ..._selectedTags}.toList();

    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    return AlertDialog(
      backgroundColor: AppTheme.surfaceWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        dialogTitle,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: themeColor,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 日期选择条
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCanvas,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '归属日期',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      Row(
                        children: [
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.deepNavy,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.calendar_today_rounded, size: 13, color: AppTheme.primaryBlue),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 备注 / 跳过原因输入框
              TextField(
                controller: _noteController,
                autofocus: widget.isSkip,
                maxLines: 3,
                onChanged: (_) {
                  if (_errorText != null) {
                    setState(() => _errorText = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: widget.isSkip ? '跳过原因（必填）' : '心得备注（选填）',
                  hintText: widget.isSkip
                      ? '请填写跳过本次任务的具体原因（如：身体不适、出差休整...）'
                      : '记录本次执行感受或反思...',
                  errorText: _errorText,
                  labelStyle: const TextStyle(fontSize: 13),
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: AppTheme.bgCanvas,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              // 数字属性录入（跳过时不展示）
              if (!widget.isSkip && widget.attributes.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  '数值属性录入',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.deepNavy),
                ),
                const SizedBox(height: 6),
                ...widget.attributes.map((attr) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: _attrControllers[attr.name],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: '${attr.name} (${attr.unit})',
                        isDense: true,
                        labelStyle: const TextStyle(fontSize: 12),
                        filled: true,
                        fillColor: AppTheme.bgCanvas,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  );
                }),
              ],

              const SizedBox(height: 12),
              const Text(
                '标签归因',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.deepNavy),
              ),
              const SizedBox(height: 6),
              if (allDisplayTags.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: allDisplayTags.map((tag) {
                    final selected = _selectedTags.contains(tag);
                    return FilterChip(
                      label: Text('#$tag', style: const TextStyle(fontSize: 11)),
                      selected: selected,
                      selectedColor: themeColor.withValues(alpha: 0.15),
                      checkmarkColor: themeColor,
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
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagController,
                      onSubmitted: (_) => _addCustomTag(),
                      decoration: InputDecoration(
                        hintText: '输入新标签...',
                        isDense: true,
                        hintStyle: const TextStyle(fontSize: 11),
                        filled: true,
                        fillColor: AppTheme.bgCanvas,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: _addCustomTag,
                    child: const Text('添加', style: TextStyle(fontSize: 12, color: AppTheme.primaryBlue)),
                  ),
                ],
              ),
            ],
          ),
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
          onPressed: _submit,
          child: Text(widget.isSkip ? '确认跳过' : '确认记录'),
        ),
      ],
    );
  }
}