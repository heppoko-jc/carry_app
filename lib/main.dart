import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/init_setup_screen.dart';
import 'screens/home_root_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AppRouter(),
    );
  }
}

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  bool? _isSetupComplete;

  @override
  void initState() {
    super.initState();
    _checkSetupComplete();
  }

  /// SharedPreferences から初期設定の完了フラグを読み込む
  Future<void> _checkSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('isSetupComplete') ?? false;
    setState(() {
      _isSetupComplete = done;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isSetupComplete == null) {
      // ロード中
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 初回起動: isSetupComplete == false → InitSetupScreen
    if (!_isSetupComplete!) {
      return const InitSetupScreen();
    }

    // 2回目以降: HomeRootScreen に遷移
    return const HomeRootScreen();
  }
}
