// main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/init_setup_screen.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: AppRouter());
  }
}

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  _AppRouterState createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  bool? _isSetupComplete;

  @override
  void initState() {
    super.initState();
    _checkSetupComplete();
  }

  Future<void> _checkSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    // isSetupComplete が存在しなければ false
    final done = prefs.getBool('isSetupComplete') ?? false;

    setState(() {
      _isSetupComplete = done;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isSetupComplete == null) {
      // ローディング中
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 初回起動でセットアップが完了していなければ InitSetupScreen に遷移
    if (!_isSetupComplete!) {
      return const InitSetupScreen();
    } else {
      // 2回目以降 → メイン画面へ
      return MainScreen(sleepData: const [], recentMatches: const []);
    }
  }
}
