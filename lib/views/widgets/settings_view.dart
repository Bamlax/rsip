import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/version_history.dart';
import '../../engine/rsip_engine.dart';
import '../../models/focus_node_model.dart';
import 'version_history_screen.dart';

class SettingsView extends StatelessWidget {
  final RsipEngine engine;

  const SettingsView({super.key, required this.engine});

  void _showDisplayModeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final currentMode = engine.displayMode;
        return AlertDialog(
          backgroundColor: AppTheme.surfaceWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text(
            '选择显示方式',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepNavy,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDisplayOptionTile(
                context: ctx,
                title: '习惯连续性分数',
                subtitle: '显示 0 ~ 100 动态健康度得分',
                isSelected: currentMode == 0,
                onTap: () {
                  engine.setDisplayMode(0);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
              _buildDisplayOptionTile(
                context: ctx,
                title: '直接显示加减次数',
                subtitle: '分别显示累计增加 (+X) 与减少 (-Y) 次数',
                isSelected: currentMode == 1,
                onTap: () {
                  engine.setDisplayMode(1);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
              _buildDisplayOptionTile(
                context: ctx,
                title: '连续次数显示',
                subtitle: '显示当前连续正向打钩的次数',
                isSelected: currentMode == 2,
                onTap: () {
                  engine.setDisplayMode(2);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDisplayOptionTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.subtleFill : AppTheme.bgCanvas,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : AppTheme.borderLight,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 18,
              color: isSelected ? AppTheme.primaryBlue : Colors.black38,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppTheme.primaryBlue : AppTheme.deepNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDayOffsetDialog(BuildContext context) {
    int tempOffset = engine.dayStartHourOffset;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surfaceWhite,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Text(
              '延后新一天起始时间',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.deepNavy),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '凌晨在此时间之前记录的打卡，仍计入前一天：',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 28),
                      color: tempOffset > 0 ? AppTheme.primaryBlue : Colors.black26,
                      onPressed: tempOffset > 0
                          ? () => setDialogState(() => tempOffset--)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCanvas,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Text(
                        '$tempOffset 小时',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.deepNavy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 28),
                      color: tempOffset < 12 ? AppTheme.primaryBlue : Colors.black26,
                      onPressed: tempOffset < 12
                          ? () => setDialogState(() => tempOffset++)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  tempOffset == 0 ? '不延后 (00:00 开启新一天)' : '凌晨 0$tempOffset:00 前算作前一天',
                  style: const TextStyle(fontSize: 12, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600),
                ),
              ],
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
                child: const Text('确定'),
                onPressed: () {
                  engine.setDayStartHourOffset(tempOffset);
                  Navigator.pop(ctx);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmClearData(BuildContext context) {
    bool deleteProgress = true;
    bool deleteRevisions = false;
    bool deleteNodes = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isAllSelected =
              deleteProgress && deleteRevisions && deleteNodes;
          final hasAnySelected =
              deleteProgress || deleteRevisions || deleteNodes;

          return AlertDialog(
            backgroundColor: AppTheme.surfaceWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '选择要删除的数据',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepNavy,
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () {
                    setDialogState(() {
                      final next = !isAllSelected;
                      deleteProgress = next;
                      deleteRevisions = next;
                      deleteNodes = next;
                    });
                  },
                  child: Text(
                    isAllSelected ? '取消全选' : '全部删除',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDeleteCheckItem(
                      title: '加减与跳过记录',
                      subtitle: '清空所有打卡、跳过记录、备注与属性累计数值',
                      checked: deleteProgress,
                      locked: deleteNodes,
                      danger: false,
                      onTap: () {
                        if (deleteNodes) return;
                        setDialogState(
                            () => deleteProgress = !deleteProgress);
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildDeleteCheckItem(
                      title: '版本修订记录',
                      subtitle: '清空节点标题与内容修订历史，版本号重置为 v1',
                      checked: deleteRevisions,
                      locked: deleteNodes,
                      danger: false,
                      onTap: () {
                        if (deleteNodes) return;
                        setDialogState(
                            () => deleteRevisions = !deleteRevisions);
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildDeleteCheckItem(
                      title: '国策节点与连线',
                      subtitle: '删除全部国策、提示节点、连线及大框（同时清空关联记录）',
                      checked: deleteNodes,
                      locked: false,
                      danger: true,
                      onTap: () {
                        setDialogState(() {
                          deleteNodes = !deleteNodes;
                          if (deleteNodes) {
                            deleteProgress = true;
                            deleteRevisions = true;
                          }
                        });
                      },
                    ),
                  ],
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
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.black12,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: !hasAnySelected
                    ? null
                    : () async {
                        await engine.clearDataBySelection(
                          deleteNodes: deleteNodes,
                          deleteRevisions: deleteRevisions,
                          deleteProgress: deleteProgress,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('已按所选范围删除数据'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                child: const Text('确认删除'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDeleteCheckItem({
    required String title,
    required String subtitle,
    required bool checked,
    required bool locked,
    required bool danger,
    required VoidCallback onTap,
  }) {
    final activeColor = danger ? Colors.redAccent : AppTheme.primaryBlue;

    return InkWell(
      onTap: locked ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Opacity(
        opacity: locked ? 0.7 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: checked
                ? (danger ? const Color(0xFFFEF2F2) : AppTheme.subtleFill)
                : AppTheme.bgCanvas,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: checked ? activeColor : AppTheme.borderLight,
              width: checked ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                checked
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 19,
                color: checked ? activeColor : Colors.black38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: checked ? activeColor : AppTheme.deepNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offset = engine.dayStartHourOffset;
    final offsetDesc = offset == 0
        ? '不延后 (00:00 开启新一天)'
        : '延后 $offset 小时 (凌晨 0$offset:00 前算作前一天)';
    final cfg = engine.scoreConfig;
    final displayModeLabel = switch (engine.displayMode) {
      1 => '直接显示加减次数',
      2 => '连续次数显示',
      _ => '习惯连续性分数',
    };

    final webdavSubtitle = !engine.isWebDavConfigured
        ? '未配置服务器 · 支持同步全部数据与设置参数'
        : (engine.webdavLastSyncTime != null
            ? '已配置 · 上次同步 ${engine.webdavLastSyncTime}'
            : '已配置 · 尚未执行同步');

    return ListView(
      padding: const EdgeInsets.only(top: 0, bottom: 24),
      children: [
        Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceWhite,
            border: Border(
              bottom: BorderSide(color: AppTheme.borderLight),
            ),
          ),
          child: Column(
            children: [
              // 1. WebDAV 云同步
              ListTile(
                title: const Text(
                  'WebDAV 云同步',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.deepNavy),
                ),
                subtitle: Text(
                  webdavSubtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black26),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => WebDavSyncScreen(engine: engine),
                    ),
                  );
                },
              ),
              const Divider(height: 1, thickness: 0.8, color: AppTheme.borderLight),

              // 2. 显示方式（分数 / 加减次数）
              ListTile(
                title: const Text(
                  '显示方式',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.deepNavy),
                ),
                subtitle: Text(
                  displayModeLabel,
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black26),
                onTap: () => _showDisplayModeDialog(context),
              ),
              const Divider(height: 1, thickness: 0.8, color: AppTheme.borderLight),

              // 3. 延后新一天
              ListTile(
                title: const Text(
                  '延后新一天',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.deepNavy),
                ),
                subtitle: Text(
                  offsetDesc,
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black26),
                onTap: () => _showDayOffsetDialog(context),
              ),
              const Divider(height: 1, thickness: 0.8, color: AppTheme.borderLight),

              // 4. 前一天未完成自动标记为减开关
              SwitchListTile(
                title: const Text(
                  '未完成自动标记为减',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.deepNavy),
                ),
                subtitle: const Text(
                  '前一天未完成增减或跳过，且未归档的节点自动记为减',
                  style: TextStyle(fontSize: 12, color: Colors.black45),
                ),
                value: engine.autoPenalizeMissedYesterday,
                activeColor: AppTheme.primaryBlue,
                onChanged: (val) => engine.setAutoPenalizeMissedYesterday(val),
              ),
              const Divider(height: 1, thickness: 0.8, color: AppTheme.borderLight),

              // 5. 习惯连续性打分算法参数配置
              ListTile(
                title: const Text(
                  '计分算法参数设置',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.deepNavy),
                ),
                subtitle: Text(
                  '窗口 W=${cfg.windowSize}天 · 饱和尺度 τ=${cfg.tau.toStringAsFixed(0)} · 权重 ${(cfg.weightR * 100).toInt()}:${(cfg.weightH * 100).toInt()}',
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black26),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => ScoreConfigScreen(engine: engine),
                    ),
                  );
                },
              ),
              const Divider(height: 1, thickness: 0.8, color: AppTheme.borderLight),

              // 6. 版本历史
              ListTile(
                title: const Text(
                  '版本历史',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.deepNavy),
                ),
                subtitle: const Text(
                  '查看更新日志与版本修订履历',
                  style: TextStyle(fontSize: 12, color: Colors.black45),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCanvas,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Text(
                        'v${VersionHistoryConfig.currentVersion}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.deepNavy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, color: Colors.black26),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => const VersionHistoryScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1, thickness: 0.8, color: AppTheme.borderLight),

              // 7. 最底部：删除数据
              ListTile(
                title: const Text(
                  '删除数据',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.redAccent),
                ),
                subtitle: const Text(
                  '支持多选删除节点、版本修订记录或加减数据',
                  style: TextStyle(fontSize: 12, color: Colors.black45),
                ),
                trailing: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                onTap: () => _confirmClearData(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// WebDAV 云同步配置与双向同步页面
class WebDavSyncScreen extends StatefulWidget {
  final RsipEngine engine;

  const WebDavSyncScreen({super.key, required this.engine});

  @override
  State<WebDavSyncScreen> createState() => _WebDavSyncScreenState();
}

class _WebDavSyncScreenState extends State<WebDavSyncScreen> {
  late final TextEditingController _urlController;
  late final TextEditingController _userController;
  late final TextEditingController _passController;

  bool _obscurePassword = true;
  bool _isTesting = false;
  bool _isSyncing = false;
  ({bool success, String message})? _testResult;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.engine.webdavUrl);
    _userController = TextEditingController(text: widget.engine.webdavUsername);
    _passController = TextEditingController(text: widget.engine.webdavPassword);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _handleTestConnection() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final result = await widget.engine.testWebDavConnection(
      url: _urlController.text,
      username: _userController.text,
      password: _passController.text,
    );

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _testResult = result;
    });
  }

  Future<void> _handleSaveConfig() async {
    FocusScope.of(context).unfocus();
    await widget.engine.saveWebDavConfig(
      url: _urlController.text,
      username: _userController.text,
      password: _passController.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('WebDAV 服务器配置已保存'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleUpload() async {
    FocusScope.of(context).unfocus();
    await widget.engine.saveWebDavConfig(
      url: _urlController.text,
      username: _userController.text,
      password: _passController.text,
    );

    setState(() => _isSyncing = true);
    final res = await widget.engine.uploadToWebDav();
    if (!mounted) return;
    setState(() => _isSyncing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor: res.success ? Colors.green.shade700 : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleDownload() async {
    FocusScope.of(context).unfocus();
    await widget.engine.saveWebDavConfig(
      url: _urlController.text,
      username: _userController.text,
      password: _passController.text,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          '确认从云端拉取覆盖？',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.deepNavy,
          ),
        ),
        content: const Text(
          '拉取后将使用云端备份完整替换本地的国策节点、画布连线、历史记录以及全部设置参数。',
          style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: Colors.black45)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认覆盖恢复'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSyncing = true);
    final res = await widget.engine.downloadFromWebDav();
    if (!mounted) return;
    setState(() => _isSyncing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor: res.success ? Colors.green.shade700 : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.engine,
      builder: (context, _) {
        final lastSync = widget.engine.webdavLastSyncTime;
        final busy = _isTesting || _isSyncing;

        return Scaffold(
          backgroundColor: AppTheme.bgCanvas,
          appBar: AppBar(
            backgroundColor: AppTheme.surfaceWhite,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: const Text(
              'WebDAV 云同步',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.deepNavy,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.only(top: 0, bottom: 32),
            children: [
              // 1. 服务器凭据配置区
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  border: Border(
                    bottom: BorderSide(color: AppTheme.borderLight),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '服务器配置',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.deepNavy,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _urlController,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: 'WebDAV 服务器目录地址',
                        hintText: 'https://dav.jianguoyun.com/dav/RSIP/',
                        labelStyle: const TextStyle(fontSize: 13),
                        hintStyle: const TextStyle(fontSize: 12, color: Colors.black26),
                        filled: true,
                        fillColor: AppTheme.bgCanvas,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _userController,
                      decoration: InputDecoration(
                        labelText: '账号 / 用户名',
                        hintText: '输入 WebDAV 登录账号',
                        labelStyle: const TextStyle(fontSize: 13),
                        hintStyle: const TextStyle(fontSize: 12, color: Colors.black26),
                        filled: true,
                        fillColor: AppTheme.bgCanvas,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: '密码 / 应用专用密码',
                        hintText: '输入应用密码',
                        labelStyle: const TextStyle(fontSize: 13),
                        hintStyle: const TextStyle(fontSize: 12, color: Colors.black26),
                        filled: true,
                        fillColor: AppTheme.bgCanvas,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                            color: Colors.black45,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 测试连通性与保存配置双按钮
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryBlue,
                              side: const BorderSide(color: AppTheme.primaryBlue),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: busy ? null : _handleTestConnection,
                            icon: _isTesting
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  )
                                : const Icon(Icons.wifi_tethering_rounded, size: 17),
                            label: Text(
                              _isTesting ? '测试中...' : '测试连通性',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: busy ? null : _handleSaveConfig,
                            icon: const Icon(Icons.save_outlined, size: 17),
                            label: const Text(
                              '保存配置',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 连通性测试结果内联反馈条
                    if (_testResult != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: _testResult!.success
                              ? const Color(0xFFF2FBF4)
                              : const Color(0xFFFDF3F3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _testResult!.success
                                ? Colors.green.shade300
                                : Colors.red.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _testResult!.success
                                  ? Icons.check_circle_rounded
                                  : Icons.error_outline_rounded,
                              size: 16,
                              color: _testResult!.success
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _testResult!.message,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _testResult!.success
                                      ? Colors.green.shade800
                                      : Colors.red.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 2. 全量数据与设置参数同步操作区
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  border: Border(
                    top: BorderSide(color: AppTheme.borderLight, width: 0.8),
                    bottom: BorderSide(color: AppTheme.borderLight),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '全量同步操作',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.deepNavy,
                          ),
                        ),
                        if (lastSync != null)
                          Text(
                            '上次同步: $lastSync',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black45,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCanvas,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '同步范围：全部国策节点、树画布布局与连线、大节点分组、全部历史记录，以及显示方式、延后时间、自动扣减开关与计分算法参数（云端文件：rsip_backup.json）。',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.deepNavy,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: busy ? null : _handleUpload,
                            icon: _isSyncing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.cloud_upload_outlined, size: 18),
                            label: const Text(
                              '上传至云端',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.deepNavy,
                              side: const BorderSide(color: AppTheme.borderLight, width: 1.4),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: busy ? null : _handleDownload,
                            icon: const Icon(Icons.cloud_download_outlined, size: 18),
                            label: const Text(
                              '从云端拉取',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 计分算法参数调优独立配置页面
class ScoreConfigScreen extends StatefulWidget {
  final RsipEngine engine;

  const ScoreConfigScreen({super.key, required this.engine});

  @override
  State<ScoreConfigScreen> createState() => _ScoreConfigScreenState();
}

class _ScoreConfigScreenState extends State<ScoreConfigScreen> {
  late HabitScoreConfig _cfg;

  @override
  void initState() {
    super.initState();
    _cfg = widget.engine.scoreConfig.copy();
  }

  void _save() {
    widget.engine.updateScoreConfig(_cfg.copy());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          '计分算法参数设置',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.deepNavy),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _cfg = HabitScoreConfig());
              widget.engine.resetScoreConfigToDefault();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已恢复默认推荐参数'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text(
              '恢复默认',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 0, bottom: 32),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF0F7FF),
            child: const Text(
              '总分 S = 100 × (w_R · R + w_H · H)  ∈ [0, 100]\n'
              '• 短期连续势能 R = 1 - exp(-E / τ)\n'
              '• 长期结构质量 H = Σ(len_k ^ p) / (N_W + K) ^ p\n'
              '• 动态断签保留率 γ = max(γ_min, γ_base - k_drop · c_prev)',
              style: TextStyle(
                fontSize: 11.5,
                color: AppTheme.deepNavy,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderLight),
          _buildParamCard(
            title: '滑动窗口 (W)',
            valueText: '${_cfg.windowSize} 天 (默认 90)',
            description:
                '【含义】统计历史结构质量 H 的时间视野。\n'
                '• 数值调小（如 30）：仅评估近期表现，历史包袱轻，适合轻量短期习惯；\n'
                '• 数值调大（如 90~180）：拉长考察周期，更看重长期的稳定坚持，适合健身、早起等核心习惯。',
            slider: Slider(
              value: _cfg.windowSize.toDouble(),
              min: 14,
              max: 180,
              divisions: 166,
              activeColor: AppTheme.primaryBlue,
              onChanged: (v) {
                setState(() => _cfg.windowSize = v.round());
                _save();
              },
            ),
          ),
          _buildParamCard(
            title: '连续饱和尺度 (τ)',
            valueText: '${_cfg.tau.toStringAsFixed(1)} (默认 14.0)',
            description:
                '【含义】控制当前连续势能 R 的爬坡速度（E = τ 时 R ≈ 63%，E = 3τ 时 R ≈ 95%）。\n'
                '• 数值调小（如 7.0）：连续打卡几天即可迅速让短期势能接近满分，即时正反馈强；\n'
                '• 数值调大（如 21.0~30.0）：爬坡更平缓，需要更长周期的连续打卡才能积累满额势能。',
            slider: Slider(
              value: _cfg.tau,
              min: 5.0,
              max: 45.0,
              divisions: 80,
              activeColor: AppTheme.primaryBlue,
              onChanged: (v) {
                setState(() => _cfg.tau = v);
                _save();
              },
            ),
          ),
          _buildParamCard(
            title: '短期与长期权重比 (w_R : w_H)',
            valueText:
                '${_cfg.weightR.toStringAsFixed(2)} : ${_cfg.weightH.toStringAsFixed(2)} (默认 0.60 : 0.40)',
            description:
                '【含义】平衡“当下连续冲劲 (R)”与“长期自律底盘 (H)”在总分中的占比。\n'
                '• w_R 调大（如 0.70）：偏向短期刺激与唤醒，连续打卡涨分快，但断签时掉分也更明显；\n'
                '• w_R 调小（如 0.50）：偏向长期底盘沉淀，总分更稳定，不易因单次断签剧烈波动。',
            slider: Slider(
              value: _cfg.weightR,
              min: 0.20,
              max: 0.80,
              divisions: 60,
              activeColor: AppTheme.primaryBlue,
              onChanged: (v) {
                setState(() => _cfg.weightR = double.parse(v.toStringAsFixed(2)));
                _save();
              },
            ),
          ),
          _buildParamCard(
            title: '分段幂次 (p)',
            valueText: '${_cfg.powerP.toStringAsFixed(2)} (默认 1.50)',
            description:
                '【含义】对“三天打鱼两天晒网”碎片化打卡的打击烈度。\n'
                '• 数值调小（接近 1.0）：退化为普通完成率，断断续续打卡也能拿到不错的分数；\n'
                '• 数值调大（如 1.8~2.0）：极度强调“连续段越长越值钱”，频繁断签会导致历史质量分 H 大幅缩水。',
            slider: Slider(
              value: _cfg.powerP,
              min: 1.0,
              max: 2.2,
              divisions: 24,
              activeColor: AppTheme.primaryBlue,
              onChanged: (v) {
                setState(() => _cfg.powerP = double.parse(v.toStringAsFixed(2)));
                _save();
              },
            ),
          ),
          _buildParamCard(
            title: '冷启动常数 (K)',
            valueText: '${_cfg.coldStartK} 天 (默认 7)',
            description:
                '【含义】新国策前几天的分母垫高平滑系数。\n'
                '• 数值调小（如 0~2）：新建习惯第 1 天打卡就能直接冲到较高分数；\n'
                '• 数值调大（如 7~14）：有效压制首日打卡分数虚高，使分数伴随坚持天数呈现循序渐进的成长感。',
            slider: Slider(
              value: _cfg.coldStartK.toDouble(),
              min: 0,
              max: 21,
              divisions: 21,
              activeColor: AppTheme.primaryBlue,
              onChanged: (v) {
                setState(() => _cfg.coldStartK = v.round());
                _save();
              },
            ),
          ),
          _buildParamCard(
            title: '基础能量保留率 (γ_base)',
            valueText: '${_cfg.gammaBase.toStringAsFixed(2)} (默认 0.85)',
            description:
                '【含义】断签时的初始能量缓冲垫（新手保护度）。\n'
                '• 数值调大（如 0.85~0.90）：短连击偶尔断签 1 天时掉分温和，宽容度高；\n'
                '• 数值调小（如 0.65~0.75）：哪怕刚起步断签也会直接损失较多能量，惩罚更严厉。',
            slider: Slider(
              value: _cfg.gammaBase,
              min: 0.50,
              max: 0.95,
              divisions: 45,
              activeColor: AppTheme.primaryBlue,
              onChanged: (v) {
                setState(() {
                  _cfg.gammaBase = double.parse(v.toStringAsFixed(2));
                  if (_cfg.gammaMin > _cfg.gammaBase) {
                    _cfg.gammaMin = _cfg.gammaBase;
                  }
                });
                _save();
              },
            ),
          ),
          _buildParamCard(
            title: '连击断签惩罚斜率 (k_drop)',
            valueText: '${_cfg.kDrop.toStringAsFixed(3)} (默认 0.005)',
            description:
                '【含义】强化断签惩罚系数：每连续坚持 1 天，断签时的能量保留率额外降低 k_drop（连击越长，断开越痛）。\n'
                '• 设为 0.000：关闭动态加罚，所有连击天数断签均按固定 γ_base 衰减；\n'
                '• 数值调大（如 0.005~0.015）：高连击断签时将产生强烈的沉没成本痛感。',
            slider: Slider(
              value: _cfg.kDrop,
              min: 0.000,
              max: 0.020,
              divisions: 40,
              activeColor: AppTheme.primaryBlue,
              onChanged: (v) {
                setState(() => _cfg.kDrop = double.parse(v.toStringAsFixed(3)));
                _save();
              },
            ),
          ),
          _buildParamCard(
            title: '断签保留率下限 (γ_min)',
            valueText: '${_cfg.gammaMin.toStringAsFixed(2)} (默认 0.35)',
            description:
                '【含义】超长连击（如 90 天以上）断签时的能量保底比例。\n'
                '• 数值调大（如 0.50）：长连击断签后最多损失一半能量，容易快速重振旗鼓；\n'
                '• 数值调小（如 0.25~0.35）：触底时瞬间抹除 65%~75% 能量，分数出现断崖式下挫的强烈警示。',
            slider: Slider(
              value: _cfg.gammaMin.clamp(0.10, _cfg.gammaBase),
              min: 0.10,
              max: _cfg.gammaBase,
              divisions: ((_cfg.gammaBase - 0.10) * 100).round().clamp(1, 100),
              activeColor: AppTheme.primaryBlue,
              onChanged: (v) {
                setState(() => _cfg.gammaMin = double.parse(v.toStringAsFixed(2)));
                _save();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParamCard({
    required String title,
    required String valueText,
    required String description,
    required Widget slider,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceWhite,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderLight, width: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.deepNavy,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.subtleFill,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  valueText,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              fontSize: 11.5,
              color: Colors.black54,
              height: 1.45,
            ),
          ),
          slider,
        ],
      ),
    );
  }
}