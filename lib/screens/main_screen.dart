import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health/health.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/health_service.dart';
import '../services/game_service.dart';

class MainScreen extends StatefulWidget {
  final List<HealthDataPoint>? sleepData; // 初回起動時などに渡される睡眠データ
  final List<Map<String, dynamic>>? recentMatches; // 初回起動時などに渡されるマッチデータ

  final String? sessionKey; // 表示用
  final String? riotPUUID; // 表示用
  final String? riotGameName; // 表示用
  final String? riotTagLine; // 表示用

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
  // サービス
  final HealthService _healthService = HealthService();
  final GameService _gameService = GameService();

  // メイン画面上で扱うデータ
  List<HealthDataPoint> _sleepData = [];
  List<Map<String, dynamic>> _recentMatches = [];

  // セッションキー / PUUID の再ロード用
  String? _sessionKey;
  String? _puuid;

  bool _isLoading = false;

  // 日付切り替え用 (前日～7日前)
  late List<DateTime> _dates;
  int _dayIndex = 0;

  @override
  void initState() {
    super.initState();

    // 1) 初回起動時に引数で渡されたデータをコピー
    if (widget.sleepData != null) {
      _sleepData = widget.sleepData!;
    }
    if (widget.recentMatches != null) {
      _recentMatches = widget.recentMatches!;
    }

    // セッションキー / PUUID も初期値をコピー
    _sessionKey = widget.sessionKey;
    _puuid = widget.riotPUUID;

    // 2) 日付リストを生成
    _setupDates();

    // 3) 2回目以降の再取得 or 毎回最新取得
    _fetchAllData();
  }

  /// (A) 前日～7日前の日付をリストに
  void _setupDates() {
    final now = DateTime.now();
    // 前日(今日の00:00 - 1日)
    final end = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));

    _dates = [];
    for (int i = 0; i < 7; i++) {
      _dates.add(end.subtract(Duration(days: i)));
    }
    // [0] => 前日, [6] => 7日前
    _dayIndex = 0;
  }

  /// (B) 2回目以降にも Sleep / Match を再取得
  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);

    // SharedPreferencesから session_key / riot_puuid を読み出し
    final prefs = await SharedPreferences.getInstance();
    _sessionKey = prefs.getString('session_key') ?? _sessionKey;
    _puuid = prefs.getString('riot_puuid') ?? _puuid;

    // 1. Health -> 8日分を取得
    final authorized = await _healthService.requestPermissions();
    if (authorized) {
      final newSleepData = await _healthService.fetchSleepData();
      setState(() {
        _sleepData = newSleepData;
      });
    }

    // 2. Game -> PUUIDあれば直近1週間
    if (_puuid != null && _puuid!.isNotEmpty) {
      final newMatches = await _gameService.getRecentMatches(_puuid!);
      setState(() {
        _recentMatches = newMatches;
      });
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    // 現在の日付
    final date = currentDate;
    final dateStr = currentDateString;

    // 当日分の睡眠 / マッチデータ
    final sleepsOfDay = _filterSleepData(date);
    final matchesOfDay = _filterMatchData(date);

    // 円グラフ(ドーナツ)
    final dailyDonut = _buildDailyDonutChart(date);

    // 1週間の棒グラフ
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
                    // ===== 日付ナビゲータ (＜ 日付 ＞) =====
                    _buildDateNavigator(),
                    const SizedBox(height: 20),

                    // ===== 24時間ドーナツ (その日の睡眠/ゲーム/その他) =====
                    Text(
                      "【$dateStr】ドーナツグラフ (24h)",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    dailyDonut,
                    const SizedBox(height: 20),

                    // ===== 当日の睡眠データ =====
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

                    // ===== 当日のマッチデータ =====
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

                    // ===== 1週間の棒グラフ =====
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

                    // ===== 下部にセッションキーやPUUID等 =====
                    Text("セッションキー: ${_sessionKey ?? '未取得'}"),
                    Text("PUUID: ${_puuid ?? '未取得'}"),
                    Text("Game Name: ${widget.riotGameName ?? '未取得'}"),
                    Text("Tag Line: ${widget.riotTagLine ?? '未取得'}"),
                  ],
                ),
              ),
    );
  }

  /// 【 日付ナビゲータ (＜＞ボタン) 】
  Widget _buildDateNavigator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 左 (＜) => dayIndex++
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
        // 右 (＞) => dayIndex--
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

  // 日付リストで現在の日付
  DateTime get currentDate => _dates[_dayIndex];

  // yyyy-mm-dd表示
  String get currentDateString {
    final d = currentDate;
    return "${d.year}-${_twoDigits(d.month)}-${_twoDigits(d.day)}";
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  // 今日 or 選択日の 「睡眠 (分)」 を計算
  double _calcDailySleepMin(DateTime date) {
    // 当日終了の睡眠データをすべて合算
    final sleeps = _filterSleepData(date);
    double sumMin = 0;
    for (var pt in sleeps) {
      final duration = pt.dateTo.difference(pt.dateFrom).inMinutes;
      // 安全策
      if (duration > 0) {
        sumMin += duration;
      }
    }
    return sumMin;
  }

  // 今日 or 選択日の 「ゲーム (分)」 を計算
  double _calcDailyGameMin(DateTime date) {
    // 当日開始のマッチ => time = gameLengthMillis合計
    final matches = _filterMatchData(date);
    double sumMin = 0;
    for (var m in matches) {
      final lengthMs = (m["gameLengthMillis"] as int?) ?? 0;
      if (lengthMs > 0) {
        sumMin += (lengthMs / 60000.0);
      }
    }
    return sumMin;
  }

  /// (1) ドーナツチャート: 睡眠 / ゲーム / その他 (24h=1440分)
  Widget _buildDailyDonutChart(DateTime date) {
    final sleepM = _calcDailySleepMin(date);
    final gameM = _calcDailyGameMin(date);
    double otherM = 1440 - (sleepM + gameM);
    if (otherM < 0) {
      otherM = 0;
    }

    final sections = <PieChartSectionData>[
      PieChartSectionData(value: sleepM, color: Colors.blue, title: 'Sleep'),
      PieChartSectionData(value: gameM, color: Colors.red, title: 'Game'),
      PieChartSectionData(value: otherM, color: Colors.grey, title: 'Other'),
    ];

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: sections,
          centerSpaceRadius: 40, // ドーナツ感
        ),
      ),
    );
  }

  /// (2) 1週間の棒グラフ: 日付ごとに睡眠/ゲーム
  Widget _buildWeeklyBar() {
    // dayKeys: ex: "3/16","3/15","3/14",...
    // reversed() するかどうかは好み
    final dayKeys =
        _dates.map((d) => "${d.month}/${d.day}").toList().reversed.toList();

    // fl_chart用のBarChartGroupDataを作る
    List<BarChartGroupData> groups = [];

    // reversedの場合, i=0 => 最も古い日  , i=6 => 新しい日
    int i = 0;
    for (final dayStr in dayKeys) {
      // dayStrをパース or iを使って _dates[_dates.length-1 - i]
      // ここでは直にアクセスしづらいので、別のアプローチ:
      final dateIndex = _dates.length - 1 - i;
      final day = _dates[dateIndex];

      final sleepMin = _calcDailySleepMin(day);
      final gameMin = _calcDailyGameMin(day);

      // 2本のBar (sleep=blue, game=red)
      final rods = [
        BarChartRodData(toY: sleepMin.toDouble(), color: Colors.blue, width: 8),
        BarChartRodData(toY: gameMin.toDouble(), color: Colors.red, width: 8),
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
                  // dayKeys= 0..6
                  if (idx >= 0 && idx < dayKeys.length) {
                    return Text(dayKeys[idx]); // ex: "3/10"
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

  // -- 該当日の睡眠(終了日=当日)
  List<HealthDataPoint> _filterSleepData(DateTime date) {
    return _sleepData.where((pt) {
      final end = pt.dateTo.toLocal();
      return (end.year == date.year &&
          end.month == date.month &&
          end.day == date.day);
    }).toList();
  }

  // -- 該当日のマッチ(開始日=当日)
  List<Map<String, dynamic>> _filterMatchData(DateTime date) {
    return _recentMatches.where((m) {
      final startMs = m["gameStartMillis"] as int? ?? 0;
      final startDt = DateTime.fromMillisecondsSinceEpoch(startMs).toLocal();
      return (startDt.year == date.year &&
          startDt.month == date.month &&
          startDt.day == date.day);
    }).toList();
  }

  // matchItem描画
  Widget _buildMatchItem(Map<String, dynamic> m) {
    final matchId = m["matchId"] ?? "";
    final mapId = m["mapId"] ?? "";
    final gameMode = m["gameMode"] ?? "";
    final startMs = m["gameStartMillis"] as int? ?? 0;
    final lengthMs = m["gameLengthMillis"] as int? ?? 0;

    final startTime = DateTime.fromMillisecondsSinceEpoch(startMs).toLocal();
    final lengthMin = (lengthMs / 60000).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("matchId: $matchId"),
          Text("  map: $mapId, mode: $gameMode"),
          Text("  start: $startTime"),
          Text("  length: $lengthMin 分"),
        ],
      ),
    );
  }
}
