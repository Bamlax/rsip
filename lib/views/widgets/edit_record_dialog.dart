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
  final _tagController = TextEditingController();
  final Map<String, TextEditingController> _attrControllers = {};
  late final Set<String> _selectedTags;
  late DateTime _selectedDate;

  // 0: 增加 (+1), 1: 减少 (-1), 2: 跳过
  late int _polarityType;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.record.note ?? '');
    _selectedTags = Set<String>.from(widget.record.tags ?? []);
    _selectedDate = widget.engine.getEffectiveDate(widget.record.time);

    if (widget.record.isSkip) {
      _polarityType = 2;
    } else if (widget.record.delta < 0) {
      _polarityType = 1;
    } else {
      _polarityType = 0;
    }

    final node = widget.engine.nodes
        .where((n) => n.id == widget.record.nodeId)
        .firstOrNull;
    if (node != null) {
      for (final attr in node.numericAttributes) {
        final existingVal = widget.record.attributeDeltas?[attr.name];
        _attrControllers[attr.name] = TextEditingController(
          text: existingVal != null
              ? (existingVal % 1 == 0
                  ? existingVal.toInt().toString()
                  : existingVal.toString())
              : '',
        );
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

  void _save() {
    final noteText = _noteController.text.trim();
    final isSkip = _polarityType == 2;
    if (isSkip && noteText.isEmpty) {
      setState(() => _errorText = '跳过记录需保留跳过原因');
      return;
    }

    final Map<String, double> attrDeltas = {};
    if (!isSkip) {
      for (final entry in _attrControllers.entries) {
        final val = double.tryParse(entry.value.text.trim());
        if (val != null && val != 0) {
          attrDeltas[entry.key] = val;
        }
      }
    }

    final oldEff = widget.engine.getEffectiveDate(widget.record.time);
    final isSameDate = oldEff.year == _selectedDate.year &&
        oldEff.month == _selectedDate.month &&
        oldEff.day == _selectedDate.day;
    final finalTime = isSameDate ? widget.record.time : _selectedDate;

    final int nextDelta = isSkip ? 0 : (_polarityType == 0 ? 1 : -1);

    widget.engine.updateRecord(
      recordId: widget.record.id,
      newDate: finalTime,
      newDelta: nextDelta,
      newIsSkip: isSkip,
      newNote: noteText,
      newTags: _selectedTags.toList(),
      newAttributeDeltas: attrDeltas,
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bool isGain = _polarityType == 0;
    final bool isSkip = _polarityType == 2;

    final Color themeColor = isSkip
        ? Colors.blueGrey.shade700
        : (isGain ? Colors.green.shade700 : Colors.red.shade700);

    final historicalTags = widget.engine.getHistoricalTags(
      isIncrease: isGain,
      isSkip: isSkip,
    );
    final allDisplayTags = {...historicalTags, ..._selectedTags}.toList();

    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    final node = widget.engine.nodes
        .where((n) => n.id == widget.record.nodeId)
        .firstOrNull;

    return AlertDialog(
      backgroundColor: AppTheme.surfaceWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        '编辑记录 · ${widget.record.nodeTitle}',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppTheme.deepNavy,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 记录加减性切换栏
              const Text(
                '记录类型（加减性）',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.deepNavy,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildPolarityTab(
                    label: '增加 (+1)',
                    selected: _polarityType == 0,
                    activeColor: Colors.green.shade700,
                    activeBg: const Color(0xFFF2FBF4),
                    onTap: () => setState(() {
                      _polarityType = 0;
                      _errorText = null;
                    }),
                  ),
                  const SizedBox(width: 8),
                  _buildPolarityTab(
                    label: '减少 (-1)',
                    selected: _polarityType == 1,
                    activeColor: Colors.red.shade700,
                    activeBg: const Color(0xFFFDF3F3),
                    onTap: () => setState(() {
                      _polarityType = 1;
                      _errorText = null;
                    }),
                  ),
                  const SizedBox(width: 8),
                  _buildPolarityTab(
                    label: '跳过',
                    selected: _polarityType == 2,
                    activeColor: Colors.blueGrey.shade700,
                    activeBg: const Color(0xFFF1F5F9),
                    onTap: () => setState(() => _polarityType = 2),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 2. 归属日期选择
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
                          const Icon(Icons.calendar_today_rounded,
                              size: 13, color: AppTheme.primaryBlue),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 3. 备注输入
              TextField(
                controller: _noteController,
                maxLines: 3,
                onChanged: (_) {
                  if (_errorText != null) {
                    setState(() => _errorText = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: isSkip ? '跳过原因（必填）' : '心得备注',
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

              // 4. 数字属性
              if (!isSkip && node != null && node.numericAttributes.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  '数值属性',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.deepNavy),
                ),
                const SizedBox(height: 6),
                ...node.numericAttributes.map((attr) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: _attrControllers[attr.name],
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
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

              // 5. 标签
              const SizedBox(height: 12),
              const Text(
                '标签归因',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepNavy),
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
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                    onPressed: _addCustomTag,
                    child: const Text('添加',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.primaryBlue)),
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
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: themeColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _save,
          child: const Text('保存修改'),
        ),
      ],
    );
  }

  Widget _buildPolarityTab({
    required String label,
    required bool selected,
    required Color activeColor,
    required Color activeBg,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? activeBg : AppTheme.bgCanvas,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? activeColor : AppTheme.borderLight,
              width: selected ? 1.4 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected ? activeColor : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}