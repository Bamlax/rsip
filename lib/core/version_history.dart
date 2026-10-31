import 'package:package_info_plus/package_info_plus.dart';

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

/// 版本历史集中数据
class VersionHistoryConfig {
  // 默认以 releases 最前面的一条最新版本兜底
  static String _currentVersion = releases.first.version;

  /// 获取当前版本号（自动读取 pubspec.yaml 中的 version）
  static String get currentVersion => _currentVersion;

  /// 在 main.dart 启动时调用，自动从原生平台读取 pubspec.yaml 的版本信息
  static Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) {
        _currentVersion = info.version;
      }
    } catch (_) {
      // 平台通道不可用时，安全回退至最新的发版记录
      _currentVersion = releases.first.version;
    }
  }

  static const List<VersionRelease> releases = [
      VersionRelease(
      version: '0.6.0',
      releaseDate: '2026-10-31',
      changeLogs: [
        '新增：分数功能',
        '新增：重置数据功能',
        '新增：统计界面',
        '优化：当日负面打卡也自动隐藏',
        '修复：设置界面版本号错误显示的bug',
      ],
    ),
    VersionRelease(
      version: '0.5.0',
      releaseDate: '2026-10-17',
      changeLogs: [
        '新增：自定义重复日期功能',
        '新增：列表节点自动隐藏功能以及树的半透明显示',
      ],
    ),
    VersionRelease(
      version: '0.4.0',
      releaseDate: '2026-10-12',
      changeLogs: [
        '新增：编辑功能',
        '新增：延后当日功能',
        '新增：颜色深度增加变深',
        '新增：标签功能',
        '优化：备注内容不在首页显示',
      ],
    ),
    VersionRelease(
      version: '0.3.0',
      releaseDate: '2026-10-11',
      changeLogs: [
        '新增：自由排序节点',
        '优化：记录的时间选择方式',
        '优化：历史界面UI',
      ],
    ),
    VersionRelease(
      version: '0.2.0',
      releaseDate: '2026-10-08',
      changeLogs: [
        '新增：大节点的连线功能',
        '新增：节点备注的自定义弹出',
        '优化：新建节点的位置',
      ],
    ),
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