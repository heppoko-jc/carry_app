import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health/health.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/health_service.dart';
import '../services/game_service.dart';
import '../services/sleep_data_service.dart';
import '../services/game_data_service.dart';
import '../services/normal_sync_service.dart';
import '../services/daily_report_service.dart'; // 日報データ取得
import '../screens/daily_report_screen.dart'; // 日報入力画面

class MainScreen extends StatefulWidget {
  final List<HealthDataPoint>? sleepData;
  final List<Map<String, dynamic>>? recentMatches;

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
  final DailyReportService _dailyReportService = DailyReportService();

  bool _isLoading = false;

  // データ
  List<HealthDataPoint> _sleepData = [];
  List<Map<String, dynamic>> _recentMatches = [];
  List<Map<String, dynamic>> _dailyReports = []; // 日報一覧

  String? _sessionKey;
  String? _puuid;

  // 日付切り替え (前日〜7日前)
  late List<DateTime> _dates;
  int _dayIndex = 0; // 0 => 前日, 6 => 7日前

  @override
  void initState() {
    super.initState();

    // 初回起動時の sleepData / recentMatches をコピー
    if (widget.sleepData != null) {
      _sleepData = widget.sleepData!;
    }
    if (widget.recentMatches != null) {
      _recentMatches = widget.recentMatches!;
    }

    _sessionKey = widget.sessionKey;
    _puuid = widget.riotPUUID;

    // デバッグ用最終同期日調整
    // _debugResetLastSyncedTime();

    _setupDates();

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
      final normalSync = NormalSyncService(
        healthService: _healthService,
        gameService: _gameService,
        sleepDataService: _sleepDataService,
        gameDataService: _gameDataService,
      );
      await normalSync.syncIncremental();
      await _fetchAllData();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 日付リスト(前日〜7日前)
  void _setupDates() {
    final now = DateTime.now();
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

  // データ取得(睡眠、マッチ、日報)
  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    _sessionKey = prefs.getString('session_key') ?? _sessionKey;
    _puuid = prefs.getString('riot_puuid') ?? _puuid;

    // 1) 睡眠
    final authorized = await _healthService.requestPermissions();
    if (authorized) {
      final newSleepData = await _healthService.fetchSleepData();
      _sleepData = newSleepData;
    }

    // 2) マッチ
    if (_puuid != null && _puuid!.isNotEmpty) {
      final newMatches = await _gameService.getRecentMatches(_puuid!);
      _recentMatches = newMatches;
    }

    // 3) 日報
    final dailyList = await _dailyReportService.fetchDailyReports();
    _dailyReports = dailyList;

    setState(() => _isLoading = false);
  }

  // 日報送信後際読み込み
  Future<void> _fetchDailyReportsOnly() async {
    setState(() => _isLoading = true);

    // 日報のみ取得
    final dailyList = await _dailyReportService.fetchDailyReports();

    setState(() {
      _dailyReports = dailyList;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final date = currentDate;
    final dateStr = currentDateString;

    // 当日分(前日〜7日前のうち一つ)
    final sleepsOfDay = _filterSleepData(date);
    final matchesOfDay = _filterMatchData(date);
    final dailyItem = _filterDailyData(date);

    final dailyDonut = _buildDailyDonutChart(date);
    final weeklyBar = _buildWeeklyBar();

    // 日報入力判別用
    final yesterday = _dates[0];
    final yesterdayReport = _filterDailyData(yesterday);

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
                    // ★ ここで昨日の日報が無い場合、アナウンスを表示
                    if (yesterdayReport == null)
                      Container(
                        color: Colors.yellow[100],
                        padding: const EdgeInsets.all(8),
                        child: const Text(
                          "日報を入力しましょう！",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // 日付ナビ
                    _buildDateNavigator(),
                    const SizedBox(height: 20),

                    // 日報入力
                    Center(
                      child: ElevatedButton(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DailyReportScreen(),
                            ),
                          );
                          if (result == true) {
                            // 日報送信成功したので、日報データだけ再取得
                            await _fetchDailyReportsOnly();

                            // 必要に応じてアナウンス非表示など setState 反映
                            setState(() {});
                          }
                        },
                        child: const Text("日報を入力"),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ドーナツ(24h)
                    Text(
                      "【$dateStr】ドーナツグラフ (24h)",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    dailyDonut,
                    const SizedBox(height: 20),

                    // 睡眠
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

                    // マッチ
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

                    // 日報
                    Text(
                      "【$dateStr】の日報",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (dailyItem == null)
                      const Text("日報なし")
                    else
                      _buildDailyReportView(
                        dailyItem["value"] as Map<String, dynamic>,
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

                    // セッションキーなど
                    Text("セッションキー: ${_sessionKey ?? '未取得'}"),
                    Text("PUUID: ${_puuid ?? '未取得'}"),
                    // riotGameName / tagLine
                  ],
                ),
              ),
    );
  }

  // ==== 日付ナビ ====
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

  // ==== ドーナツグラフ ====
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

  // ==== 1週間棒グラフ ====
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

  // ==== 睡眠時間(分) ====
  double _calcDailySleepMin(DateTime date) {
    final sleeps = _filterSleepData(date);
    double sumMin = 0;
    for (var pt in sleeps) {
      final dur = pt.dateTo.difference(pt.dateFrom).inMinutes;
      if (dur > 0) sumMin += dur;
    }
    return sumMin;
  }

  // ==== ゲーム時間(分) ====
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

  // ==== 睡眠フィルタ ====
  List<HealthDataPoint> _filterSleepData(DateTime date) {
    return _sleepData.where((pt) {
      final end = pt.dateTo.toLocal();
      return (end.year == date.year &&
          end.month == date.month &&
          end.day == date.day);
    }).toList();
  }

  // ==== マッチフィルタ ====
  List<Map<String, dynamic>> _filterMatchData(DateTime date) {
    return _recentMatches.where((m) {
      final startMs = (m["gameStartMillis"] as int?) ?? 0;
      final startDt = DateTime.fromMillisecondsSinceEpoch(startMs).toLocal();
      return startDt.year == date.year &&
          startDt.month == date.month &&
          startDt.day == date.day;
    }).toList();
  }

  // ==== 日報フィルタ ====
  Map<String, dynamic>? _filterDailyData(DateTime date) {
    // daily -> {id, datetime, value:{}}
    final localDate = DateTime(date.year, date.month, date.day, 12);
    final ms = localDate.millisecondsSinceEpoch;
    for (var item in _dailyReports) {
      final dt = item["datetime"] as int? ?? 0;
      if (dt == ms) {
        return item;
      }
    }
    return null;
  }

  // ==== 日報表示 ====
  Widget _buildDailyReportView(Map<String, dynamic> val) {
    final isBad = val["isBad"] == true;
    final motivation = val["motivation"] ?? "";
    final selfEval = val["selfEvaluation"] ?? "";
    final gComment = val["G-comment"] ?? "";
    final symptom = val["symptom"] ?? "";
    final place = val["place"] ?? "";
    final painLevel = val["painLevel"] ?? "";
    final mComment = val["M-comment"] ?? "";

    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey[200],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("motivation: $motivation"),
          Text("selfEval: $selfEval"),
          Text("G-comment: $gComment"),
          Text("isBad: $isBad"),
          if (isBad) ...[
            Text("symptom: $symptom"),
            Text("place: $place"),
            Text("painLevel: $painLevel"),
            Text("comment: $mComment"),
          ] else ...[
            const Text("symptom: (なし)"),
          ],
        ],
      ),
    );
  }

  // ==== マッチ表示 ====
  Widget _buildMatchItem(Map<String, dynamic> match) {
    final matchId = match["matchId"] ?? "";
    final mapId = match["mapId"] ?? "unknownMap";
    final queueId = match["queueId"] ?? "unknownMode";
    final isDm = match["isDeathmatch"] == true;

    final startMs = (match["gameStartMillis"] as int?) ?? 0;
    final lengthMs = (match["gameLengthMillis"] as int?) ?? 0;
    final startTime = DateTime.fromMillisecondsSinceEpoch(startMs).toLocal();
    final lengthMin = (lengthMs / 60000.0).toStringAsFixed(1);

    final teamAScore = (match["teamAScore"] as int?) ?? 0;
    final teamBScore = (match["teamBScore"] as int?) ?? 0;
    final didWin = match["didWin"] == true;

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
          Text("  teamA: $teamAScore vs teamB: $teamBScore"),
          Text("  didWin (Self): $didWin"),
          const Text("  [Your Stats]:"),
          Text("    name: $selfName"),
          Text("    char: $selfChar"),
          Text("    K/D/A: $selfKills/$selfDeaths/$selfAssists"),
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
