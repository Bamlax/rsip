import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'widgets/statistics_view.dart';

class MainScreen extends StatefulWidget {
  final RsipEngine engine;

  const MainScreen({super.key, required this.engine});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentViewIndex = 0;
  bool _isConnectMode = false;

  static const List<({String label, IconData icon, IconData activeIcon})>
      _navItems = [
    (
      label: '列表',
      icon: Icons.list_alt_rounded,
      activeIcon: Icons.list_alt,
    ),
    (
      label: '树',
      icon: Icons.account_tree_outlined,
      activeIcon: Icons.account_tree,
    ),
    (
      label: '历史',
      icon: Icons.history_rounded,
      activeIcon: Icons.history,
    ),
    (
      label: '统计',
      icon: Icons.analytics_outlined,
      activeIcon: Icons.analytics,
    ),
    (
      label: '设置',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
    ),
  ];

  bool _shouldUseSideNav(BuildContext context) {
    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    return isDesktop || MediaQuery.of(context).size.width >= 720;
  }

  void _switchTab(int idx) {
    widget.engine.selectNode(null);
    widget.engine.selectConnection(null);
    widget.engine.cancelGroupSelectMode();
    if (widget.engine.isArchiveMode) {
      widget.engine.cancelArchiveMode();
    }
    if (widget.engine.isTimelineMode) {
      widget.engine.toggleTimelineMode(false);
    }
    setState(() {
      _currentViewIndex = idx;
      if (idx != 1) _isConnectMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final useSideNav = _shouldUseSideNav(context);

    return ListenableBuilder(
      listenable: widget.engine,
      builder: (context, _) {
        final selectedNode = widget.engine.selectedNode;
        final selectedConnection = widget.engine.selectedConnection;
        final inGroupMode = widget.engine.isGroupSelectMode;
        final inArchiveMode = widget.engine.isArchiveMode;
        final inTimelineMode = widget.engine.isTimelineMode;

        final appBar = _buildAppBar(
          selectedNode: selectedNode,
          selectedConnection: selectedConnection,
          inGroupMode: inGroupMode,
          inArchiveMode: inArchiveMode,
          inTimelineMode: inTimelineMode,
          useSideNav: useSideNav,
        );

        final bodyContent = IndexedStack(
          index: _currentViewIndex,
          children: [
            NodeListView(engine: widget.engine),
            NodeCanvasView(
              engine: widget.engine,
              isConnectMode: _isConnectMode,
            ),
            HistoryView(engine: widget.engine),
            StatisticsView(engine: widget.engine),
            SettingsView(engine: widget.engine),
          ],
        );

        final fab = ((_currentViewIndex == 0 || _currentViewIndex == 1) &&
                !inArchiveMode &&
                !inGroupMode &&
                !inTimelineMode)
            ? FloatingActionButton(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 2,
                child: const Icon(Icons.add),
                onPressed: () => _openAddDialog(context),
              )
            : null;

        if (useSideNav) {
          return Scaffold(
            backgroundColor: AppTheme.bgCanvas,
            body: Row(
              children: [
                _buildDesktopSidebar(),
                Expanded(
                  child: Scaffold(
                    backgroundColor: AppTheme.bgCanvas,
                    appBar: appBar,
                    body: bodyContent,
                    floatingActionButton: fab,
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.bgCanvas,
          appBar: appBar,
          body: bodyContent,
          floatingActionButton: fab,
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
              onTap: _switchTab,
              items: _navItems
                  .map(
                    (item) => BottomNavigationBarItem(
                      icon: Icon(item.icon),
                      activeIcon: Icon(item.activeIcon),
                      label: item.label,
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopSidebar() {
    return Container(
      width: 76,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceWhite,
        border: Border(
          right: BorderSide(color: AppTheme.borderLight, width: 1.0),
        ),
      ),
      child: Column(
        children: [
          Container(
            height: kToolbarHeight,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.borderLight, width: 0.8),
              ),
            ),
            child: const Text(
              'RSIP',
              style: TextStyle(
                color: Colors.black,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _navItems.length,
              itemBuilder: (context, idx) {
                final item = _navItems[idx];
                final isSelected = _currentViewIndex == idx;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _switchTab(idx),
                      borderRadius: BorderRadius.circular(10),
                      hoverColor: AppTheme.bgCanvas,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.subtleFill
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected ? item.activeIcon : item.icon,
                              size: 22,
                              color: isSelected
                                  ? AppTheme.primaryBlue
                                  : Colors.black45,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppTheme.primaryBlue
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({
    required FocusNodeModel? selectedNode,
    required FocusConnection? selectedConnection,
    required bool inGroupMode,
    required bool inArchiveMode,
    required bool inTimelineMode,
    required bool useSideNav,
  }) {
    return AppBar(
      backgroundColor: AppTheme.surfaceWhite,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leadingWidth: inArchiveMode ? 68 : null,
      leading: inArchiveMode
          ? TextButton(
              onPressed: () => widget.engine.cancelArchiveMode(),
              child: const Text(
                '取消',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            )
          : null,
      centerTitle: inArchiveMode,
      bottom: useSideNav
          ? const PreferredSize(
              preferredSize: Size.fromHeight(0.8),
              child: Divider(
                height: 0.8,
                thickness: 0.8,
                color: AppTheme.borderLight,
              ),
            )
          : null,
      title: inTimelineMode
          ? const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timeline_rounded,
                  size: 20,
                  color: AppTheme.primaryBlue,
                ),
                SizedBox(width: 8),
                Text(
                  '时间轴回放',
                  style: TextStyle(
                    color: AppTheme.deepNavy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            )
          : inGroupMode
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
          : inArchiveMode
          ? Text(
              '归档管理 (${widget.engine.archiveSelectedIds.length})',
              style: const TextStyle(
                color: AppTheme.deepNavy,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            )
          : selectedConnection != null
          ? const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.hub_outlined,
                  size: 20,
                  color: AppTheme.primaryBlue,
                ),
                SizedBox(width: 8),
                Text(
                  '连线',
                  style: TextStyle(
                    color: AppTheme.deepNavy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            )
          : selectedNode == null
          ? Text(
              useSideNav ? _navItems[_currentViewIndex].label : 'RSIP',
              style: TextStyle(
                color: useSideNav ? AppTheme.deepNavy : Colors.black,
                fontSize: useSideNav ? 18 : 22,
                fontWeight: FontWeight.w900,
                letterSpacing: useSideNav ? 0.5 : 1.5,
              ),
            )
          : _buildSelectedNodeTitle(selectedNode),
      actions: _buildAppBarActions(
        selectedNode,
        selectedConnection,
        inGroupMode,
        inArchiveMode,
        inTimelineMode,
      ),
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

    final displayMode = widget.engine.displayMode;
    final scoreRes = widget.engine.getNodeScore(node.id);
    final scoreColor = ProgressColorHelper.getScoreColor(scoreRes.score);
    final scoreBgColor = ProgressColorHelper.getScoreBgColor(scoreRes.score);

    final incTextColor =
        ProgressColorHelper.getIncreaseColor(node.increaseCount);
    final incBgColor =
        ProgressColorHelper.getIncreaseBgColor(node.increaseCount);

    final consecutiveCount = widget.engine.getNodeConsecutiveCount(node.id);
    final consTextColor =
        ProgressColorHelper.getIncreaseColor(consecutiveCount);
    final consBgColor =
        ProgressColorHelper.getIncreaseBgColor(consecutiveCount);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (displayMode == 1) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: incBgColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '+${node.increaseCount}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: incTextColor,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '-${node.decreaseCount}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.red.shade700,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ] else if (displayMode == 2) ...[
          if (consecutiveCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: consBgColor,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: consTextColor.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                '连续 $consecutiveCount 次',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: consTextColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: scoreBgColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: scoreColor.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              '${scoreRes.score.toStringAsFixed(1)}分',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: scoreColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
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

  Widget _buildTimelineToggleSwitch(bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: InkWell(
        onTap: () {
          setState(() => _isConnectMode = false);
          widget.engine.toggleTimelineMode(!active);
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: active ? AppTheme.primaryBlue : AppTheme.bgCanvas,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? AppTheme.primaryBlue : AppTheme.borderLight,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timeline_rounded,
                size: 15,
                color: active ? Colors.white : AppTheme.deepNavy,
              ),
              const SizedBox(width: 4),
              Text(
                '时间轴',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : AppTheme.deepNavy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAppBarActions(
    FocusNodeModel? selectedNode,
    FocusConnection? selectedConnection,
    bool inGroupMode,
    bool inArchiveMode,
    bool inTimelineMode,
  ) {
    // 0. 树界面时间轴模式开启态：顶部保留开启状态的时间轴开关以便一键关闭
    if (_currentViewIndex == 1 && inTimelineMode) {
      return [
        _buildTimelineToggleSwitch(true),
        const SizedBox(width: 8),
      ];
    }

    // 1. 归档模式
    if (inArchiveMode) {
      return [
        IconButton(
          icon: const Icon(
            Icons.add_rounded,
            size: 24,
            color: AppTheme.primaryBlue,
          ),
          tooltip: '保存当前归档为分类',
          onPressed: _openSaveArchivePresetDialog,
        ),
        TextButton(
          onPressed: () {
            widget.engine.saveArchiveSelections();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('归档设置已更新'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: const Text(
            '完成',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryBlue,
            ),
          ),
        ),
        const SizedBox(width: 4),
      ];
    }

    // 2. 框选模式
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

    // 3. 点击连线选中态
    if (selectedConnection != null) {
      return [
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          tooltip: '删除此连线',
          onPressed: () => _confirmDeleteConnection(selectedConnection),
        ),
        const SizedBox(width: 4),
      ];
    }

    // 4. 选中节点态
    if (selectedNode != null) {
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
          const SizedBox(width: 4),
        ];
      }

      return [
        IconButton(
          icon: const Icon(
            Icons.remove_circle_outline,
            color: Colors.redAccent,
          ),
          tooltip: '减少',
          onPressed: () => _handleProgressChange(selectedNode, -1),
        ),
        IconButton(
          icon: Icon(
            Icons.skip_next_rounded,
            color: Colors.blueGrey.shade700,
          ),
          tooltip: '跳过（填写原因）',
          onPressed: () => _handleSkipNode(selectedNode),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, color: Colors.green),
          tooltip: '增加',
          onPressed: () => _handleProgressChange(selectedNode, 1),
        ),
        IconButton(
          icon: const Icon(
            Icons.assessment_outlined,
            color: AppTheme.primaryBlue,
          ),
          tooltip: '查看节点详情与管理',
          onPressed: () => _openNodeDetail(selectedNode.id),
        ),
        const SizedBox(width: 4),
      ];
    }

    // 5. 树界面常规态：顶部出现时间轴开关 + 框选 + 连线
    if (_currentViewIndex == 1) {
      return [
        _buildTimelineToggleSwitch(false),
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
                content:
                    Text(_isConnectMode ? '连线模式：依次点击两个国策建立连线' : '已退出连线模式'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        const SizedBox(width: 8),
      ];
    }

    // 6. 列表界面常规态
    if (_currentViewIndex == 0) {
      return [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: AppTheme.deepNavy),
          tooltip: '更多操作',
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          color: AppTheme.surfaceWhite,
          onSelected: (val) {
            if (val == 'archive') {
              widget.engine.startArchiveMode();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'archive',
              child: Row(
                children: [
                  Icon(Icons.archive_outlined,
                      size: 18, color: AppTheme.deepNavy),
                  SizedBox(width: 8),
                  Text(
                    '归档',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.deepNavy,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ];
    }

    return const [];
  }

  void _openSaveArchivePresetDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          '保存归档分类',
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
            labelText: '分类名称',
            hintText: '如：工作日 / 假期精简 / 考试周',
            labelStyle: const TextStyle(fontSize: 13),
            filled: true,
            fillColor: AppTheme.bgCanvas,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (val) {
            final name = val.trim();
            if (name.isEmpty) return;
            widget.engine.addArchivePreset(name);
            Navigator.pop(ctx);
          },
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('保存'),
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              widget.engine.addArchivePreset(name);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

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
        builder: (ctx) =>
            NodeDetailScreen(nodeId: nodeId, engine: widget.engine),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('确认生成'),
            onPressed: () {
              final title = nameController.text.trim();
              if (title.isEmpty) return;

              widget.engine.addGroup(title: title, nodeIds: selectedIds);
              widget.engine.cancelGroupSelectMode();
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleProgressChange(FocusNodeModel node, int delta) async {
    final shouldPrompt =
        delta > 0 ? node.promptNoteOnIncrease : node.promptNoteOnDecrease;

    if (shouldPrompt || node.numericAttributes.isNotEmpty) {
      final result = await showDialog<ProgressSubmitData?>(
        context: context,
        builder: (ctx) => ProgressNoteDialog(
          nodeTitle: node.title,
          delta: delta,
          attributes: node.numericAttributes,
          engine: widget.engine,
        ),
      );
      if (result == null && !mounted) return;
      if (result != null) {
        widget.engine.changeProgress(
          node.id,
          delta,
          note: result.note,
          tags: result.tags,
          attributeDeltas: result.attributeDeltas,
          recordDate: result.date,
        );
        widget.engine.selectNode(null);
      }
    } else {
      widget.engine.changeProgress(node.id, delta);
      widget.engine.selectNode(null);
    }
  }

  Future<void> _handleSkipNode(FocusNodeModel node) async {
    final result = await showDialog<ProgressSubmitData?>(
      context: context,
      builder: (ctx) => ProgressNoteDialog(
        nodeTitle: node.title,
        delta: 0,
        isSkip: true,
        attributes: const [],
        engine: widget.engine,
      ),
    );
    if (result != null && result.note != null && result.note!.isNotEmpty) {
      widget.engine.skipNode(
        node.id,
        reason: result.note!,
        tags: result.tags,
        recordDate: result.date,
      );
      widget.engine.selectNode(null);
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