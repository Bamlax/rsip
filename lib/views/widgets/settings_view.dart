import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/version_history.dart';
import '../../engine/rsip_engine.dart';
import '../../models/focus_node_model.dart';
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          '确认删除历史填充数据？',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.deepNavy),
        ),
        content: const Text(
          '将清空所有历史打卡记录、备注与属性累计数值，各节点得分将重新开始计算（应用版本号与国策版本号将完整保留）。',
          style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
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
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('确认删除'),
            onPressed: () async {
              await engine.clearAllHistoryData();
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已清空全部历史填充数据（版本号已保留）'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
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
              // 1. 延后新一天
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

              // 2. 习惯连续性打分算法参数配置
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

              // 3. 版本历史
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
              const Divider(height: 1, thickness: 0.8, color: AppTheme.borderLight),

              // 4. 最底部：删除数据（清空历史填充数据，保留版本号）
              ListTile(
                title: const Text(
                  '删除数据',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.redAccent),
                ),
                subtitle: const Text(
                  '清空全部历史填充记录与统计数据（保留版本号）',
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
          // 顶部公式概览横幅
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

          // 1. 滑动窗口 W
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

          // 2. 连续饱和尺度 τ
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

          // 3. 权重分配 w_R : w_H
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

          // 4. 分段幂次 p
          _buildParamCard(
            title: '分段幂次 (p)',
            valueText: '${_cfg.powerP.toStringAsFixed(2)} (默认 1.50)',
            description:
                '【含义】对“三天打鱼两天晒网”碎片化打卡的打击烈度。\n'
                '• 数值调小（接近 1.0）：退化为普通完成率，断断续续打卡也能拿到不错的分数；\n'
                '• 数值调大（如 1.8~2.0）：极度强调“连续段越长越值钱”，频繁断签会导致历史质量分 H 大幅缩水（推荐 1.4~1.6 兼顾区分度与抗挫力）。',
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

          // 5. 冷启动常数 K
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

          // 6. 基础能量保留率 γ_base
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

          // 7. 连击衰减斜率 k_drop
          _buildParamCard(
            title: '连击断签惩罚斜率 (k_drop)',
            valueText: '${_cfg.kDrop.toStringAsFixed(3)} (默认 0.005)',
            description:
                '【含义】强化断签惩罚系数：每连续坚持 1 天，断签时的能量保留率额外降低 k_drop（连击越长，断开越痛）。\n'
                '• 设为 0.000：关闭动态加罚，所有连击天数断签均按固定 γ_base 衰减；\n'
                '• 数值调大（如 0.005~0.015）：高连击断签时将产生强烈的沉没成本痛感，促使全力维持长连击。',
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

          // 8. 保留率下限 γ_min
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