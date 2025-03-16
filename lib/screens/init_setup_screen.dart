// init_setup_screen.dart (例)
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/session_service.dart';
import 'package:health/health.dart';
import '../services/api_service.dart';
import '../services/riot_auth_service.dart';
import '../services/health_service.dart';
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

  String? _sessionKey;
  String? _riotAccessToken;
  String? _riotPUUID;
  String? _riotGameName;
  String? _riotTagLine;

  // 過去7日間の睡眠データを保持
  List<HealthDataPoint> _sleepData = [];

  Future<void> _startSetup() async {
    setState(() => _isLoading = true);

    // 1. WebCarry セッションキー取得
    final String? sessionKey = await _sessionService.acquireSessionKey(context);
    if (sessionKey == null) {
      setState(() => _isLoading = false);
      return;
    }
    _sessionKey = sessionKey;

    // 2. ディレクトリ作成 & 権限付与
    final bool dirOk = await _apiService.initializeDirectories();
    if (!dirOk) {
      setState(() => _isLoading = false);
      return;
    }

    // 3. Riot認証
    final String? accessToken = await _riotAuthService.authenticate(context);
    if (accessToken == null) {
      setState(() => _isLoading = false);
      return;
    }
    _riotAccessToken = accessToken;

    // Riotアカウント情報取得
    final accountInfo = await _riotAuthService.getAccountInfo(accessToken);
    if (accountInfo != null) {
      _riotPUUID = accountInfo["puuid"];
      _riotGameName = accountInfo["gameName"];
      _riotTagLine = accountInfo["tagLine"];
    }

    // 4. 健康情報の取得フロー
    // 4-1. Health Connect / Apple Health の権限リクエスト
    final bool authorized = await _healthService.requestPermissions();
    if (!authorized) {
      setState(() => _isLoading = false);
      return;
    }

    // 4-2. 過去7日分の睡眠データを取得
    final sleepData = await _healthService.fetchSleepData();
    _sleepData = sleepData;

    // 5. SharedPreferencesなどに必要なデータを保存
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('session_key', _sessionKey!);
    prefs.setString('riot_puuid', _riotPUUID ?? '');
    prefs.setString('riot_gameName', _riotGameName ?? '');
    prefs.setString('riot_tagLine', _riotTagLine ?? '');

    // 6. 初期設定完了
    prefs.setBool('isSetupComplete', true);

    setState(() => _isLoading = false);

    // 7. メイン画面へ遷移 (睡眠データを渡す)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (_) => MainScreen(
              sleepData: _sleepData,
              sessionKey: _sessionKey,
              riotPUUID: _riotPUUID,
              riotGameName: _riotGameName,
              riotTagLine: _riotTagLine,
            ),
      ),
    );
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
