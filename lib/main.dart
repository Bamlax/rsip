import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'core/version_history.dart';
import 'engine/rsip_engine.dart';
import 'views/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await VersionHistoryConfig.init();
  runApp(const RsipApp());
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class RsipApp extends StatefulWidget {
  const RsipApp({super.key});

  @override
  State<RsipApp> createState() => _RsipAppState();
}

class _RsipAppState extends State<RsipApp> {
  late final RsipEngine _engine;

  @override
  void initState() {
    super.initState();
    _engine = RsipEngine();
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RSIP 稳态协议',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      scrollBehavior: _AppScrollBehavior(),
      home: MainScreen(engine: _engine),
    );
  }
}