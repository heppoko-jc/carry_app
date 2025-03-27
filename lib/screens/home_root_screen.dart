import 'package:carry_app/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health/health.dart';

import '../services/health_service.dart';
import '../services/game_service.dart';
import '../services/sleep_data_service.dart';
import '../services/game_data_service.dart';
import '../services/normal_sync_service.dart';
import '../services/daily_report_service.dart';

import '../screens/daily_report_screen.dart';
import '../screens/main_screen.dart';
import '../screens/weekly_screen.dart';

class HomeRootScreen extends StatefulWidget {
  /// 初期設定直後に渡される睡眠データ
  final List<HealthDataPoint>? initSleepData;

  /// 初期設定直後に渡されるマッチデータ
  final List<Map<String, dynamic>>? initMatches;

  const HomeRootScreen({super.key, this.initSleepData, this.initMatches});

  @override
  State<HomeRootScreen> createState() => _HomeRootScreenState();
}

class _HomeRootScreenState extends State<HomeRootScreen> {
  // BottomNavigationBarのインデックス（0: メイン, 1: 週画面, 2: 設定）
  int _currentIndex = 0;

  // 同期＆データ取得中のプログレス表示用
  bool _isLoading = false;

  // データ
  List<HealthDataPoint> _sleepData = [];
  List<Map<String, dynamic>> _recentMatches = [];
  List<Map<String, dynamic>> _dailyReports = [];

  String? _puuid;

  // サービス
  final HealthService _healthService = HealthService();
  final GameService _gameService = GameService();
  final SleepDataService _sleepDataService = SleepDataService();
  final GameDataService _gameDataService = GameDataService();
  final DailyReportService _dailyReportService = DailyReportService();

  // NormalSyncService は増分同期用
  late final NormalSyncService _normalSync;

  // 前日～7日前の日付リスト
  late final List<DateTime> _dates;

  @override
  void initState() {
    super.initState();

    // NormalSyncService を初期化
    _normalSync = NormalSyncService(
      healthService: _healthService,
      gameService: _gameService,
      sleepDataService: _sleepDataService,
      gameDataService: _gameDataService,
    );

    if (widget.initSleepData != null) {
      _sleepData = widget.initSleepData!;
    }
    if (widget.initMatches != null) {
      _recentMatches = widget.initMatches!;
    }

    // 日付リストを作成 (前日〜7日前)
    _setupDates();

    // デバッグ用最終同期日調整
    // _debugResetLastSyncedTime();

    // 同期 -> データ取得
    _syncIncremental();
  }

  //デバッグ用最終同期日調整
  // Future<void> _debugResetLastSyncedTime() async {
  //  final prefs = await SharedPreferences.getInstance();
  //  final debugDate = DateTime.now().subtract(const Duration(days: 2));
  //  await prefs.setInt('lastSyncedTime', debugDate.millisecondsSinceEpoch);
  //  print("【DEBUG】lastSyncedTimeを $debugDate に設定");
  // }

  // 増分同期
  Future<void> _syncIncremental() async {
    setState(() => _isLoading = true);
    try {
      // 同期（送信）
      await _normalSync.syncIncremental();
      // 同期後再取得
      await _fetchAllData();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 前日～7日前のリストを作る
  void _setupDates() {
    final now = DateTime.now();
    final end = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1)); // 前日

    _dates = [];
    for (int i = 0; i < 7; i++) {
      _dates.add(end.subtract(Duration(days: i)));
    }
  }

  // データ取得(睡眠、マッチ、日報)
  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _puuid = prefs.getString('riot_puuid') ?? _puuid;

      // 1) 睡眠
      final authorized = await _healthService.requestPermissions();
      if (authorized) {
        final newSleepData = await _healthService.fetchSleepData();
        _sleepData = newSleepData;
      } else {
        _sleepData = [];
      }

      // 2) マッチ
      if (_puuid != null && _puuid!.isNotEmpty) {
        final newMatches = await _gameService.getRecentMatches(_puuid!);
        _recentMatches = newMatches;
      } else {
        _recentMatches = [];
      }

      // 3) 日報
      _dailyReports = await _dailyReportService.fetchDailyReports();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 日報送信後際読み込み
  Future<void> _fetchDailyReportsOnly() async {
    setState(() => _isLoading = true);
    try {
      _dailyReports = await _dailyReportService.fetchDailyReports();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 日報画面再取得の判別処理
  Future<void> _navigateDailyReport() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DailyReportScreen()),
    );
    if (result == true) {
      // 日報送信成功 => 日報だけ再取得
      await _fetchDailyReportsOnly();
    }
  }

  // ボトムナビで画面切り替え
  void _onTapNav(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      MainScreen(
        sleepData: _sleepData,
        recentMatches: _recentMatches,
        dailyReports: _dailyReports,
        onTapDailyReport: _navigateDailyReport,
        dateList: _dates,
      ),

      WeeklyScreen(
        sleepData: _sleepData,
        recentMatches: _recentMatches,
        dailyReports: _dailyReports,
        dateList: _dates,
      ),
      const SettingsScreen(),
    ];

    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : screens[_currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTapNav,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "メイン"),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: "ウィークリー",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "設定"),
        ],
      ),
      floatingActionButton:
          _currentIndex == 0
              ? FloatingActionButton(
                onPressed: _navigateDailyReport,
                child: const Icon(Icons.edit),
              )
              : null,
    );
  }
}
