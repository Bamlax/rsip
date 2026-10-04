import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/version_history.dart';
import '../../engine/rsip_engine.dart';
import 'version_history_screen.dart';

class SettingsView extends StatelessWidget {
  final RsipEngine engine;

  const SettingsView({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 0, bottom: 24),
      children: [
        // 1. 打卡交互设置
        Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceWhite,
            border: Border(
              bottom: BorderSide(color: AppTheme.borderLight),
            ),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text(
                  '增加进度时弹出心得备注',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.deepNavy),
                ),
                subtitle: const Text(
                  '点击顶栏「+」打卡时弹出心得录入对话框',
                  style: TextStyle(fontSize: 12, color: Colors.black45),
                ),
                activeColor: AppTheme.primaryBlue,
                value: engine.promptNoteOnIncrease,
                onChanged: (val) => engine.setPromptNoteOnIncrease(val),
              ),
              const Divider(height: 1, thickness: 0.8, color: AppTheme.borderLight),
              SwitchListTile(
                title: const Text(
                  '减少进度时弹出反思备注',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.deepNavy),
                ),
                subtitle: const Text(
                  '点击顶栏「-」扣除时弹出反思录入对话框',
                  style: TextStyle(fontSize: 12, color: Colors.black45),
                ),
                activeColor: AppTheme.primaryBlue,
                value: engine.promptNoteOnDecrease,
                onChanged: (val) => engine.setPromptNoteOnDecrease(val),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 2. 关于与版本历史（跳转独立新界面）
        Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceWhite,
            border: Border(
              top: BorderSide(color: AppTheme.borderLight),
              bottom: BorderSide(color: AppTheme.borderLight),
            ),
          ),
          child: Column(
            children: [
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