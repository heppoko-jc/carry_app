// lib/services/normal_sync_service.dart
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/health_service.dart';
import '../services/game_service.dart';
import '../services/sleep_data_service.dart';
import '../services/game_data_service.dart';

/// アプリの通常時にデータを同期（増分送信）するためのサービス
/// - 前回同期日時 (lastSyncedTime) から現在までの新データだけ取得し、送信する
class NormalSyncService {
  final HealthService _healthService;
  final GameService _gameService;
  final SleepDataService _sleepDataService;
  final GameDataService _gameDataService;

  NormalSyncService({
    required HealthService healthService,
    required GameService gameService,
    required SleepDataService sleepDataService,
    required GameDataService gameDataService,
  }) : _healthService = healthService,
       _gameService = gameService,
       _sleepDataService = sleepDataService,
       _gameDataService = gameDataService;

  /// 通常同期メソッド (増分同期)
  /// - 前回同期日時 ~ 現在 の範囲だけ 取得＆送信
  Future<void> syncIncremental() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt('lastSyncedTime');

    // もし前回同期日時がnullなら、初期同期扱い(7日前)
    DateTime lastSyncedTime;
    if (lastMs == null) {
      lastSyncedTime = DateTime.now().subtract(const Duration(days: 7));
    } else {
      lastSyncedTime = DateTime.fromMillisecondsSinceEpoch(lastMs);
    }
    final now = DateTime.now();

    // 1) 睡眠データの増分取得
    final allSleeps = await _healthService.fetchSleepData();
    // 例: fetchSleepData() は1週間分全部を返すなら、その中から lastSyncedTime ~ now でフィルタ
    final newSleep =
        allSleeps.where((dp) {
          final start = dp.dateFrom;
          // startが lastSyncedTimeより後 && nowより前
          return start.isAfter(lastSyncedTime) && start.isBefore(now);
        }).toList();

    if (newSleep.isNotEmpty) {
      final ok = await _sleepDataService.sendSleepData(newSleep);
      if (!ok) {
        print("❌ [NormalSync] 睡眠データ送信失敗");
      } else {
        print("✅ [NormalSync] ${newSleep.length}件の新しい睡眠データを送信しました");
      }
    }

    // 2) ゲームデータの増分取得
    // getRecentMatches() は1週間分をまとめて返す -> local filter
    final allMatches = await _gameService.getRecentMatches("PUUID_OF_USER");
    // PUUID_OF_USER は適宜呼び出し側から取得 or SharedPreferences などで管理
    final newMatches =
        allMatches.where((m) {
          final startMs = m["gameStartMillis"] as int? ?? 0;
          final startDt = DateTime.fromMillisecondsSinceEpoch(startMs);
          return startDt.isAfter(lastSyncedTime) && startDt.isBefore(now);
        }).toList();

    if (newMatches.isNotEmpty) {
      // newMatchesの各マッチについて gametime / matchDetailを送信
      for (var match in newMatches) {
        await _gameDataService.sendGameTime(
          gameStartMillis: match["gameStartMillis"] ?? 0,
          gameLengthMillis: match["gameLengthMillis"] ?? 0,
          gameName: "valorant",
        );
        await _gameDataService.sendMatchDetail(match);
      }
      print("✅ [NormalSync] ${newMatches.length}件の新しいマッチ情報を送信しました");
    }

    // 3) 同期完了 -> lastSyncedTimeを更新
    prefs.setInt('lastSyncedTime', now.millisecondsSinceEpoch);
    print("✅ [NormalSync] 同期完了。lastSyncedTimeを $now に更新");
  }
}
