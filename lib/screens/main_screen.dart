import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:fl_chart/fl_chart.dart';

class MainScreen extends StatefulWidget {
  final List<HealthDataPoint>? sleepData;
  final List<Map<String, dynamic>>? recentMatches;
  final List<Map<String, dynamic>>? dailyReports;

  // 日付リスト: HomeRootScreenで作った (前日〜7日前)
  final List<DateTime>? dateList;

  // 日報入力ボタン押下時のコールバック
  final VoidCallback? onTapDailyReport;

  const MainScreen({
    super.key,
    this.sleepData,
    this.recentMatches,
    this.dailyReports,
    this.dateList,
    this.onTapDailyReport,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // データ
  late List<HealthDataPoint> _sleepData;
  late List<Map<String, dynamic>> _recentMatches;
  late List<Map<String, dynamic>> _dailyReports; // 日報一覧

  // 日付切り替え (前日〜7日前)
  late List<DateTime> _dates;
  int _dayIndex = 0; // 0 => 前日, 6 => 7日前

  @override
  void initState() {
    super.initState();

    // コンストラクタ引数をコピー
    _sleepData = widget.sleepData ?? [];
    _recentMatches = widget.recentMatches ?? [];
    _dailyReports = widget.dailyReports ?? [];

    // HomeRootScreen側から受け取った日付リスト (前日〜7日前)
    _dates = widget.dateList ?? [];

    // 初期値 dayIndex=0 => 前日
    _dayIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    // 現在の選択日
    final currentDate =
        _dates.isNotEmpty
            ? _dates[_dayIndex]
            : DateTime.now().subtract(const Duration(days: 1));

    final dateStr =
        "${currentDate.year}-${_twoDigits(currentDate.month)}-${_twoDigits(currentDate.day)}";

    // 当日分(前日〜7日前のうち一つ)
    final sleepsOfDay = _filterSleepData(currentDate);
    final matchesOfDay = _filterMatchData(currentDate);
    final dailyItem = _filterDailyData(currentDate);

    // 日報入力判別用
    final yesterday = _dates[0];
    final yesterdayReport = _filterDailyData(yesterday);

    return Scaffold(
      appBar: AppBar(title: const Text("Carry App - Main Screen")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // (A) 昨日の日報未入力ならアナウンス
            if (yesterdayReport == null)
              Container(
                color: Colors.yellow[100],
                padding: const EdgeInsets.all(8),
                child: const Text(
                  "日報を入力しましょう！",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 20),

            // (B) 日付ナビ
            _buildDateNavigator(dateStr),
            const SizedBox(height: 20),

            // (C) 「日報を入力」ボタン => HomeRootScreen の onTapDailyReport
            Center(
              child: ElevatedButton(
                onPressed: widget.onTapDailyReport,
                child: const Text("日報を入力"),
              ),
            ),
            const SizedBox(height: 20),

            // (D) ドーナツ(24h)
            Text(
              "【$dateStr】ドーナツグラフ (24h)",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            _buildDailyDonutChart(currentDate),
            const SizedBox(height: 20),

            // (E) 睡眠データ
            Text(
              "【$dateStr】の睡眠データ",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

            // (F) マッチ情報
            Text(
              "【$dateStr】のマッチ情報",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (matchesOfDay.isEmpty)
              const Text("マッチ情報なし")
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: matchesOfDay.map(_buildMatchItem).toList(),
              ),
            const SizedBox(height: 30),

            // (G) 日報
            Text(
              "【$dateStr】の日報",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (dailyItem == null)
              const Text("日報なし")
            else
              _buildDailyReportView(dailyItem["value"] as Map<String, dynamic>),
            const SizedBox(height: 30),

            const Divider(),
          ],
        ),
      ),
    );
  }

  // ==== 日付ナビ ====
  Widget _buildDateNavigator(String dateStr) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed:
              _dayIndex >= 6
                  ? null
                  : () {
                    setState(() => _dayIndex++);
                  },
        ),
        Text(
          dateStr,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed:
              _dayIndex <= 0
                  ? null
                  : () {
                    setState(() => _dayIndex--);
                  },
        ),
      ],
    );
  }

  // ==== ドーナツグラフ (24h) ====
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

  // ==== 計算系 ====
  double _calcDailySleepMin(DateTime date) {
    final sleeps = _filterSleepData(date);
    double sumMin = 0;
    for (var pt in sleeps) {
      final dur = pt.dateTo.difference(pt.dateFrom).inMinutes;
      if (dur > 0) sumMin += dur;
    }
    return sumMin;
  }

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

  // ==== フィルタ ====
  List<HealthDataPoint> _filterSleepData(DateTime date) {
    return _sleepData.where((pt) {
      final end = pt.dateTo.toLocal();
      return (end.year == date.year &&
          end.month == date.month &&
          end.day == date.day);
    }).toList();
  }

  List<Map<String, dynamic>> _filterMatchData(DateTime date) {
    return _recentMatches.where((m) {
      final startMs = (m["gameStartMillis"] as int?) ?? 0;
      final startDt = DateTime.fromMillisecondsSinceEpoch(startMs).toLocal();
      return startDt.year == date.year &&
          startDt.month == date.month &&
          startDt.day == date.day;
    }).toList();
  }

  Map<String, dynamic>? _filterDailyData(DateTime date) {
    // 同じロジック: 12時固定
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

  String _twoDigits(int n) => n.toString().padLeft(2, '0');
}
