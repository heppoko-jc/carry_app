import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health/health.dart';

import '../services/session_service.dart';
import '../services/api_service.dart';
import '../services/riot_auth_service.dart';
import '../services/health_service.dart';
import '../services/game_service.dart';
import '../services/sleep_data_service.dart';
import '../services/game_data_service.dart';

import '../screens/policy_screens.dart';

import 'home_root_screen.dart';

class InitSetupScreen extends StatefulWidget {
  const InitSetupScreen({Key? key}) : super(key: key);

  @override
  State<InitSetupScreen> createState() => _InitSetupScreenState();
}

class _InitSetupScreenState extends State<InitSetupScreen> {
  bool _isLoading = false;

  // サービス
  final SessionService _sessionService = SessionService();
  final ApiService _apiService = ApiService();
  final RiotAuthService _riotAuthService = RiotAuthService();
  final HealthService _healthService = HealthService();
  final GameService _gameService = GameService();
  final SleepDataService _sleepDataService = SleepDataService();
  final GameDataService _gameDataService = GameDataService();

  // 取得したデータ格納用
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
      // (0) 利用規約の表示と同意
      bool? termsAgreed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder:
              (context) =>
                  TermsScreen(onNext: () => Navigator.pop(context, true)),
        ),
      );
      if (termsAgreed != true) {
        setState(() => _isLoading = false);
        return;
      }

      // (0.1) 研究同意書の表示と同意
      bool? consentAgreed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder:
              (context) =>
                  ConsentScreen(onNext: () => Navigator.pop(context, true)),
        ),
      );
      if (consentAgreed != true) {
        setState(() => _isLoading = false);
        return;
      }

      // (1) WebCarryセッションキー
      final sessionKey = await _sessionService.acquireSessionKey(context);
      if (sessionKey == null) {
        // ユーザーがキャンセル等
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

      // (3-1) アカウント情報取得
      final accountInfo = await _riotAuthService.getAccountInfo(accessToken);
      if (accountInfo != null) {
        _riotPUUID = accountInfo["puuid"];
        _riotGameName = accountInfo["gameName"];
        _riotTagLine = accountInfo["tagLine"];
      }

      // (4) Health権限 & 睡眠データ取得
      final authorized = await _healthService.requestPermissions();
      if (!authorized) {
        setState(() => _isLoading = false);
        return;
      }
      final sleepData = await _healthService.fetchSleepData();
      _sleepData = sleepData;

      // (5) ゲームマッチ情報
      if (_riotPUUID != null && _riotPUUID!.isNotEmpty) {
        final matches = await _gameService.getRecentMatches(_riotPUUID!);
        _recentMatches = matches;
      }

      // (6) Sleepデータ送信
      final sleepSendOk = await _sleepDataService.sendSleepData(_sleepData);
      if (!sleepSendOk) {
        print("❌ [InitSetup] 睡眠データ送信失敗");
      } else {
        print("✅ [InitSetup] 睡眠データ送信成功");
      }

      // (7) ゲーム情報送信
      //  (7-1) ユーザー情報
      if (_riotPUUID != null &&
          _riotPUUID!.isNotEmpty &&
          _riotGameName != null) {
        final userOk = await _gameDataService.sendUserInfo(
          puuid: _riotPUUID!,
          username: _riotGameName!,
          tagline: _riotTagLine ?? "",
        );
        if (!userOk) {
          print("❌ [InitSetup] ユーザー情報送信失敗");
        } else {
          print("✅ [InitSetup] ユーザー情報送信成功");
        }
      }
      //  (7-2) マッチ
      for (var m in _recentMatches) {
        final timeOk = await _gameDataService.sendGameTime(
          gameStartMillis: m["gameStartMillis"] ?? 0,
          gameLengthMillis: m["gameLengthMillis"] ?? 0,
          gameName: "valorant",
        );
        if (!timeOk) {
          print("❌ [InitSetup] gametime送信失敗 matchId=${m["matchId"]}");
        }

        final matchOk = await _gameDataService.sendMatchDetail(m);
        if (!matchOk) {
          print("❌ [InitSetup] match情報送信失敗 matchId=${m["matchId"]}");
        }
      }

      // (8) SharedPreferences保存 (あとで通常同期などで使用可能)
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('session_key', _sessionKey!);
      prefs.setString('riot_puuid', _riotPUUID ?? '');
      prefs.setString('riot_gameName', _riotGameName ?? '');
      prefs.setString('riot_tagLine', _riotTagLine ?? '');
      prefs.setString('riotAccessToken', _riotAccessToken ?? '');
      prefs.setBool('isSetupComplete', true);

      // (8-1) 初回同期日時を記録 => 通常同期/増分同期の基準時刻
      final now = DateTime.now();
      prefs.setInt('lastSyncedTime', now.millisecondsSinceEpoch);
      print("✅ [InitSetup] 初回同期日時: $now に設定");

      setState(() => _isLoading = false);

      // (9) HomeRootScreen に遷移し、初期フローで取得したデータをそのまま渡す
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => HomeRootScreen(
                // ↓ コンストラクタに受け取り用パラメータを作り、渡す
                initSleepData: _sleepData,
                initMatches: _recentMatches,
              ),
        ),
      );
    } catch (e) {
      print("❌ [InitSetup] 初期設定中に例外発生: $e");
      setState(() => _isLoading = false);
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
