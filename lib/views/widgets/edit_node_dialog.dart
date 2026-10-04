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

  final List<String> _attrIds = [];
  final List<TextEditingController> _attrNameControllers = [];
  final List<TextEditingController> _attrUnitControllers = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.node.title);
    _contentController = TextEditingController(text: widget.node.content);

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

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty) return;

    final shouldRecord = await showDialog<bool>(
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

    if (shouldRecord == null || !mounted) return;

    final List<NumericAttribute> newAttrs = [];
    for (int i = 0; i < _attrNameControllers.length; i++) {
      final id = _attrIds[i];
      final name = _attrNameControllers[i].text.trim();
      final unit = _attrUnitControllers[i].text.trim();
      if (name.isNotEmpty) {
        // 根据 id 寻找原属性，更名或换单位依然继承原有的 totalValue 与 count
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

    // 统计属性的增、删、改差异
    final List<AttributeChange> attrChanges = [];

    // 1. 比对旧属性：检查被删除或被修改的属性
    for (final oldAttr in widget.node.numericAttributes) {
      final matchNew = newAttrs.where((a) => a.id == oldAttr.id).firstOrNull;
      if (matchNew == null) {
        attrChanges.add(
          AttributeChange(
            oldName: oldAttr.name,
            oldUnit: oldAttr.unit,
            type: -1, // 被删除
          ),
        );
      } else if (matchNew.name != oldAttr.name || matchNew.unit != oldAttr.unit) {
        attrChanges.add(
          AttributeChange(
            oldName: oldAttr.name,
            oldUnit: oldAttr.unit,
            newName: matchNew.name,
            newUnit: matchNew.unit,
            type: 0, // 被修改
          ),
        );
      }
    }

    // 2. 比对新属性：检查新增的属性
    for (final newAttr in newAttrs) {
      final matchOld =
          widget.node.numericAttributes.where((a) => a.id == newAttr.id).firstOrNull;
      if (matchOld == null) {
        attrChanges.add(
          AttributeChange(
            newName: newAttr.name,
            newUnit: newAttr.unit,
            type: 1, // 新增
          ),
        );
      }
    }

    widget.engine.updateNode(
      widget.node.id,
      title,
      content,
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