import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../engine/rsip_engine.dart';
import '../../models/focus_node_model.dart';

class AddNodeDialog extends StatefulWidget {
  final RsipEngine engine;
  final Offset? spawnPosition;

  const AddNodeDialog({
    super.key,
    required this.engine,
    this.spawnPosition,
  });

  @override
  State<AddNodeDialog> createState() => _AddNodeDialogState();
}

class _AddNodeDialogState extends State<AddNodeDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isPrompt = false;

  bool _promptNoteOnIncrease = true;
  bool _promptNoteOnDecrease = true;

  // 重复模式状态：默认模式0且全选7天（每天）
  int _repeatMode = 0; // 0: 周一至周日自选, 1: 周期/频次
  final Set<int> _selectedWeekdays = {1, 2, 3, 4, 5, 6, 7};
  int _repeatFreqType = 0; // 0: 每x天, 1: 每周x次, 2: 每月x次
  int _repeatFreqValue = 1;

  final List<TextEditingController> _attrNameControllers = [];
  final List<TextEditingController> _attrUnitControllers = [];

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
      _attrNameControllers.add(TextEditingController());
      _attrUnitControllers.add(TextEditingController());
    });
  }

  void _removeNumericField(int index) {
    setState(() {
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
          // 顶部模式切换栏
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
            // 模式一：周一到周日自选
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
            // 模式二：每x天 / 每周x次 / 每月x次
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        _isPrompt ? '添加提示节点' : '添加国策节点',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.deepNavy),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('常规国策'),
                    selected: !_isPrompt,
                    selectedColor: AppTheme.subtleFill,
                    labelStyle: TextStyle(
                      color: !_isPrompt ? AppTheme.primaryBlue : Colors.black54,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) => setState(() => _isPrompt = !val),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('提示节点'),
                    selected: _isPrompt,
                    selectedColor: AppTheme.subtleFill,
                    labelStyle: TextStyle(
                      color: _isPrompt ? AppTheme.primaryBlue : Colors.black54,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) => setState(() => _isPrompt = val),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!_isPrompt) ...[
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: '国策标题',
                    hintText: '如：专注学习',
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
              ],
              TextField(
                controller: _contentController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: _isPrompt ? '提示内容' : '国策内容',
                  hintText: _isPrompt ? '写下备忘心得、提醒事项...' : '写下具体执行细则...',
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

              if (!_isPrompt) ...[
                const SizedBox(height: 12),
                // 重复天数选项
                _buildRepeatSection(),
                const SizedBox(height: 10),

                // 增加/减少备注左右长方形开关块
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

                // 数字属性定义
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
                          '数值将在每次加减打卡中录入',
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
          child: const Text('添加'),
          onPressed: () {
            final content = _contentController.text.trim();
            if (content.isEmpty) return;

            final title = _isPrompt
                ? (_titleController.text.trim().isEmpty ? '提示' : _titleController.text.trim())
                : _titleController.text.trim();

            if (!_isPrompt && title.isEmpty) return;

            final List<NumericAttribute> attrs = [];
            for (int i = 0; i < _attrNameControllers.length; i++) {
              final name = _attrNameControllers[i].text.trim();
              final unit = _attrUnitControllers[i].text.trim();
              if (name.isNotEmpty) {
                attrs.add(NumericAttribute(name: name, unit: unit.isEmpty ? '项' : unit));
              }
            }

            widget.engine.addNode(
              title: title,
              content: content,
              isPrompt: _isPrompt,
              promptNoteOnIncrease: _promptNoteOnIncrease,
              promptNoteOnDecrease: _promptNoteOnDecrease,
              repeatMode: _repeatMode,
              repeatWeekdays: _selectedWeekdays.toList()..sort(),
              repeatFreqType: _repeatFreqType,
              repeatFreqValue: _repeatFreqValue,
              numericAttributes: attrs,
              x: widget.spawnPosition?.dx,
              y: widget.spawnPosition?.dy,
            );
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}