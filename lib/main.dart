import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'engine/rsip_engine.dart';
import 'views/main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RsipApp());
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
      home: MainScreen(engine: _engine),
    );
  }
}