import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../engine/rsip_engine.dart';
import '../../models/focus_node_model.dart';

class EditNodeDialog extends StatefulWidget {
  final FocusNodeModel node;
  final RsipEngine engine;

  const EditNodeDialog({
    super.key,
    required this.node,
    required this.engine,
  });

  @override
  State<EditNodeDialog> createState() => _EditNodeDialogState();
}

class _EditNodeDialogState extends State<EditNodeDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  late bool _promptNoteOnIncrease;
  late bool _promptNoteOnDecrease;

  late int _repeatMode;
  late final Set<int> _selectedWeekdays;
  late int _repeatFreqType;
  late int _repeatFreqValue;

  final List<String> _attrIds = [];
  final List<TextEditingController> _attrNameControllers = [];
  final List<TextEditingController> _attrUnitControllers = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.node.title);
    _contentController = TextEditingController(text: widget.node.content);
    _promptNoteOnIncrease = widget.node.promptNoteOnIncrease;
    _promptNoteOnDecrease = widget.node.promptNoteOnDecrease;

    _repeatMode = widget.node.repeatMode;
    _selectedWeekdays = Set<int>.from(widget.node.repeatWeekdays);
    _repeatFreqType = widget.node.repeatFreqType;
    _repeatFreqValue = widget.node.repeatFreqValue;

    for (final attr in widget.node.numericAttributes) {
      _attrIds.add(attr.id);
      _attrNameControllers.add(TextEditingController(text: attr.name));
      _attrUnitControllers.add(TextEditingController(text: attr.unit));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    for (final c in _attrNameControllers) {
      c.dispose();
    }
    for (final c in _attrUnitControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addNumericField() {
    setState(() {
      _attrIds.add(DateTime.now().microsecondsSinceEpoch.toString());
      _attrNameControllers.add(TextEditingController());
      _attrUnitControllers.add(TextEditingController());
    });
  }

  void _removeNumericField(int index) {
    setState(() {
      _attrIds.removeAt(index);
      _attrNameControllers[index].dispose();
      _attrUnitControllers[index].dispose();
      _attrNameControllers.removeAt(index);
      _attrUnitControllers.removeAt(index);
    });
  }

  Widget _buildToggleBlock({
    required String label,
    required bool isSelected,
    required Color activeColor,
    required Color activeBg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : AppTheme.bgCanvas,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor.withValues(alpha: 0.5) : AppTheme.borderLight,
            width: isSelected ? 1.3 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 14,
              color: isSelected ? activeColor : Colors.black26,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepeatSection() {
    const dayLabels = ['一', '二', '三', '四', '五', '六', '日'];
    const freqLabels = ['每X天', '每周X次', '每月X次'];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.bgCanvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _repeatMode == 0 && _selectedWeekdays.length == 7
                    ? '重复规则：每天'
                    : '重复规则',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.deepNavy,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMiniModeTab('按星期', _repeatMode == 0, () {
                    setState(() => _repeatMode = 0);
                  }),
                  const SizedBox(width: 6),
                  _buildMiniModeTab('按频次', _repeatMode == 1, () {
                    setState(() => _repeatMode = 1);
                  }),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_repeatMode == 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (idx) {
                final day = idx + 1;
                final selected = _selectedWeekdays.contains(day);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (selected && _selectedWeekdays.length > 1) {
                        _selectedWeekdays.remove(day);
                      } else {
                        _selectedWeekdays.add(day);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.primaryBlue : AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: selected ? AppTheme.primaryBlue : AppTheme.borderLight,
                      ),
                    ),
                    child: Text(
                      dayLabels[idx],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: selected ? Colors.white : Colors.black54,
                      ),
                    ),
                  ),
                );
              }),
            )
          else
            Column(
              children: [
                Row(
                  children: List.generate(3, (idx) {
                    final selected = _repeatFreqType == idx;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: idx < 2 ? 6.0 : 0.0),
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _repeatFreqType = idx;
                            final maxLimit = idx == 1 ? 7 : (idx == 2 ? 31 : 99);
                            if (_repeatFreqValue > maxLimit) {
                              _repeatFreqValue = maxLimit;
                            }
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected ? AppTheme.subtleFill : AppTheme.surfaceWhite,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: selected ? AppTheme.primaryBlue : AppTheme.borderLight,
                              ),
                            ),
                            child: Text(
                              freqLabels[idx],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                color: selected ? AppTheme.primaryBlue : Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _repeatFreqType == 0
                          ? '每 '
                          : (_repeatFreqType == 1 ? '每周 ' : '每月 '),
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      constraints: const BoxConstraints(),
                      color: _repeatFreqValue > 1 ? AppTheme.primaryBlue : Colors.black26,
                      onPressed: _repeatFreqValue > 1
                          ? () => setState(() => _repeatFreqValue--)
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceWhite,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Text(
                        '$_repeatFreqValue',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.deepNavy,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      constraints: const BoxConstraints(),
                      color: AppTheme.primaryBlue,
                      onPressed: () {
                        final maxLimit = _repeatFreqType == 1 ? 7 : (_repeatFreqType == 2 ? 31 : 99);
                        if (_repeatFreqValue < maxLimit) {
                          setState(() => _repeatFreqValue++);
                        }
                      },
                    ),
                    Text(
                      _repeatFreqType == 0 ? ' 天' : ' 次',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMiniModeTab(String text, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryBlue : AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: active ? AppTheme.primaryBlue : AppTheme.borderLight,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: active ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty) return;

    final List<NumericAttribute> newAttrs = [];
    for (int i = 0; i < _attrNameControllers.length; i++) {
      final id = _attrIds[i];
      final name = _attrNameControllers[i].text.trim();
      final unit = _attrUnitControllers[i].text.trim();
      if (name.isNotEmpty) {
        final existingIdx =
            widget.node.numericAttributes.indexWhere((a) => a.id == id);
        double existingTotal = 0.0;
        int existingCount = 0;
        if (existingIdx != -1) {
          existingTotal = widget.node.numericAttributes[existingIdx].totalValue;
          existingCount = widget.node.numericAttributes[existingIdx].count;
        }

        newAttrs.add(
          NumericAttribute(
            id: id,
            name: name,
            unit: unit.isEmpty ? '项' : unit,
            totalValue: existingTotal,
            count: existingCount,
          ),
        );
      }
    }

    final List<AttributeChange> attrChanges = [];
    for (final oldAttr in widget.node.numericAttributes) {
      final matchNew = newAttrs.where((a) => a.id == oldAttr.id).firstOrNull;
      if (matchNew == null) {
        attrChanges.add(
          AttributeChange(
            oldName: oldAttr.name,
            oldUnit: oldAttr.unit,
            type: -1,
          ),
        );
      } else if (matchNew.name != oldAttr.name || matchNew.unit != oldAttr.unit) {
        attrChanges.add(
          AttributeChange(
            oldName: oldAttr.name,
            oldUnit: oldAttr.unit,
            newName: matchNew.name,
            newUnit: matchNew.unit,
            type: 0,
          ),
        );
      }
    }

    for (final newAttr in newAttrs) {
      final matchOld =
          widget.node.numericAttributes.where((a) => a.id == newAttr.id).firstOrNull;
      if (matchOld == null) {
        attrChanges.add(
          AttributeChange(
            newName: newAttr.name,
            newUnit: newAttr.unit,
            type: 1,
          ),
        );
      }
    }

    // 计算修改后的重复规则描述
    final newRepeatDesc = FocusNodeModel.formatRepeatRule(
      mode: _repeatMode,
      weekdays: _selectedWeekdays.toList(),
      freqType: _repeatFreqType,
      freqValue: _repeatFreqValue,
    );
    final bool hasRepeatChanged = newRepeatDesc != widget.node.repeatDescription;

    // 标题、内容、重复规则或数字属性任一变动，均触发版本记录确认
    final bool hasContentChanged = title != widget.node.title ||
        content != widget.node.content ||
        hasRepeatChanged ||
        attrChanges.isNotEmpty;

    bool shouldRecord = false;
    if (hasContentChanged) {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surfaceWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text(
            '保存确认',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.deepNavy,
            ),
          ),
          content: const Text(
            '是否保存该次编辑到记录？',
            style: TextStyle(fontSize: 14, color: Colors.black87),
          ),
          actions: [
            TextButton(
              child: const Text('仅修改不记录', style: TextStyle(color: Colors.black45)),
              onPressed: () => Navigator.pop(ctx, false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('确定'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );
      if (result == null || !mounted) return;
      shouldRecord = result;
    }

    widget.engine.updateNode(
      widget.node.id,
      title,
      content,
      promptNoteOnIncrease: _promptNoteOnIncrease,
      promptNoteOnDecrease: _promptNoteOnDecrease,
      repeatMode: _repeatMode,
      repeatWeekdays: _selectedWeekdays.toList()..sort(),
      repeatFreqType: _repeatFreqType,
      repeatFreqValue: _repeatFreqValue,
      numericAttributes: newAttrs,
      attributeChanges: attrChanges,
      recordToHistory: shouldRecord,
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text(
        '编辑国策',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.deepNavy),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: '国策标题',
                  labelStyle: const TextStyle(fontSize: 13),
                  filled: true,
                  fillColor: AppTheme.bgCanvas,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contentController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: '国策内容',
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

              if (!widget.node.isPrompt) ...[
                const SizedBox(height: 12),
                _buildRepeatSection(),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: _buildToggleBlock(
                        label: '增加备注',
                        isSelected: _promptNoteOnIncrease,
                        activeColor: Colors.green.shade700,
                        activeBg: const Color(0xFFF2FBF4),
                        onTap: () => setState(() => _promptNoteOnIncrease = !_promptNoteOnIncrease),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildToggleBlock(
                        label: '减少备注',
                        isSelected: _promptNoteOnDecrease,
                        activeColor: Colors.red.shade700,
                        activeBg: const Color(0xFFFDF3F3),
                        onTap: () => setState(() => _promptNoteOnDecrease = !_promptNoteOnDecrease),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '数字属性定义',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.deepNavy),
                        ),
                        Text(
                          '修改名称将自动同步历史数据',
                          style: TextStyle(fontSize: 10, color: Colors.black38),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.add, size: 16, color: AppTheme.primaryBlue),
                      label: const Text('添加属性', style: TextStyle(fontSize: 12, color: AppTheme.primaryBlue)),
                      onPressed: _addNumericField,
                    ),
                  ],
                ),
                ...List.generate(_attrNameControllers.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: TextField(
                            controller: _attrNameControllers[index],
                            decoration: InputDecoration(
                              hintText: '属性名称 (如: 耗时)',
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
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _attrUnitControllers[index],
                            decoration: InputDecoration(
                              hintText: '单位 (如: 分钟)',
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
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.redAccent),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _removeNumericField(index),
                        ),
                      ],
                    ),
                  );
                }),
              ],
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
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _handleSave,
          child: const Text('保存修改'),
        ),
      ],
    );
  }
}