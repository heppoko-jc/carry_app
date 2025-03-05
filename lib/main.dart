import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SleepTrackerScreen(),
    );
  }
}

class SleepTrackerScreen extends StatefulWidget {
  const SleepTrackerScreen({super.key});

  @override
  _SleepTrackerScreenState createState() => _SleepTrackerScreenState();
}

class _SleepTrackerScreenState extends State<SleepTrackerScreen> {
  Health health = Health(); // Health API のインスタンス
  List<HealthDataPoint> _sleepData = []; // 取得した睡眠データ

  /// **睡眠データを取得する**
  Future<void> fetchSleepData() async {
    List<HealthDataType> types = [HealthDataType.SLEEP_ASLEEP];

    print("I/flutter: 権限リクエスト開始...");

    // **Android の ACTIVITY_RECOGNITION の権限をリクエスト**
    if (await Permission.activityRecognition.request().isDenied) {
      print("I/flutter: ACTIVITY_RECOGNITION の権限が拒否されました");
      return;
    }

    // **Health Connect または HealthKit の権限リクエスト**
    bool requested = await health.requestAuthorization(types);

    if (!requested) {
      print("I/flutter: Health Connect / HealthKit の権限リクエストが拒否されました");
      return;
    } else {
      print("I/flutter: Health Connect / HealthKit の権限が付与されました");
    }

    DateTime now = DateTime.now();
    DateTime start = now.subtract(const Duration(days: 1)); // 過去24時間分を取得

    print("I/flutter: 睡眠データの取得を開始...");
    try {
      List<HealthDataPoint> sleepData = await health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: types,
      );

      if (sleepData.isEmpty) {
        print("I/flutter: 取得した睡眠データは空です");
      } else {
        print("I/flutter: 取得成功 - ${sleepData.length} 件のデータ");
        for (var data in sleepData) {
          print("I/flutter: 開始: ${data.dateFrom}, 終了: ${data.dateTo}");
        }
      }

      setState(() {
        _sleepData = sleepData;
      });
    } catch (e) {
      print("I/flutter: 睡眠データの取得中にエラーが発生: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("睡眠時間の記録")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: fetchSleepData,
              child: const Text("睡眠データを取得"),
            ),
            const SizedBox(height: 20),
            _sleepData.isEmpty
                ? const Text("データなし", style: TextStyle(fontSize: 18))
                : Column(
                  children:
                      _sleepData.map((data) {
                        return Text(
                          "開始: ${data.dateFrom}\n終了: ${data.dateTo}",
                          style: const TextStyle(fontSize: 16),
                        );
                      }).toList(),
                ),
          ],
        ),
      ),
    );
  }
}
