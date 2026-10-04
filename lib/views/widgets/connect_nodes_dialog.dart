import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../engine/rsip_engine.dart';

class ConnectNodesDialog extends StatefulWidget {
  final RsipEngine engine;

  const ConnectNodesDialog({super.key, required this.engine});

  @override
  State<ConnectNodesDialog> createState() => _ConnectNodesDialogState();
}

class _ConnectNodesDialogState extends State<ConnectNodesDialog> {
  String? _selectedA;
  String? _selectedB;

  @override
  void initState() {
    super.initState();
    if (widget.engine.nodes.length >= 2) {
      _selectedA = widget.engine.nodes[0].id;
      _selectedB = widget.engine.nodes[1].id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nodes = widget.engine.nodes;

    if (nodes.length < 2) {
      return AlertDialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('提示', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.deepNavy)),
        content: const Text('当前国策少于 2 个，请先在「列表」页面添加至少两个国策后再尝试加线。'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            child: const Text('好的', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: AppTheme.surfaceWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Row(
        children: [
          Icon(Icons.hub_outlined, color: AppTheme.primaryBlue, size: 22),
          SizedBox(width: 8),
          Text(
            '连接两个国策',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.deepNavy),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('选择起始国策：', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 6),
          _buildDropdown(
            value: _selectedA,
            onChanged: (val) => setState(() => _selectedA = val),
          ),
          const SizedBox(height: 14),
          const Text('选择目标国策：', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 6),
          _buildDropdown(
            value: _selectedB,
            onChanged: (val) => setState(() => _selectedB = val),
          ),
        ],
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
          child: const Text('确认加线'),
          onPressed: () {
            if (_selectedA == null || _selectedB == null || _selectedA == _selectedB) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请选择两个不同的国策进行连接！')),
              );
              return;
            }
            widget.engine.addConnection(_selectedA!, _selectedB!);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCanvas,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          items: widget.engine.nodes.map((node) {
            return DropdownMenuItem<String>(
              value: node.id,
              child: Text(
                node.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: AppTheme.deepNavy),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}