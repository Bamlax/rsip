import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/version_history.dart';
import '../../engine/rsip_engine.dart';
import 'version_history_screen.dart';

class SettingsView extends StatelessWidget {
  final RsipEngine engine;

  const SettingsView({super.key, required this.engine});

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
                // 简洁的增加/减少小时控件
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

  @override
  Widget build(BuildContext context) {
    final offset = engine.dayStartHourOffset;
    final offsetDesc = offset == 0
        ? '不延后 (00:00 开启新一天)'
        : '延后 $offset 小时 (凌晨 0$offset:00 前算作前一天)';

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
                      child: const Text(
                        'v${VersionHistoryConfig.currentVersion}',
                        style: TextStyle(
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
            ],
          ),
        ),
      ],
    );
  }
}