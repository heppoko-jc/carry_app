// init_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/session_service.dart';
import 'package:health/health.dart';
import '../services/api_service.dart';
import '../services/riot_auth_service.dart';
import '../services/health_service.dart';
import '../services/game_service.dart';
import '../services/sleep_data_service.dart';
import '../services/game_data_service.dart';

import 'main_screen.dart';

class InitSetupScreen extends StatefulWidget {
  const InitSetupScreen({super.key});

  @override
  _InitSetupScreenState createState() => _InitSetupScreenState();
}

class _InitSetupScreenState extends State<InitSetupScreen> {
  bool _isLoading = false;

  final SessionService _sessionService = SessionService();
  final ApiService _apiService = ApiService();
  final RiotAuthService _riotAuthService = RiotAuthService();
  final HealthService _healthService = HealthService();
  final GameService _gameService = GameService();
  final SleepDataService _sleepDataService = SleepDataService();
  final GameDataService _gameDataService = GameDataService(); // ←追加

  String? _sessionKey;
  String? _riotAccessToken;
  String? _riotPUUID;
  String? _riotGameName;
  String? _riotTagLine;

  List<HealthDataPoint> _sleepData = [];
  List<Map<String, dynamic>> _recentMatches = [];

  Future<void> _startSetup() async {
    setState(() => _isLoading = true);

    try {
      // (1) セッションキー取得
      final sessionKey = await _sessionService.acquireSessionKey(context);
      if (sessionKey == null) {
        setState(() => _isLoading = false);
        return;
      }
      _sessionKey = sessionKey;

      // (2) ディレクトリ作成 & 権限付与
      final dirOk = await _apiService.initializeDirectories();
      if (!dirOk) {
        setState(() => _isLoading = false);
        return;
      }

      // (3) Riot認証
      final accessToken = await _riotAuthService.authenticate(context);
      if (accessToken == null) {
        setState(() => _isLoading = false);
        return;
      }
      _riotAccessToken = accessToken;

      // 3-1) アカウント情報を取得
      final accountInfo = await _riotAuthService.getAccountInfo(accessToken);
      if (accountInfo != null) {
        _riotPUUID = accountInfo["puuid"];
        _riotGameName = accountInfo["gameName"];
        _riotTagLine = accountInfo["tagLine"];
      }

      // (4) Health情報取得
      final authorized = await _healthService.requestPermissions();
      if (!authorized) {
        setState(() => _isLoading = false);
        return;
      }
      final sleepData = await _healthService.fetchSleepData();
      _sleepData = sleepData;

      // (5) ゲームのマッチ情報取得
      if (_riotPUUID != null && _riotPUUID!.isNotEmpty) {
        final matches = await _gameService.getRecentMatches(_riotPUUID!);
        _recentMatches = matches;
      }

      // (6) Sleepデータを WebCarry へ送信
      final sendOk = await _sleepDataService.sendSleepData(_sleepData);
      if (!sendOk) {
        print("❌ 睡眠データ送信失敗");
      } else {
        print("✅ 睡眠データ送信成功");
      }

      // (7) ゲーム情報送信 (ユーザー情報, マッチ時間, マッチ詳細)
      //    7-1) userInfo
      if (_riotPUUID != null &&
          _riotPUUID!.isNotEmpty &&
          _riotGameName != null) {
        final userOk = await _gameDataService.sendUserInfo(
          puuid: _riotPUUID!,
          username: _riotGameName!,
          tagline: _riotTagLine ?? "",
        );
        if (!userOk) {
          print("❌ ユーザー情報の送信失敗");
        } else {
          print("✅ ユーザー情報の送信成功");
        }
      }

      //    7-2) 各マッチの時間(gametime) と match詳細
      for (var m in _recentMatches) {
        // (a) gametime送信
        final gameTimeOk = await _gameDataService.sendGameTime(
          gameStartMillis: m["gameStartMillis"] ?? 0,
          gameLengthMillis: m["gameLengthMillis"] ?? 0,
          gameName: "valorant",
        );
        if (!gameTimeOk) {
          print("❌ gametime送信失敗 for matchId=${m["matchId"]}");
        }

        // (b) match詳細送信
        final matchOk = await _gameDataService.sendMatchDetail(m);
        if (!matchOk) {
          print("❌ match情報送信失敗 for matchId=${m["matchId"]}");
        }
      }

      // (8) SharedPreferencesに保存
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('session_key', _sessionKey!);
      prefs.setString('riot_puuid', _riotPUUID ?? '');
      prefs.setString('riot_gameName', _riotGameName ?? '');
      prefs.setString('riot_tagLine', _riotTagLine ?? '');
      prefs.setBool('isSetupComplete', true);

      // (8-1) "初回同期日時" として now を保存
      //       → 通常時の増分同期で使用 (normal_sync_service)
      final now = DateTime.now();
      prefs.setInt('lastSyncedTime', now.millisecondsSinceEpoch);
      print("✅ 初回同期日時を $now に設定");

      setState(() => _isLoading = false);

      // (9) MainScreenへ
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => MainScreen(
                sleepData: _sleepData,
                recentMatches: _recentMatches,
                sessionKey: _sessionKey,
                riotPUUID: _riotPUUID,
                riotGameName: _riotGameName,
                riotTagLine: _riotTagLine,
              ),
        ),
      );
    } catch (e) {
      print("❌ 初期設定中の例外: $e");
      setState(() => _isLoading = false);
      // エラー処理
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("初期設定")),
      body: Center(
        child:
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                  onPressed: _startSetup,
                  child: const Text("Carryを始める"),
                ),
      ),
    );
  }
}
