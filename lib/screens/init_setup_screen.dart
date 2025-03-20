import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 以下はアプリ内の各種サービスファイル
import '../services/session_service.dart';
import 'package:health/health.dart'; // Apple Health / Google Health Connect
import '../services/api_service.dart'; // carryディレクトリ構成関連
import '../services/riot_auth_service.dart'; // Riot認証
import '../services/health_service.dart'; // ヘルスデータ取得
import '../services/game_service.dart'; // Riotマッチデータ取得
import '../services/sleep_data_service.dart'; // WebCarry へ睡眠データ送信

import 'main_screen.dart';

/// 初回起動時の初期設定画面
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

  // セッションキーや RiotAPI 情報など
  String? _sessionKey;
  String? _riotAccessToken;
  String? _riotPUUID;
  String? _riotGameName;
  String? _riotTagLine;

  // 過去7日間の睡眠データ
  List<HealthDataPoint> _sleepData = [];

  // 直近1週間のマッチ情報
  List<Map<String, dynamic>> _recentMatches = [];

  /// **初期フロー開始**
  Future<void> _startSetup() async {
    setState(() => _isLoading = true);

    try {
      // (1) WebCarryセッションキーを取得 (例: WebViewでユーザーがログイン)
      final String? sessionKey = await _sessionService.acquireSessionKey(
        context,
      );
      if (sessionKey == null) {
        // ユーザーが中断したなど
        setState(() => _isLoading = false);
        return;
      }
      _sessionKey = sessionKey;

      // (2) ディレクトリ作成 & 権限付与
      final bool dirOk = await _apiService.initializeDirectories();
      if (!dirOk) {
        setState(() => _isLoading = false);
        return;
      }

      // (3) Riot認証
      final String? accessToken = await _riotAuthService.authenticate(context);
      if (accessToken == null) {
        setState(() => _isLoading = false);
        return;
      }
      _riotAccessToken = accessToken;

      // 3-1. アカウント情報取得
      final accountInfo = await _riotAuthService.getAccountInfo(accessToken);
      if (accountInfo != null) {
        _riotPUUID = accountInfo["puuid"];
        _riotGameName = accountInfo["gameName"];
        _riotTagLine = accountInfo["tagLine"];
      }

      // (4) 健康情報の取得
      // 4-1. 権限リクエスト
      final bool authorized = await _healthService.requestPermissions();
      if (!authorized) {
        setState(() => _isLoading = false);
        return;
      }

      // 4-2. 過去7日分の睡眠データを取得
      final sleepData = await _healthService.fetchSleepData();
      _sleepData = sleepData;

      // (5) VALORANTのマッチ情報を直近1週間分取得
      if (_riotPUUID != null && _riotPUUID!.isNotEmpty) {
        final matches = await _gameService.getRecentMatches(_riotPUUID!);
        _recentMatches = matches;
      }

      // (6) 一週間の睡眠データを WebCarry に送信
      //     例: SleepDataService.sendSleepData(_sleepData)
      final bool sendOk = await _sleepDataService.sendSleepData(_sleepData);
      if (!sendOk) {
        // 送信失敗時のログなど
        print("❌ 一週間の睡眠データ送信に失敗");
      } else {
        print("✅ 一週間の睡眠データ送信成功");
      }

      // (7) SharedPreferencesなどに必要情報を保存
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('session_key', _sessionKey!);
      prefs.setString('riot_puuid', _riotPUUID ?? '');
      prefs.setString('riot_gameName', _riotGameName ?? '');
      prefs.setString('riot_tagLine', _riotTagLine ?? '');

      // 初期設定完了フラグ
      prefs.setBool('isSetupComplete', true);

      setState(() => _isLoading = false);

      // (8) メイン画面へ遷移
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
      print("❌ 初期設定中に例外発生: $e");
      setState(() => _isLoading = false);
      // エラーUI表示など適宜
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
