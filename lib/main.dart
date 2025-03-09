import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final Health health = Health();
  List<HealthDataPoint> _sleepData = [];
  bool _isLoading = false;
  bool _isAuthorized = false;
  String? _sessionKey;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _initializeHealth();
    _loadSessionKey();
  }

  /// **Health Connect / Apple Health の権限をリクエスト**
  Future<void> _initializeHealth() async {
    setState(() => _isLoading = true);
    _addLog("I/flutter: 権限リクエスト開始...");

    if (Platform.isAndroid &&
        await Permission.activityRecognition.request().isDenied) {
      _addLog("I/flutter: ACTIVITY_RECOGNITION の権限が拒否されました");
      setState(() => _isLoading = false);
      return;
    }

    List<HealthDataType> types =
        Platform.isAndroid
            ? [
              HealthDataType.SLEEP_ASLEEP,
              HealthDataType.SLEEP_AWAKE,
              HealthDataType.SLEEP_SESSION,
            ]
            : [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_AWAKE];

    bool? hasPermissions = await health.hasPermissions(types);
    if (hasPermissions == true) {
      _addLog("I/flutter: 既に Health Connect / Apple Health の権限があります");
      setState(() => _isAuthorized = true);
      await fetchSleepData();
      return;
    }

    bool requested = await health.requestAuthorization(types);
    if (!requested) {
      _addLog("I/flutter: Health Connect / HealthKit の権限リクエストが拒否されました");
      setState(() {
        _isAuthorized = false;
        _isLoading = false;
      });
      return;
    }

    _addLog("I/flutter: Health Connect / HealthKit の権限が付与されました");
    setState(() => _isAuthorized = true);
    await fetchSleepData();
  }

  /// **過去 7 日間の睡眠データを取得**
  Future<void> fetchSleepData() async {
    setState(() => _isLoading = true);
    DateTime now = DateTime.now();
    DateTime start = now.subtract(const Duration(days: 7));

    _addLog("I/flutter: 睡眠データの取得を開始...");
    try {
      List<HealthDataType> types =
          Platform.isAndroid
              ? [
                HealthDataType.SLEEP_ASLEEP,
                HealthDataType.SLEEP_AWAKE,
                HealthDataType.SLEEP_SESSION,
              ]
              : [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_AWAKE];

      List<HealthDataPoint> sleepData = await health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: types,
      );

      if (sleepData.isEmpty) {
        _addLog("I/flutter: 取得した睡眠データは空です");
      } else {
        _addLog("I/flutter: 取得成功 - ${sleepData.length} 件のデータ");
      }

      setState(() {
        _sleepData = sleepData;
        _isLoading = false;
      });
    } catch (e) {
      _addLog("I/flutter: 睡眠データの取得中にエラーが発生: $e");
      setState(() => _isLoading = false);
    }
  }

  /// **セッションキーを保存**
  Future<void> _saveSessionKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_key', key);
    setState(() {
      _sessionKey = key;
    });
  }

  /// **セッションキーを読み込む**
  Future<void> _loadSessionKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _sessionKey = prefs.getString('session_key'));
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
                        await _saveSessionKey(token);
                      }
                    },
                    child: const Text("セッションキーを取得"),
                  ),
                  const SizedBox(height: 10),
                  Text("セッションキー: ${_sessionKey ?? '未取得'}"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// **WebView でセッションキーを取得**
class SessionKeyWebView extends StatefulWidget {
  const SessionKeyWebView({super.key});

  @override
  _SessionKeyWebViewState createState() => _SessionKeyWebViewState();
}

class _SessionKeyWebViewState extends State<SessionKeyWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (String url) {
                if (url.contains("generated-token=")) {
                  final Uri uri = Uri.parse(url);
                  final String? token = uri.queryParameters["generated-token"];
                  if (token != null) {
                    Navigator.pop(context, token);
                  }
                }
              },
            ),
          )
          ..loadRequest(
            Uri.parse(
              "https://milc.dev.sharo-dev.com/?app=account&dialog=registerNewApp&newApp=Carry-App",
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("セッションキー取得")),
      body: WebViewWidget(controller: _controller),
    );
  }
}
