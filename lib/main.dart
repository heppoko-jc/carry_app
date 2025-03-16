import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:carry_app/services/health_service.dart';
import 'package:carry_app/services/session_service.dart';
import 'package:carry_app/services/api_service.dart';
import 'package:carry_app/services/sleep_data_service.dart';
import 'package:carry_app/services/game_service.dart';
import 'package:carry_app/services/riot_auth_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CarryAppScreen(),
    );
  }
}

class CarryAppScreen extends StatefulWidget {
  const CarryAppScreen({super.key});

  @override
  _CarryAppScreenState createState() => _CarryAppScreenState();
}

class _CarryAppScreenState extends State<CarryAppScreen> {
  final HealthService _healthService = HealthService();
  final SessionService _sessionService = SessionService();
  final ApiService _apiService = ApiService();
  final SleepDataService _sleepDataService = SleepDataService();
  final GameService _gameService = GameService();
  final RiotAuthService _riotAuthService = RiotAuthService();

  List<String> _logs = [];
  List<String> _apiLogs = [];
  List<String> _gameLogs = [];
  List<HealthDataPoint> _sleepData = [];
  bool _isLoading = false;
  String? _sessionKey;

  // ゲーム情報取得用の変数
  String _gameName = "";
  String _tagLine = "";
  String? _puuid;
  List<String> _matchIds = [];
  String? _latestMatchId;
  Map<String, dynamic>? _matchInfo;

  // Riot認証情報
  String? _riotAccessToken;
  String? _riotPUUID;
  String? _riotGameName;
  String? _riotTagLine;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  /// **初期化処理**
  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    bool authorized = await _healthService.requestPermissions();
    if (authorized) await fetchSleepData();
    _sessionKey = await _sessionService.loadSessionKey();
    setState(() => _isLoading = false);
  }

  /// **睡眠データを取得**
  Future<void> fetchSleepData() async {
    setState(() => _isLoading = true);
    List<HealthDataPoint> sleepData = await _healthService.fetchSleepData();
    setState(() {
      _sleepData = sleepData;
      _isLoading = false;
    });
  }

  /// **APIの初期設定**
  Future<void> initializeApi() async {
    setState(() => _apiLogs = ["API 初期設定開始..."]);
    bool success = await _apiService.initializeDirectories();
    setState(() {
      _apiLogs.add(success ? "API 初期設定成功！" : "API 初期設定失敗...");
      _apiLogs.addAll(_apiService.logs);
    });
  }

  /// **睡眠データをWebCarryに送信**
  Future<void> sendSleepData() async {
    setState(() => _apiLogs.add("睡眠データ送信中..."));
    bool success = await _sleepDataService.sendSleepData(_sleepData);
    setState(() {
      _apiLogs.add(success ? "睡眠データ送信成功！" : "睡眠データ送信失敗...");
    });
  }

  /// **ゲーム情報を取得**
  Future<void> fetchGameInfo() async {
    setState(() {
      _gameLogs = ["🎮 ゲーム情報取得開始..."];
    });

    if (_gameName.isEmpty || _tagLine.isEmpty) {
      _addGameLog("❌ ゲームネームとタグラインを入力してください。");
      return;
    }

    String? puuid = await _gameService.getPUUID(_gameName, _tagLine);
    if (puuid == null) return;

    List<String>? matchIds = await _gameService.getMatchList(puuid);
    if (matchIds == null || matchIds.isEmpty) return;

    _matchIds = matchIds;
    _latestMatchId = matchIds.first;

    Map<String, dynamic>? matchInfo = await _gameService.getMatchInfo(
      _latestMatchId!,
    );
    if (matchInfo != null) {
      _matchInfo = matchInfo;
    }

    setState(() {
      _gameLogs.addAll(_gameService.logs);
    });
  }

  /// **Riot認証**
  Future<void> authenticateWithRiot() async {
    String? accessToken = await _riotAuthService.authenticate(context);

    if (accessToken != null) {
      setState(() {
        _riotAccessToken = accessToken;
      });

      Map<String, dynamic>? riotUserInfo = await _riotAuthService
          .getAccountInfo(accessToken);
      if (riotUserInfo != null) {
        setState(() {
          _riotPUUID = riotUserInfo["puuid"];
          _riotGameName = riotUserInfo["gameName"];
          _riotTagLine = riotUserInfo["tagLine"];
        });
      }
    }
  }

  /// **ログを追加**
  void _addGameLog(String message) {
    setState(() {
      _gameLogs.add(message);
      if (_gameLogs.length > 10) _gameLogs.removeAt(0);
    });
    print(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Carry App")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            /// **ヘルスブロック**
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  const Text(
                    "ヘルスデータ",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton(
                    onPressed: fetchSleepData,
                    child: const Text("睡眠データを再取得"),
                  ),
                  const SizedBox(height: 10),
                  Text("取得データ: ${_sleepData.length}件"),
                  ..._sleepData.map(
                    (data) => Text(
                      "日付: ${data.dateFrom.toLocal()} - ${data.dateTo.toLocal()}",
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            /// **APIブロック**
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  const Text(
                    "API設定",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  /// **セッションキー取得ボタン**
                  ElevatedButton(
                    onPressed: () async {
                      String? token = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SessionKeyWebView(),
                        ),
                      );
                      if (token != null) {
                        await _sessionService.saveSessionKey(token);
                        setState(() => _sessionKey = token);
                      }
                    },
                    child: const Text("セッションキーを取得"),
                  ),
                  const SizedBox(height: 10),
                  Text("セッションキー: ${_sessionKey ?? '未取得'}"),

                  const SizedBox(height: 20),

                  /// **API 初期設定ボタン**
                  ElevatedButton(
                    onPressed: initializeApi,
                    child: const Text("API初期設定"),
                  ),

                  const SizedBox(height: 20),

                  /// **睡眠データ送信ボタン**
                  ElevatedButton(
                    onPressed: sendSleepData,
                    child: const Text("睡眠データを送信"),
                  ),

                  const SizedBox(height: 10),
                  const Text(
                    "APIログ",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  ..._apiLogs.map((log) => Text(log)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            /// **Gameブロック**
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orange, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  const Text(
                    "Game情報",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextField(
                    decoration: const InputDecoration(labelText: "ゲームネーム"),
                    onChanged: (value) => _gameName = value,
                  ),
                  TextField(
                    decoration: const InputDecoration(labelText: "タグライン"),
                    onChanged: (value) => _tagLine = value,
                  ),
                  ElevatedButton(
                    onPressed: fetchGameInfo,
                    child: const Text("マッチ情報を取得"),
                  ),
                  const SizedBox(height: 10),
                  const Text("マッチ情報"),
                  _matchInfo != null
                      ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("マップ: ${_matchInfo!["matchInfo"]["mapId"]}"),
                          Text(
                            "ゲームモード: ${_matchInfo!["matchInfo"]["gameMode"]}",
                          ),
                          ..._matchInfo!["players"].map<Widget>((player) {
                            return Text(
                              "${player["gameName"]} - K/D/A: ${player["stats"]["kills"]}/${player["stats"]["deaths"]}/${player["stats"]["assists"]}",
                            );
                          }).toList(),
                        ],
                      )
                      : const Text("マッチ情報なし"),
                  ..._gameLogs.map((log) => Text(log)),
                ],
              ),
            ),

            /// **Riotブロック**
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.purple, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  const Text(
                    "Riot Games 認証",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton(
                    onPressed: authenticateWithRiot,
                    child: const Text("Riot認証"),
                  ),
                  const SizedBox(height: 10),
                  Text("Access Token: ${_riotAccessToken ?? '未認証'}"),
                  Text("PUUID: ${_riotPUUID ?? '未取得'}"),
                  Text("Game Name: ${_riotGameName ?? '未取得'}"),
                  Text("Tag Line: ${_riotTagLine ?? '未取得'}"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
