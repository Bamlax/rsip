import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/progress_color_helper.dart';
import '../../engine/rsip_engine.dart';
import '../../models/focus_node_model.dart';

class StatisticsView extends StatefulWidget {
  final RsipEngine engine;

  const StatisticsView({super.key, required this.engine});

  @override
  State<StatisticsView> createState() => _StatisticsViewState();
}

class _StatisticsViewState extends State<StatisticsView> {
  DateTime? _selectedHeatmapDate;
  int _selectedHeatmapCount = 0;

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.engine,
      builder: (context, _) {
        final normalNodes = widget.engine.nodes.where((n) => !n.isPrompt).toList();
        final rawRecords = widget.engine.history.where((r) => !r.isEdit && r.delta != 0).toList();

        final today = widget.engine.getEffectiveDate(DateTime.now());

        // 1. 统计打卡总量与正负比例
        final totalCount = rawRecords.length;
        final posCount = rawRecords.where((r) => r.delta > 0).length;
        final negCount = rawRecords.where((r) => r.delta < 0).length;
        final winRate = totalCount > 0 ? (posCount / totalCount * 100.0) : 0.0;

        // 2. 活跃天数与连续打卡
        final Set<DateTime> activeDays = {};
        final Map<DateTime, int> dailyRecordCount = {};
        for (final r in rawRecords) {
          final d = widget.engine.getEffectiveDate(r.time);
          activeDays.add(d);
          dailyRecordCount[d] = (dailyRecordCount[d] ?? 0) + 1;
        }

        // 计算当前全局连续打卡天数
        int currentStreak = 0;
        DateTime checkDay = today;
        if (!dailyRecordCount.containsKey(checkDay)) {
          checkDay = checkDay.subtract(const Duration(days: 1));
        }
        while (dailyRecordCount.containsKey(checkDay)) {
          currentStreak++;
          checkDay = checkDay.subtract(const Duration(days: 1));
        }

        // 3. 全局平均健康得分
        double avgScore = 0.0;
        if (normalNodes.isNotEmpty) {
          final totalScore = normalNodes.fold<double>(
            0.0,
            (sum, n) => sum + widget.engine.getNodeScore(n.id).score,
          );
          avgScore = totalScore / normalNodes.length;
        }

        // 4. 标签归因聚合统计
        final Map<String, int> posTagCounts = {};
        final Map<String, int> negTagCounts = {};
        for (final r in rawRecords) {
          if (r.tags == null || r.tags!.isEmpty) continue;
          for (final tag in r.tags!) {
            if (r.delta > 0) {
              posTagCounts[tag] = (posTagCounts[tag] ?? 0) + 1;
            } else {
              negTagCounts[tag] = (negTagCounts[tag] ?? 0) + 1;
            }
          }
        }

        final sortedPosTags = posTagCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final sortedNegTags = negTagCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        // 5. 国策排行榜（得分由高到低与关注榜）
        final scoredNodes = normalNodes.map((n) {
          return MapEntry(n, widget.engine.getNodeScore(n.id));
        }).toList()
          ..sort((a, b) => b.value.score.compareTo(a.value.score));

        return ListView(
          padding: const EdgeInsets.only(top: 0, bottom: 32),
          children: [
            // 模块一：宏观核心大盘看板
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceWhite,
                border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '自律效能大盘',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.deepNavy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildMetricTile(
                        label: '习惯健康均分',
                        value: '${avgScore.toStringAsFixed(1)} 分',
                        valColor: ProgressColorHelper.getScoreColor(avgScore),
                        subLabel: '共 ${normalNodes.length} 项国策',
                      ),
                      const SizedBox(width: 8),
                      _buildMetricTile(
                        label: '打卡胜率',
                        value: '${winRate.toStringAsFixed(0)}%',
                        valColor: winRate >= 70
                            ? Colors.green.shade700
                            : (winRate >= 50 ? AppTheme.primaryBlue : Colors.orange.shade800),
                        subLabel: '+$posCount / -$negCount',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildMetricTile(
                        label: '当前连续活跃',
                        value: '$currentStreak 天',
                        valColor: AppTheme.primaryBlue,
                        subLabel: '全局自律节奏',
                      ),
                      const SizedBox(width: 8),
                      _buildMetricTile(
                        label: '累计记录天数',
                        value: '${activeDays.length} 天',
                        valColor: AppTheme.deepNavy,
                        subLabel: '共产生 $totalCount 次记录',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 模块二：15周打卡贡献热力图
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceWhite,
                border: Border(
                  top: BorderSide(color: AppTheme.borderLight, width: 0.8),
                  bottom: BorderSide(color: AppTheme.borderLight, width: 0.8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '打卡节奏热力图',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.deepNavy,
                          ),
                        ),
                        _buildHeatmapLegend(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildHeatmapGrid(today, dailyRecordCount),
                  if (_selectedHeatmapDate != null) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCanvas,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.primaryBlue),
                            const SizedBox(width: 6),
                            Text(
                              '${_formatDate(_selectedHeatmapDate!)}：共记录 $_selectedHeatmapCount 次',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.deepNavy),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 模块三：标签归因与诱因透视
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceWhite,
                border: Border(
                  top: BorderSide(color: AppTheme.borderLight, width: 0.8),
                  bottom: BorderSide(color: AppTheme.borderLight, width: 0.8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '归因分析（标签排行）',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.deepNavy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 正向标签 Top
                      Expanded(
                        child: _buildTagList(
                          title: '正向动力 Top',
                          tags: sortedPosTags.take(5).toList(),
                          isPositive: true,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // 负向标签 Top
                      Expanded(
                        child: _buildTagList(
                          title: '挫折诱因 Top',
                          tags: sortedNegTags.take(5).toList(),
                          isPositive: false,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 模块四：国策得分榜单
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceWhite,
                border: Border(
                  top: BorderSide(color: AppTheme.borderLight, width: 0.8),
                  bottom: BorderSide(color: AppTheme.borderLight, width: 0.8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '国策效能排行',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.deepNavy,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (scoredNodes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text('暂无国策健康度数据', style: TextStyle(fontSize: 12, color: Colors.black38)),
                      ),
                    )
                  else
                    ...List.generate(scoredNodes.length, (idx) {
                      final item = scoredNodes[idx];
                      final node = item.key;
                      final scoreRes = item.value;
                      final scoreColor = ProgressColorHelper.getScoreColor(scoreRes.score);
                      final scoreBg = ProgressColorHelper.getScoreBgColor(scoreRes.score);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCanvas,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: idx < 3
                                    ? AppTheme.primaryBlue.withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${idx + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: idx < 3 ? AppTheme.primaryBlue : Colors.black45,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    node.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.deepNavy,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '连续 ${scoreRes.streak} 天 · 势能 E=${scoreRes.energy.toStringAsFixed(1)}',
                                    style: const TextStyle(fontSize: 10, color: Colors.black45),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: scoreBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: scoreColor.withValues(alpha: 0.35),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '${scoreRes.score.toStringAsFixed(1)}分',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: scoreColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color valColor,
    required String subLabel,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.bgCanvas,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: valColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(subLabel, style: const TextStyle(fontSize: 10, color: Colors.black38)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmapLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('少 ', style: TextStyle(fontSize: 10, color: Colors.black38)),
        _buildLegendBox(const Color(0xFFF1F5F9)),
        const SizedBox(width: 3),
        _buildLegendBox(const Color(0xFFBBF7D0)),
        const SizedBox(width: 3),
        _buildLegendBox(const Color(0xFF4ADE80)),
        const SizedBox(width: 3),
        _buildLegendBox(const Color(0xFF16A34A)),
        const SizedBox(width: 3),
        _buildLegendBox(const Color(0xFF064E3B)),
        const Text(' 多', style: TextStyle(fontSize: 10, color: Colors.black38)),
      ],
    );
  }

  Widget _buildLegendBox(Color c) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeatmapGrid(DateTime today, Map<DateTime, int> dailyCounts) {
    const int numWeeks = 16;
    final int todayWeekday = today.weekday; // 1 (Mon) ~ 7 (Sun)
    // 往前推算 15 周前的周一
    final startMonday = today.subtract(Duration(days: (numWeeks - 1) * 7 + (todayWeekday - 1)));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true, // 默认滚动到最右侧的今日
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(numWeeks, (weekIndex) {
          final weekStart = startMonday.add(Duration(days: weekIndex * 7));
          return Column(
            children: List.generate(7, (dayIndex) {
              final cellDate = weekStart.add(Duration(days: dayIndex));
              final isFuture = cellDate.isAfter(today);
              final count = dailyCounts.entries
                  .where((e) => _isSameDay(e.key, cellDate))
                  .fold<int>(0, (sum, e) => sum + e.value);

              Color cellColor = const Color(0xFFF1F5F9);
              if (!isFuture) {
                if (count == 0) {
                  cellColor = const Color(0xFFF1F5F9);
                } else if (count == 1) {
                  cellColor = const Color(0xFFBBF7D0);
                } else if (count == 2) {
                  cellColor = const Color(0xFF4ADE80);
                } else if (count <= 4) {
                  cellColor = const Color(0xFF16A34A);
                } else {
                  cellColor = const Color(0xFF064E3B);
                }
              }

              final isSelected = _selectedHeatmapDate != null &&
                  _isSameDay(_selectedHeatmapDate!, cellDate);

              return GestureDetector(
                onTap: isFuture
                    ? null
                    : () {
                        setState(() {
                          _selectedHeatmapDate = cellDate;
                          _selectedHeatmapCount = count;
                        });
                      },
                child: Container(
                  width: 13,
                  height: 13,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isFuture ? Colors.transparent : cellColor,
                    borderRadius: BorderRadius.circular(3),
                    border: isSelected
                        ? Border.all(color: AppTheme.primaryBlue, width: 1.5)
                        : null,
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  Widget _buildTagList({
    required String title,
    required List<MapEntry<String, int>> tags,
    required bool isPositive,
  }) {
    final themeColor = isPositive ? Colors.green.shade700 : Colors.red.shade700;
    final bgLight = isPositive ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: themeColor,
            ),
          ),
          const SizedBox(height: 8),
          if (tags.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '暂无标签沉淀',
                style: TextStyle(fontSize: 11, color: Colors.black38),
              ),
            )
          else
            ...tags.map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '#${e.key}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.deepNavy,
                        ),
                      ),
                    ),
                    Text(
                      '${e.value}次',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: themeColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}