// lib/services/health_service.dart
import 'dart:io';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthService {
  final Health _health = Health();
  List<HealthDataPoint> sleepData = [];
  bool isAuthorized = false;

  /// Health Connect / Apple Health の権限をリクエストする
  Future<bool> requestPermissions() async {
    print("I/flutter: 権限リクエスト開始...");

    if (Platform.isAndroid &&
        await Permission.activityRecognition.request().isDenied) {
      print("I/flutter: ACTIVITY_RECOGNITION の権限が拒否されました");
      return false;
    }

    // Androidの場合はSLEEP_SESSIONのみ、iOSは詳細な睡眠データを取得する
    List<HealthDataType> types;
    if (Platform.isAndroid) {
      types = [HealthDataType.SLEEP_SESSION];
    } else {
      types = [
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
        HealthDataType.SLEEP_IN_BED,
      ];
    }

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

  /// 過去8日間の睡眠データを取得する
  Future<List<HealthDataPoint>> fetchSleepData() async {
    if (!isAuthorized) {
      print("I/flutter: 権限がないため、データ取得をスキップ");
      return [];
    }

    DateTime now = DateTime.now();
    DateTime start = now.subtract(const Duration(days: 8));

    List<HealthDataType> types;
    if (Platform.isAndroid) {
      types = [HealthDataType.SLEEP_SESSION];
    } else {
      types = [
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
        HealthDataType.SLEEP_IN_BED,
      ];
    }

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

      // iOSの場合、連続した睡眠セグメントを統合する
      if (!Platform.isAndroid) {
        sleepData = _consolidateSleepData(sleepData);
        print("I/flutter: 統合後の睡眠データ件数: ${sleepData.length}");
      }

      return sleepData;
    } catch (e) {
      print("I/flutter: 睡眠データの取得中にエラーが発生: $e");
      return [];
    }
  }

  /// iOSの睡眠データ統合処理
  ///
  /// 取得された睡眠データを、開始時刻でソートし、
  /// 連続している（または重複している）セッションを１つに統合します。
  /// gapThresholdMinutes で、終了と次の開始の差がこの分数以内なら同一セッションと判断します。
  List<HealthDataPoint> _consolidateSleepData(List<HealthDataPoint> data) {
    if (data.isEmpty) return [];

    // 開始時刻でソート（古い順）
    data.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));

    List<HealthDataPoint> consolidated = [];
    // currentに最初のデータを設定
    HealthDataPoint current = data.first;
    const int gapThresholdMinutes = 15; // 15分以内なら連続と見なす

    for (int i = 1; i < data.length; i++) {
      HealthDataPoint next = data[i];
      // nextの開始がcurrentの終了からgapThresholdMinutes以内なら連続
      if (next.dateFrom.difference(current.dateTo).inMinutes <=
          gapThresholdMinutes) {
        // 終了時刻はcurrentとnextのうち、より遅い方を採用する
        DateTime newEnd =
            current.dateTo.isAfter(next.dateTo) ? current.dateTo : next.dateTo;
        // currentの開始はそのままで、終了時刻を更新
        current = HealthDataPoint(
          uuid: current.uuid, // 必要に応じて新たなUUID生成も検討可能
          value: current.value,
          type: current.type,
          unit: current.unit,
          dateFrom: current.dateFrom,
          dateTo: newEnd,
          sourcePlatform: current.sourcePlatform,
          sourceDeviceId: current.sourceDeviceId,
          sourceId: current.sourceId,
          sourceName: current.sourceName,
          recordingMethod: current.recordingMethod,
          metadata: current.metadata,
        );
      } else {
        // 閾値を超える場合は current を結果リストに追加し、next を新たな current とする
        consolidated.add(current);
        current = next;
      }
    }
    // 最後のセッションを追加
    consolidated.add(current);
    return consolidated;
  }
}
