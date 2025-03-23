import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/health_service.dart';
import '../services/game_service.dart';
import '../services/sleep_data_service.dart';
import '../services/game_data_service.dart';

/// アプリの通常時にデータを同期（増分送信）するためのサービス
/// - 前回同期日時 (lastSyncedTime) から現在までに“終了した”新しいデータを送信
/// - ヘルス権限がなければ睡眠同期はスキップ
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

  /// 増分同期
  /// 1) SharedPreferencesから lastSyncedTime を読み込む (なければ7日前)
  /// 2) Health権限をリクエスト → OKなら睡眠データを取得→終了時刻でnew判定→送信
  /// 3) riot_puuid を読み出し→マッチ情報  →終了時刻でnew判定→送信
  /// 4) lastSyncedTime = now に更新
  Future<void> syncIncremental() async {
    print("=== [NormalSync] 開始 ===");

    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt('lastSyncedTime');

    DateTime lastSyncedTime;
    if (lastMs == null) {
      lastSyncedTime = DateTime.now().subtract(const Duration(days: 7));
      print("■ 初回同期: lastSyncedTime を 7日前($lastSyncedTime) に設定");
    } else {
      lastSyncedTime = DateTime.fromMillisecondsSinceEpoch(lastMs);
      print("■ 前回同期日時: $lastSyncedTime");
    }

    final now = DateTime.now();
    print("■ 今回の同期基準(now): $now");

    // ========================================================
    // 1) ヘルス権限 → OKなら睡眠データ取得して送信
    // ========================================================
    final authorized = await _healthService.requestPermissions();
    if (!authorized) {
      print("⚠️ [NormalSync] Health権限がないため、睡眠データ同期をスキップします。");
    } else {
      // 1-1) 全量(過去7日など)を取得
      final allSleeps = await _healthService.fetchSleepData();
      print("◇ 全睡眠データ数(allSleeps) => ${allSleeps.length}");

      // 1-2) "終了時刻"が lastSyncedTime～now のみ送信対象
      final newSleep =
          allSleeps.where((dp) {
            final endTime = dp.dateTo;
            return endTime.isAfter(lastSyncedTime) && endTime.isBefore(now);
          }).toList();
      print("◇ 同期対象(睡眠) => ${newSleep.length}件");

      if (newSleep.isNotEmpty) {
        final ok = await _sleepDataService.sendSleepData(newSleep);
        if (ok) {
          print("✅ [NormalSync] 睡眠データ送信成功 => ${newSleep.length}件");
        } else {
          print("❌ [NormalSync] 睡眠データ送信失敗...");
        }
      } else {
        print("⚠️ [NormalSync] 新しい睡眠データは 0 件、スキップ。");
      }
    }

    // ========================================================
    // 2) ゲームデータ(riot_puuid) → マッチ情報同期
    // ========================================================
    final riotPuuid = prefs.getString('riot_puuid') ?? '';
    if (riotPuuid.isEmpty) {
      print("⚠️ [NormalSync] riot_puuidが未設定、マッチ同期をスキップ");
    } else {
      final allMatches = await _gameService.getRecentMatches(riotPuuid);
      print("◇ 全マッチデータ数(1週間) => ${allMatches.length}");

      // 2-1) 開始+長さ => 終了時刻で判定
      final newMatches =
          allMatches.where((m) {
            final startMs = m["gameStartMillis"] as int? ?? 0;
            final lengthMs = m["gameLengthMillis"] as int? ?? 0;
            final startDt = DateTime.fromMillisecondsSinceEpoch(startMs);
            final endDt = startDt.add(Duration(milliseconds: lengthMs));
            return endDt.isAfter(lastSyncedTime) && endDt.isBefore(now);
          }).toList();
      print("◇ 同期対象(マッチ) => ${newMatches.length}件");

      // 2-2) 送信( gametime & matchDetail )
      if (newMatches.isNotEmpty) {
        for (var match in newMatches) {
          // ゲーム時間
          await _gameDataService.sendGameTime(
            gameStartMillis: match["gameStartMillis"] ?? 0,
            gameLengthMillis: match["gameLengthMillis"] ?? 0,
            gameName: "valorant",
          );
          // マッチ詳細
          await _gameDataService.sendMatchDetail(match);
        }
        print("✅ [NormalSync] ${newMatches.length}件のマッチ情報を送信しました");
      } else {
        print("⚠️ [NormalSync] 新しいマッチデータは 0 件、スキップ。");
      }
    }

    // ========================================================
    // 3) lastSyncedTime を更新して終了
    // ========================================================
    prefs.setInt('lastSyncedTime', now.millisecondsSinceEpoch);
    print("✅ [NormalSync] 同期完了、lastSyncedTime を $now に更新");
    print("=== [NormalSync] 終了 ===");
  }
}
