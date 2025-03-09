import 'dart:io';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthService {
  final Health _health = Health();
  List<HealthDataPoint> sleepData = [];
  bool isAuthorized = false;

  /// **Health Connect / Apple Health の権限をリクエスト**
  Future<bool> requestPermissions() async {
    print("I/flutter: 権限リクエスト開始...");

    if (Platform.isAndroid &&
        await Permission.activityRecognition.request().isDenied) {
      print("I/flutter: ACTIVITY_RECOGNITION の権限が拒否されました");
      return false;
    }

    List<HealthDataType> types =
        Platform.isAndroid
            ? [
              HealthDataType.SLEEP_ASLEEP,
              HealthDataType.SLEEP_AWAKE,
              HealthDataType.SLEEP_SESSION,
            ]
            : [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_AWAKE];

    bool? hasPermissions = await _health.hasPermissions(types);
    if (hasPermissions == true) {
      print("I/flutter: 既に Health Connect / Apple Health の権限があります");
      isAuthorized = true;
      return true;
    }

    bool requested = await _health.requestAuthorization(types);
    if (!requested) {
      print("I/flutter: Health Connect / HealthKit の権限リクエストが拒否されました");
      return false;
    }

    print("I/flutter: Health Connect / HealthKit の権限が付与されました");
    isAuthorized = true;
    return true;
  }

  /// **過去 7 日間の睡眠データを取得**
  Future<List<HealthDataPoint>> fetchSleepData() async {
    if (!isAuthorized) {
      print("I/flutter: 権限がないため、データ取得をスキップ");
      return [];
    }

    DateTime now = DateTime.now();
    DateTime start = now.subtract(const Duration(days: 7));

    List<HealthDataType> types =
        Platform.isAndroid
            ? [
              HealthDataType.SLEEP_ASLEEP,
              HealthDataType.SLEEP_AWAKE,
              HealthDataType.SLEEP_SESSION,
            ]
            : [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_AWAKE];

    print("I/flutter: 睡眠データの取得を開始...");
    try {
      sleepData = await _health.getHealthDataFromTypes(
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

      return sleepData;
    } catch (e) {
      print("I/flutter: 睡眠データの取得中にエラーが発生: $e");
      return [];
    }
  }
}
