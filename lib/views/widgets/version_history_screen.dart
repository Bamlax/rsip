import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/version_history.dart';

class VersionHistoryScreen extends StatelessWidget {
  const VersionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          '版本历史',
          style: TextStyle(
            color: AppTheme.deepNavy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        // 与 AppBar 零间距，贴合屏幕左右
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
                for (int i = 0; i < VersionHistoryConfig.releases.length; i++) ...[
                  if (i > 0) const Divider(height: 1, thickness: 0.8, color: AppTheme.borderLight),
                  _buildReleaseItem(VersionHistoryConfig.releases[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReleaseItem(VersionRelease release) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部：版本徽章与发布日期
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.subtleFill,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'v${release.version}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
              Text(
                release.releaseDate,
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 更新说明点列
          ...release.changeLogs.map(
            (log) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      log,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}