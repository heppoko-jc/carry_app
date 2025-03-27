import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:fl_chart/fl_chart.dart';

/// WeeklyScreenでは1週間まとめの棒グラフと日報(モチベーション)の折れ線グラフを表示する
class WeeklyScreen extends StatelessWidget {
  final List<HealthDataPoint> sleepData;
  final List<Map<String, dynamic>> recentMatches;
  final List<Map<String, dynamic>> dailyReports;
  // dataListは、index 0: 前日、6: 7日前 の降順で入っている前提
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
    // sortedDates: 昇順（古い→新しい）に変換
    final List<DateTime> sortedDates = List.from(dateList.reversed);

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
            _buildWeeklyBar(sortedDates),
            const SizedBox(height: 30),

            // ==== (2) モチベーション の折れ線グラフ ====
            const Text(
              "1週間の日報 (モチベーション)",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            _buildDailyReportLineChart(sortedDates),
            const SizedBox(height: 30),
            const Divider(),
          ],
        ),
      ),
    );
  }

  /// -------------------------------
  /// (1) 睡眠/ゲーム の棒グラフ
  /// sortedDates は昇順（0: 7日前、最終: 前日）
  /// -------------------------------
  Widget _buildWeeklyBar(List<DateTime> sortedDates) {
    // X軸ラベルもsortedDatesを利用して古い→新しい順で表示
    final dayKeys = sortedDates.map((d) => "${d.month}/${d.day}").toList();

    final groups = <BarChartGroupData>[];

    // 0からsortedDates.length - 1の順番でX軸の値と対応させる
    for (int i = 0; i < sortedDates.length; i++) {
      final day = sortedDates[i];

      final sleepMin = _calcDailySleepMin(day);
      final gameMin = _calcDailyGameMin(day);

      final rods = [
        BarChartRodData(toY: sleepMin, color: Colors.blue, width: 8),
        BarChartRodData(toY: gameMin, color: Colors.red, width: 8),
      ];

      groups.add(BarChartGroupData(x: i, barRods: rods));
    }

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          barGroups: groups,
          titlesData: FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  /// -------------------------------
  /// (2) モチベーション の折れ線グラフ
  /// -------------------------------
  Widget _buildDailyReportLineChart(List<DateTime> sortedDates) {
    final motivationSpots = <FlSpot>[];

    // sortedDatesは昇順（古い→新しい）なので、その順でX軸値は0〜n-1
    for (int i = 0; i < sortedDates.length; i++) {
      final day = sortedDates[i];
      final xValue = i.toDouble();
      final report = _findDailyReport(day);
      if (report == null) {
        // 日報なしはNaNを入れて折れ線が途切れるように
        motivationSpots.add(FlSpot(xValue, double.nan));
        continue;
      }
      final val = report["value"] as Map<String, dynamic>? ?? {};
      // モチベーションは1〜100の値を想定
      final mot = (val["motivation"] is int) ? val["motivation"] as int : 0;
      if (mot > 0) {
        motivationSpots.add(FlSpot(xValue, mot.toDouble()));
      } else {
        motivationSpots.add(FlSpot(xValue, double.nan));
      }
    }

    final motivationLine = LineChartBarData(
      spots: motivationSpots,
      color: Colors.orange,
      isCurved: false,
      dotData: const FlDotData(show: true),
    );

    final chartData = LineChartData(
      minX: 0,
      maxX: (sortedDates.length - 1).toDouble(),
      minY: 0,
      maxY: 110, // 余裕を持たせるため110
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            // X軸ラベルはsortedDatesをそのまま使用（古い→新しい）
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx >= 0 && idx < sortedDates.length) {
                final d = sortedDates[idx];
                return Text("${d.month}/${d.day}");
              }
              return const SizedBox();
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: true, interval: 10),
        ),
      ),
      lineBarsData: [motivationLine],
    );

    return SizedBox(height: 200, child: LineChart(chartData));
  }

  /// -------------------------------
  /// 睡眠/ゲーム棒グラフの計算ロジック
  /// -------------------------------
  double _calcDailySleepMin(DateTime date) {
    // sleepDataはWeeklyScreenに渡されたデータ
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

  // ==== フィルタリング処理 ====
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
  /// 日報(モチベーション)折れ線グラフの計算用
  /// -------------------------------
  Map<String, dynamic>? _findDailyReport(DateTime day) {
    // 日報のdatetimeはその日の12:00固定
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
