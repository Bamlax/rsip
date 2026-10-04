import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/progress_color_helper.dart';
import '../engine/rsip_engine.dart';
import '../models/focus_node_model.dart';
import 'widgets/add_node_dialog.dart';
import 'widgets/edit_node_dialog.dart';
import 'widgets/history_view.dart';
import 'widgets/node_canvas_view.dart';
import 'widgets/node_detail_screen.dart';
import 'widgets/node_list_view.dart';
import 'widgets/progress_note_dialog.dart';
import 'widgets/settings_view.dart';

class MainScreen extends StatefulWidget {
  final RsipEngine engine;

  const MainScreen({super.key, required this.engine});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentViewIndex = 0;
  bool _isConnectMode = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.engine,
      builder: (context, _) {
        final selectedNode = widget.engine.selectedNode;
        final selectedConnection = widget.engine.selectedConnection;
        final inGroupMode = widget.engine.isGroupSelectMode;

        return Scaffold(
          backgroundColor: AppTheme.bgCanvas,
          appBar: AppBar(
            backgroundColor: AppTheme.surfaceWhite,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: inGroupMode
                ? Row(
                    children: [
                      const Icon(
                        Icons.dashboard_customize_rounded,
                        size: 20,
                        color: AppTheme.primaryBlue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '框选模式 (已选 ${widget.engine.groupSelectedNodeIds.length} 个)',
                        style: const TextStyle(
                          color: AppTheme.deepNavy,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  )
                : selectedConnection != null
                    // 1. 选中连线时的顶栏标题
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hub_outlined, size: 20, color: AppTheme.primaryBlue),
                          SizedBox(width: 8),
                          Text(
                            '国策连线',
                            style: TextStyle(
                              color: AppTheme.deepNavy,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      )
                    : selectedNode == null
                        ? const Text(
                            'RSIP',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          )
                        : _buildSelectedNodeTitle(selectedNode),
            actions: _buildAppBarActions(selectedNode, selectedConnection, inGroupMode),
          ),
          body: IndexedStack(
            index: _currentViewIndex,
            children: [
              NodeListView(engine: widget.engine),
              NodeCanvasView(
                engine: widget.engine,
                isConnectMode: _isConnectMode,
              ),
              HistoryView(engine: widget.engine),
              SettingsView(engine: widget.engine),
            ],
          ),
          floatingActionButton: _currentViewIndex == 0
              ? FloatingActionButton(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  child: const Icon(Icons.add),
                  onPressed: () => _openAddDialog(context),
                )
              : null,
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: AppTheme.surfaceWhite,
              border: Border(top: BorderSide(color: AppTheme.borderLight)),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentViewIndex,
              backgroundColor: AppTheme.surfaceWhite,
              selectedItemColor: AppTheme.primaryBlue,
              unselectedItemColor: Colors.black38,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              onTap: (idx) {
                widget.engine.selectNode(null);
                widget.engine.selectConnection(null);
                widget.engine.cancelGroupSelectMode();
                setState(() {
                  _currentViewIndex = idx;
                  if (idx != 1) _isConnectMode = false;
                });
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.list_alt_rounded),
                  activeIcon: Icon(Icons.list_alt),
                  label: '列表',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.account_tree_outlined),
                  activeIcon: Icon(Icons.account_tree),
                  label: '树',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history_rounded),
                  activeIcon: Icon(Icons.history),
                  label: '历史',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label: '设置',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectedNodeTitle(FocusNodeModel node) {
    if (node.isPrompt) {
      return Flexible(
        child: Text(
          node.content.isEmpty ? node.title : node.content,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: ProgressColorHelper.getBgColor(node.progress),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: ProgressColorHelper.getColor(node.progress).withValues(alpha: 0.5),
            ),
          ),
          child: Text(
            node.progress >= 0 ? '+${node.progress}' : '${node.progress}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: ProgressColorHelper.getColor(node.progress),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            node.title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildAppBarActions(
    FocusNodeModel? selectedNode,
    FocusConnection? selectedConnection,
    bool inGroupMode,
  ) {
    // 1. 框选模式
    if (inGroupMode) {
      return [
        IconButton(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: AppTheme.primaryBlue,
            size: 28,
          ),
          tooltip: '完成框选并输入名称',
          onPressed: _confirmGroupCreationOnCanvas,
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.black45),
          tooltip: '退出框选模式',
          onPressed: () => widget.engine.cancelGroupSelectMode(),
        ),
        const SizedBox(width: 4),
      ];
    }

    // 2. 【点击连线后：显示删除连线按钮与取消按钮】
    if (selectedConnection != null) {
      return [
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          tooltip: '删除此连线',
          onPressed: () => _confirmDeleteConnection(selectedConnection),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.black38),
          tooltip: '取消选中',
          onPressed: () => widget.engine.selectConnection(null),
        ),
        const SizedBox(width: 4),
      ];
    }

    // 3. 选中节点态
    if (selectedNode != null) {
      // 【提示块没有详情，不能加减，仅允许编辑、删除与取消】
      if (selectedNode.isPrompt) {
        return [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryBlue),
            tooltip: '编辑提示内容',
            onPressed: () => _openEditDialog(context, selectedNode),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: '删除提示节点',
            onPressed: () => _confirmDeleteNode(selectedNode),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black38),
            tooltip: '取消选中',
            onPressed: () => widget.engine.selectNode(null),
          ),
          const SizedBox(width: 4),
        ];
      }

      // 常规节点：保留进度加减、详情入口与取消
      return [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
          tooltip: '进度 -1',
          onPressed: () => _handleProgressChange(selectedNode, -1),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, color: Colors.green),
          tooltip: '进度 +1',
          onPressed: () => _handleProgressChange(selectedNode, 1),
        ),
        IconButton(
          icon: const Icon(Icons.assessment_outlined, color: AppTheme.primaryBlue),
          tooltip: '查看节点详情与管理',
          onPressed: () => _openNodeDetail(selectedNode.id),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.black38),
          tooltip: '取消选中',
          onPressed: () => widget.engine.selectNode(null),
        ),
        const SizedBox(width: 4),
      ];
    }

    // 4. 树界面常规态
    if (_currentViewIndex == 1) {
      return [
        IconButton(
          icon: const Icon(
            Icons.dashboard_customize_outlined,
            color: Colors.black87,
          ),
          tooltip: '在画布上框选组合大节点',
          onPressed: () => widget.engine.startGroupSelectMode(),
        ),
        IconButton(
          icon: Icon(
            _isConnectMode ? Icons.hub : Icons.hub_outlined,
            color: _isConnectMode ? AppTheme.primaryBlue : Colors.black87,
          ),
          tooltip: _isConnectMode ? '退出连线模式' : '连线模式',
          onPressed: () {
            setState(() => _isConnectMode = !_isConnectMode);
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _isConnectMode ? '连线模式：依次点击两个国策建立连线' : '已退出连线模式',
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        const SizedBox(width: 8),
      ];
    }

    return const [];
  }

  /// 连线删除确认弹窗
  void _confirmDeleteConnection(FocusConnection conn) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          '确认删除连线？',
          style: TextStyle(
            color: AppTheme.deepNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text('将移除这两个国策节点之间的关联连线。'),
        actions: [
          TextButton(
            child: const Text('取消', style: TextStyle(color: Colors.black45)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('确认删除'),
            onPressed: () {
              widget.engine.deleteConnection(conn);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteNode(FocusNodeModel node) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          '确认删除？',
          style: TextStyle(
            color: AppTheme.deepNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text('将彻底删除「${node.title}」及其关联连线。'),
        actions: [
          TextButton(
            child: const Text('取消', style: TextStyle(color: Colors.black45)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('确认删除'),
            onPressed: () {
              widget.engine.deleteNode(node.id);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _openNodeDetail(String nodeId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => NodeDetailScreen(
          nodeId: nodeId,
          engine: widget.engine,
        ),
      ),
    );
  }

  void _confirmGroupCreationOnCanvas() {
    final selectedIds = widget.engine.groupSelectedNodeIds;
    if (selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请直接在画布上点击至少 1 个国策卡片'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          '创建大节点',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.deepNavy,
          ),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: '大节点名称 (不含内容)',
            hintText: '如：晨间习惯流 / 核心工作组',
            labelStyle: const TextStyle(fontSize: 13),
            filled: true,
            fillColor: AppTheme.bgCanvas,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('取消', style: TextStyle(color: Colors.black45)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('确认生成'),
            onPressed: () {
              final title = nameController.text.trim();
              if (title.isEmpty) return;

              widget.engine.addGroup(
                title: title,
                nodeIds: selectedIds,
              );
              widget.engine.cancelGroupSelectMode();
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleProgressChange(FocusNodeModel node, int delta) async {
    final shouldPrompt = delta > 0
        ? widget.engine.promptNoteOnIncrease
        : widget.engine.promptNoteOnDecrease;

    if (shouldPrompt || node.numericAttributes.isNotEmpty) {
      final result = await showDialog<ProgressSubmitData?>(
        context: context,
        builder: (ctx) => ProgressNoteDialog(
          nodeTitle: node.title,
          delta: delta,
          attributes: node.numericAttributes,
        ),
      );
      if (result == null && !mounted) return;
      if (result != null) {
        widget.engine.changeProgress(
          node.id,
          delta,
          note: result.note,
          attributeDeltas: result.attributeDeltas,
        );
      }
    } else {
      widget.engine.changeProgress(node.id, delta);
    }
  }

  void _openAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AddNodeDialog(engine: widget.engine),
    );
  }

  void _openEditDialog(BuildContext context, FocusNodeModel node) {
    showDialog(
      context: context,
      builder: (ctx) => EditNodeDialog(node: node, engine: widget.engine),
    );
  }
}