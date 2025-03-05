import 'dart:io';
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
  final Health health = Health(); // Health API のインスタンス
  List<HealthDataPoint> _sleepData = []; // 取得した睡眠データ
  bool _isLoading = false; // ローディング状態
  bool _isAuthorized = false; // 権限付与状態

  @override
  void initState() {
    super.initState();
    _initializeHealth(); // アプリ起動時に権限取得 & データ取得
  }

  /// **Health Connect / Apple Health の権限をリクエスト**
  Future<void> _initializeHealth() async {
    setState(() => _isLoading = true);

    print("I/flutter: 権限リクエスト開始...");

    // **Android の ACTIVITY_RECOGNITION の権限をリクエスト**
    if (Platform.isAndroid &&
        await Permission.activityRecognition.request().isDenied) {
      print("I/flutter: ACTIVITY_RECOGNITION の権限が拒否されました");
      setState(() => _isLoading = false);
      return;
    }

    // **プラットフォームごとにリクエストするデータタイプを変更**
    List<HealthDataType> types =
        Platform.isAndroid
            ? [
              HealthDataType.SLEEP_ASLEEP,
              HealthDataType.SLEEP_AWAKE,
              HealthDataType.SLEEP_SESSION,
            ] // Android
            : [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_AWAKE]; // iOS

    // **権限がすでにあるかを確認**
    bool? hasPermissions = await health.hasPermissions(types);
    if (hasPermissions == true) {
      print("I/flutter: 既に Health Connect / Apple Health の権限があります");
      setState(() => _isAuthorized = true);
      await fetchSleepData(); // 既に権限がある場合、即座にデータ取得
      return;
    }

    // **権限リクエスト**
    bool requested = await health.requestAuthorization(types);

    if (!requested) {
      print("I/flutter: Health Connect / HealthKit の権限リクエストが拒否されました");
      setState(() {
        _isAuthorized = false;
        _isLoading = false;
      });
      return;
    } else {
      print("I/flutter: Health Connect / HealthKit の権限が付与されました");
      setState(() => _isAuthorized = true);
    }

    // 権限付与後、データ取得
    await fetchSleepData();
  }

  /// **過去 7 日間の睡眠データを取得**
  Future<void> fetchSleepData() async {
    setState(() => _isLoading = true);

    DateTime now = DateTime.now();
    DateTime start = now.subtract(const Duration(days: 7)); // 過去7日間分を取得

    print("I/flutter: 睡眠データの取得を開始...");
    try {
      List<HealthDataType> types =
          Platform.isAndroid
              ? [
                HealthDataType.SLEEP_ASLEEP,
                HealthDataType.SLEEP_AWAKE,
                HealthDataType.SLEEP_SESSION,
              ] // Android
              : [
                HealthDataType.SLEEP_ASLEEP,
                HealthDataType.SLEEP_AWAKE,
              ]; // iOS

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
        _isLoading = false;
      });
    } catch (e) {
      print("I/flutter: 睡眠データの取得中にエラーが発生: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("睡眠時間の記録")),
      body: Center(
        child:
            _isLoading
                ? const CircularProgressIndicator() // ローディング表示
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: fetchSleepData,
                      child: const Text("睡眠データを再取得"),
                    ),
                    const SizedBox(height: 20),
                    _isAuthorized
                        ? (_sleepData.isEmpty
                            ? const Text(
                              "データなし",
                              style: TextStyle(fontSize: 18),
                            )
                            : Column(
                              children:
                                  _sleepData.map((data) {
                                    return Text(
                                      "開始: ${data.dateFrom}\n終了: ${data.dateTo}",
                                      style: const TextStyle(fontSize: 16),
                                    );
                                  }).toList(),
                            ))
                        : const Text(
                          "Health Connect / Apple Health の権限がありません",
                          style: TextStyle(fontSize: 18, color: Colors.red),
                        ),
                  ],
                ),
      ),
    );
  }
}
