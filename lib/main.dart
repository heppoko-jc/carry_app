import 'dart:async';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:carry_app/services/health_service.dart';
import 'package:carry_app/services/session_service.dart';
import 'package:carry_app/services/api_service.dart';

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

  List<String> _logs = [];
  List<String> _apiLogs = [];
  List<HealthDataPoint> _sleepData = [];
  bool _isLoading = false;
  String? _sessionKey;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  /// **初期化**
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
      _apiLogs.addAll(_apiService.logs); // APIログを追加
    });
  }

  /// **ログを追加**
  void _addLog(String message) {
    setState(() {
      _logs.add(message);
      if (_logs.length > 10) _logs.removeAt(0);
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
                      "日付: ${data.dateFrom.toLocal().toString().split(' ')[0]}, 開始: ${data.dateFrom.toLocal().toString().split(' ')[1]}, 終了: ${data.dateTo.toLocal().toString().split(' ')[1]}",
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "ログ",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  ..._logs.map(
                    (log) => Text(log, style: const TextStyle(fontSize: 12)),
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
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: initializeApi,
                    child: const Text("API初期設定"),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "APIログ",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  ..._apiLogs.map(
                    (log) => Text(log, style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
