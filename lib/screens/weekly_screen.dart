import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:fl_chart/fl_chart.dart';

/// WeeklyScreenでは1週間まとめの棒グラフなどを表示する
class WeeklyScreen extends StatelessWidget {
  final List<HealthDataPoint> sleepData;
  final List<Map<String, dynamic>> recentMatches;
  final List<Map<String, dynamic>> dailyReports;
  final List<DateTime> dateList;

  const WeeklyScreen({
    super.key,
    required this.sleepData,
    required this.recentMatches,
    required this.dailyReports,
    required this.dateList,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ウィークリー")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==== (1) 1週間の睡眠/ゲーム棒グラフ ====
            const Text(
              "1週間の睡眠 / ゲーム 棒グラフ",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            _buildWeeklyBar(),
            const SizedBox(height: 30),

            // ==== (2) モチベーション & 自己評価 折れ線グラフ ====
            const Text(
              "1週間の日報 (モチベーション/自己評価)",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            _buildDailyReportLineChart(),
            const SizedBox(height: 30),
            const Divider(),
          ],
        ),
      ),
    );
  }

  /// -------------------------------
  /// (1) 睡眠/ゲーム の棒グラフ
  /// -------------------------------
  Widget _buildWeeklyBar() {
    // dateList は 7日分の日付
    // reversedして 古い→新しい の順 or 新しい→古い の順は好みでOK
    final dayKeys =
        dateList.map((d) => "${d.month}/${d.day}").toList().reversed.toList();

    final groups = <BarChartGroupData>[];

    // ここでは「古い→新しい」を左→右にしたいので reversed
    for (int i = 0; i < dayKeys.length; i++) {
      final dateIndex = dateList.length - 1 - i;
      final day = dateList[dateIndex];

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
                    return Text(dayKeys[idx]); // "3/21"など
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

  /// -------------------------------
  /// (2) モチベーション / 自己評価 の折れ線グラフ
  /// -------------------------------
  Widget _buildDailyReportLineChart() {
    // モチベ(Line1=オレンジ) と自己評価(Line2=緑)
    final motivationSpots = <FlSpot>[];
    final selfEvalSpots = <FlSpot>[];

    // dateList[0..6] を古い順(0=最古, 6=最新)に見せたいなら普通に for i in 0..6
    // reversedにする場合は工夫要
    // ここは "古い→新しい" 左→右を想定
    for (int i = 0; i < dateList.length; i++) {
      final day = dateList[i];
      final xValue = i.toDouble(); // 0..6
      final report = _findDailyReport(day);
      if (report == null) {
        // 日報なし => スキップ => 線が途切れる
        continue;
      }
      final val = report["value"] as Map<String, dynamic>? ?? {};
      final mot = (val["motivation"] is int) ? val["motivation"] as int : 0;
      final sev =
          (val["selfEvaluation"] is int) ? val["selfEvaluation"] as int : 0;

      // 1..5 の想定, 0なら実質空 => skip
      if (mot > 0) {
        motivationSpots.add(FlSpot(xValue, mot.toDouble()));
      }
      if (sev > 0) {
        selfEvalSpots.add(FlSpot(xValue, sev.toDouble()));
      }
    }

    // Line1(モチベ)
    final motivationLine = LineChartBarData(
      spots: motivationSpots,
      color: Colors.orange,
      isCurved: false,
      dotData: const FlDotData(show: true),
    );
    // Line2(自己評価)
    final selfEvalLine = LineChartBarData(
      spots: selfEvalSpots,
      color: Colors.green,
      isCurved: false,
      dotData: const FlDotData(show: true),
    );

    // 0..6 => 7日
    // y=1..5 程度 => 0..6 に余裕を持たせる
    final chartData = LineChartData(
      minX: 0,
      maxX: 6,
      minY: 0,
      maxY: 6,
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            // x=0..6 => dateList[i], i=0が最古日
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i < 0 || i >= dateList.length) return const SizedBox();
              final d = dateList[i];
              return Text("${d.month}/${d.day}");
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: true, interval: 1),
        ),
      ),
      lineBarsData: [motivationLine, selfEvalLine],
    );

    return SizedBox(height: 200, child: LineChart(chartData));
  }

  /// -------------------------------
  /// 睡眠/ゲーム棒グラフの計算ロジック
  /// -------------------------------
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

  List<HealthDataPoint> _filterSleepData(DateTime date) {
    return sleepData.where((pt) {
      final end = pt.dateTo.toLocal();
      return (end.year == date.year &&
          end.month == date.month &&
          end.day == date.day);
    }).toList();
  }

  List<Map<String, dynamic>> _filterMatchData(DateTime date) {
    return recentMatches.where((m) {
      final startMs = (m["gameStartMillis"] as int?) ?? 0;
      final startDt = DateTime.fromMillisecondsSinceEpoch(startMs).toLocal();
      return (startDt.year == date.year &&
          startDt.month == date.month &&
          startDt.day == date.day);
    }).toList();
  }

  /// -------------------------------
  /// 日報(モチベ/評価)折れ線グラフの計算用
  /// -------------------------------
  Map<String, dynamic>? _findDailyReport(DateTime day) {
    // "datetime" が dayの12:00 のEpochMSかどうか
    final localMidday = DateTime(day.year, day.month, day.day, 12);
    final targetMs = localMidday.millisecondsSinceEpoch;

    for (var rep in dailyReports) {
      final dt = rep["datetime"] as int? ?? 0;
      if (dt == targetMs) {
        return rep;
      }
    }
    return null;
  }
}
