/// 版本发布记录模型
class VersionRelease {
  final String version;
  final String releaseDate;
  final List<String> changeLogs;

  const VersionRelease({
    required this.version,
    required this.releaseDate,
    required this.changeLogs,
  });
}

/// 版本历史集中数据（便于后续在此手动增删改）
class VersionHistoryConfig {
  static const String currentVersion = '0.1.0';

  static const List<VersionRelease> releases = [
    VersionRelease(
      version: '0.1.0',
      releaseDate: '2026-10-04',
      changeLogs: [
        '首个基础版本发布，确立无边界国策定式管理架构',
        '支持无限视口动态点阵画布、质心自适应居中与平滑缩放',
        '支持画布直觉框选国策生成大节点，并提供框内总进度聚合统计',
        '支持长按大节点整体协同位移与增量平滑拖动',
        '支持自定义数字属性（名称与单位），并在每次加减打卡中即时录入变动量',
        '全界面边缘无缝一体化设计，列表自动过滤提示块',
        '详情页支持版本修订对比（删除内容划红线，新增内容高亮对比）',
        '打卡流水支持单例互斥左滑撤回删除，版本修订记录锁定防滑',
      ],
    ),
  ];
}