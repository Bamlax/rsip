import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../engine/rsip_engine.dart';
import '../../models/focus_node_model.dart';

class AddNodeDialog extends StatefulWidget {
  final RsipEngine engine;

  const AddNodeDialog({super.key, required this.engine});

  @override
  State<AddNodeDialog> createState() => _AddNodeDialogState();
}

class _AddNodeDialogState extends State<AddNodeDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isPrompt = false;

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
                maxLines: _isPrompt ? 3 : 3,
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

              // 属性定义区：仅填名称与单位，数值在加减进度时填入
              if (!_isPrompt) ...[
                const SizedBox(height: 16),
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
              numericAttributes: attrs,
            );
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}