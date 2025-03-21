import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health/health.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/health_service.dart';
import '../services/game_service.dart';
import '../services/sleep_data_service.dart';
import '../services/game_data_service.dart';
import '../services/normal_sync_service.dart';
// 日報画面用
import '../screens/daily_report_screen.dart';

class MainScreen extends StatefulWidget {
  final List<HealthDataPoint>? sleepData; // 初回起動時データ
  final List<Map<String, dynamic>>? recentMatches; // 初回起動時データ

  final String? sessionKey;
  final String? riotPUUID;
  final String? riotGameName;
  final String? riotTagLine;

  const MainScreen({
    super.key,
    this.sleepData,
    this.recentMatches,
    this.sessionKey,
    this.riotPUUID,
    this.riotGameName,
    this.riotTagLine,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final HealthService _healthService = HealthService();
  final GameService _gameService = GameService();
  final SleepDataService _sleepDataService = SleepDataService();
  final GameDataService _gameDataService = GameDataService();

  // メイン画面が保持するデータ
  List<HealthDataPoint> _sleepData = [];
  List<Map<String, dynamic>> _recentMatches = [];

  String? _sessionKey;
  String? _puuid;

  bool _isLoading = false;

  // 日付切り替え (前日〜7日前)
  late List<DateTime> _dates;
  int _dayIndex = 0; // 0 => 前日, 6 => 7日前

  @override
  void initState() {
    super.initState();
    // (1) 初回起動時データをコピー
    if (widget.sleepData != null) {
      _sleepData = widget.sleepData!;
    }
    if (widget.recentMatches != null) {
      _recentMatches = widget.recentMatches!;
    }

    // sessionKey/puuid
    _sessionKey = widget.sessionKey;
    _puuid = widget.riotPUUID;

    // (2) 日付リスト
    _setupDates();

    // (3) 増分同期 -> UI更新
    _syncIncremental();
  }

  Future<void> _syncIncremental() async {
    setState(() => _isLoading = true);

    try {
      // NormalSyncServiceを生成
      final normalSync = NormalSyncService(
        healthService: _healthService,
        gameService: _gameService,
        sleepDataService: _sleepDataService,
        gameDataService: _gameDataService,
      );

      // 増分同期実行
      await normalSync.syncIncremental();

      // 増分同期後、UI用のデータ再取得
      await _fetchAllData();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 前日〜7日前のDateTimeリスト
  void _setupDates() {
    final now = DateTime.now();
    // 前日(今日0:00 -1日)
    final end = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));

    _dates = [];
    for (int i = 0; i < 7; i++) {
      _dates.add(end.subtract(Duration(days: i)));
    }
    _dayIndex = 0;
  }

  /// (A) 2回目以降データ再取得
  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    _sessionKey = prefs.getString('session_key') ?? _sessionKey;
    _puuid = prefs.getString('riot_puuid') ?? _puuid;

    // 1) Health
    bool authorized = await _healthService.requestPermissions();
    if (authorized) {
      final newSleepData = await _healthService.fetchSleepData();
      setState(() {
        _sleepData = newSleepData;
      });
    }

    // 2) Game
    if (_puuid != null && _puuid!.isNotEmpty) {
      // getRecentMatches は detailを含む
      final newMatches = await _gameService.getRecentMatches(_puuid!);
      setState(() {
        _recentMatches = newMatches;
      });
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final date = currentDate;
    final dateStr = currentDateString;

    // 当日分の睡眠
    final sleepsOfDay = _filterSleepData(date);
    // 当日分のマッチ
    final matchesOfDay = _filterMatchData(date);

    // ドーナツグラフ(当日)
    final dailyDonut = _buildDailyDonutChart(date);
    // 1週間棒グラフ
    final weeklyBar = _buildWeeklyBar();

    return Scaffold(
      appBar: AppBar(title: const Text("Carry App - Main Screen")),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 日付ナビ
                    _buildDateNavigator(),
                    const SizedBox(height: 20),

                    // 日報ボタン
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DailyReportScreen(),
                            ),
                          );
                        },
                        child: const Text("日報を入力"),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ドーナツ
                    Text(
                      "【$dateStr】ドーナツグラフ (24h)",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    dailyDonut,
                    const SizedBox(height: 20),

                    // 睡眠データ
                    Text(
                      "【$dateStr】の睡眠データ",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (sleepsOfDay.isEmpty)
                      const Text("睡眠データなし")
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:
                            sleepsOfDay.map((pt) {
                              final start = pt.dateFrom.toLocal();
                              final end = pt.dateTo.toLocal();
                              return Text("開始: $start, 終了: $end");
                            }).toList(),
                      ),
                    const SizedBox(height: 20),

                    // マッチデータ
                    Text(
                      "【$dateStr】のマッチ情報",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (matchesOfDay.isEmpty)
                      const Text("マッチ情報なし")
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: matchesOfDay.map(_buildMatchItem).toList(),
                      ),
                    const SizedBox(height: 30),

                    // 1週間棒グラフ
                    const Text(
                      "1週間の睡眠 / ゲーム 棒グラフ",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    weeklyBar,

                    const SizedBox(height: 30),
                    const Divider(),

                    // 下部セッションキー等
                    Text("セッションキー: ${_sessionKey ?? '未取得'}"),
                    Text("PUUID: ${_puuid ?? '未取得'}"),
                    Text("Game Name: ${widget.riotGameName ?? '未取得'}"),
                    Text("Tag Line: ${widget.riotTagLine ?? '未取得'}"),
                  ],
                ),
              ),
    );
  }

  // 日付切り替えUI
  Widget _buildDateNavigator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed:
              _dayIndex >= 6
                  ? null
                  : () {
                    setState(() {
                      _dayIndex++;
                    });
                  },
        ),
        Text(
          currentDateString,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed:
              _dayIndex <= 0
                  ? null
                  : () {
                    setState(() {
                      _dayIndex--;
                    });
                  },
        ),
      ],
    );
  }

  DateTime get currentDate => _dates[_dayIndex];
  String get currentDateString {
    final d = currentDate;
    return "${d.year}-${_twoDigits(d.month)}-${_twoDigits(d.day)}";
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  /// ドーナツグラフ (当日24h)
  Widget _buildDailyDonutChart(DateTime date) {
    final sleepM = _calcDailySleepMin(date);
    final gameM = _calcDailyGameMin(date);
    double otherM = 1440 - (sleepM + gameM);
    if (otherM < 0) otherM = 0;

    final sections = [
      PieChartSectionData(value: sleepM, color: Colors.blue, title: "Sleep"),
      PieChartSectionData(value: gameM, color: Colors.red, title: "Game"),
      PieChartSectionData(value: otherM, color: Colors.grey, title: "Other"),
    ];

    return SizedBox(
      height: 200,
      child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 40)),
    );
  }

  /// 1週間棒グラフ
  Widget _buildWeeklyBar() {
    final dayKeys =
        _dates.map((d) => "${d.month}/${d.day}").toList().reversed.toList();

    List<BarChartGroupData> groups = [];
    int i = 0;
    for (final dayStr in dayKeys) {
      final dateIndex = _dates.length - 1 - i;
      final day = _dates[dateIndex];

      final sleepMin = _calcDailySleepMin(day);
      final gameMin = _calcDailyGameMin(day);

      final rods = [
        BarChartRodData(toY: sleepMin, color: Colors.blue, width: 8),
        BarChartRodData(toY: gameMin, color: Colors.red, width: 8),
      ];

      groups.add(BarChartGroupData(x: i, barRods: rods));
      i++;
    }

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          barGroups: groups,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < dayKeys.length) {
                    return Text(dayKeys[idx]);
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  // 当日終了した睡眠合計(分)
  double _calcDailySleepMin(DateTime date) {
    final sleeps = _filterSleepData(date);
    double sumMin = 0;
    for (var pt in sleeps) {
      final dur = pt.dateTo.difference(pt.dateFrom).inMinutes;
      if (dur > 0) sumMin += dur;
    }
    return sumMin;
  }

  // 当日開始したマッチの合計(分)
  double _calcDailyGameMin(DateTime date) {
    final matches = _filterMatchData(date);
    double sumMin = 0;
    for (var m in matches) {
      final lengthMs = (m["gameLengthMillis"] as int?) ?? 0;
      if (lengthMs > 0) {
        sumMin += lengthMs / 60000.0;
      }
    }
    return sumMin;
  }

  // 当日終了の睡眠
  List<HealthDataPoint> _filterSleepData(DateTime date) {
    return _sleepData.where((pt) {
      final end = pt.dateTo.toLocal();
      return (end.year == date.year &&
          end.month == date.month &&
          end.day == date.day);
    }).toList();
  }

  // 当日開始のマッチ
  List<Map<String, dynamic>> _filterMatchData(DateTime date) {
    return _recentMatches.where((m) {
      final startMs = (m["gameStartMillis"] as int?) ?? 0;
      final startDt = DateTime.fromMillisecondsSinceEpoch(startMs).toLocal();
      return startDt.year == date.year &&
          startDt.month == date.month &&
          startDt.day == date.day;
    }).toList();
  }

  /// マッチアイテムの表示 (修正後: 追加情報を表示)
  Widget _buildMatchItem(Map<String, dynamic> match) {
    // 基本情報
    final matchId = match["matchId"] ?? "";
    final mapId = match["mapId"] ?? "unknownMap";
    final queueId = match["queueId"] ?? "unknownMode";
    final isDm = match["isDeathmatch"] == true;

    final startMs = (match["gameStartMillis"] as int?) ?? 0;
    final lengthMs = (match["gameLengthMillis"] as int?) ?? 0;
    final startTime = DateTime.fromMillisecondsSinceEpoch(startMs).toLocal();
    final lengthMin = (lengthMs / 60000.0).toStringAsFixed(1);

    // スコア情報
    final teamAScore = (match["teamAScore"] as int?) ?? 0;
    final teamBScore = (match["teamBScore"] as int?) ?? 0;
    final didWin = match["didWin"] == true;

    // 自分情報
    final self = match["self"] ?? {};
    final selfName = "${self["name"]}#${self["tagLine"]}";
    final selfChar = self["character"] ?? "???";
    final selfKills = self["kills"] ?? 0;
    final selfDeaths = self["deaths"] ?? 0;
    final selfAssists = self["assists"] ?? 0;

    final allyTeam =
        (match["allyTeam"] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
    final enemyTeam =
        (match["enemyTeam"] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();

    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("matchId: $matchId"),
          Text("  map: $mapId, mode: $queueId"),
          Text("  isDeathmatch: $isDm"),
          Text("  start: $startTime"),
          Text("  length: $lengthMin 分"),
          // スコア (teamA - teamB)
          Text("  teamA: $teamAScore vs teamB: $teamBScore"),
          Text("  didWin (Self): $didWin"),
          // 自分情報
          const Text("  [Your Stats]:"),
          Text("    name: $selfName"),
          Text("    char: $selfChar"),
          Text("    K/D/A: $selfKills/$selfDeaths/$selfAssists"),

          // Ally Team
          const Text("  Ally Team:"),
          if (allyTeam.isEmpty)
            const Text("   (none?)")
          else
            ...allyTeam.map((p) {
              final pname = p["name"] ?? "";
              final pchar = p["character"] ?? "";
              final pk = p["kills"] ?? 0;
              final pd = p["deaths"] ?? 0;
              final pa = p["assists"] ?? 0;
              return Text("    $pname [$pchar] => K/D/A: $pk/$pd/$pa");
            }).toList(),

          // Enemy Team
          const Text("  Enemy Team:"),
          if (enemyTeam.isEmpty)
            const Text("   (none?)")
          else
            ...enemyTeam.map((p) {
              final pname = p["name"] ?? "";
              final pchar = p["character"] ?? "";
              final pk = p["kills"] ?? 0;
              final pd = p["deaths"] ?? 0;
              final pa = p["assists"] ?? 0;
              return Text("    $pname [$pchar] => K/D/A: $pk/$pd/$pa");
            }).toList(),
        ],
      ),
    );
  }
}
