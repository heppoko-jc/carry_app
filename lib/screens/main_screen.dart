import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
// 他のファイルで定義した HealthService / GameService を使用
import '../services/health_service.dart';
import '../services/game_service.dart';

class MainScreen extends StatefulWidget {
  /// 初期設定画面 (InitSetupScreen) から渡されるデータ
  ///  - sleepData:  初回起動時に取得した過去7~8日分の睡眠データ (省略可能)
  ///  - recentMatches: 同じく初回起動時に取得したマッチ情報 (省略可能)
  final List<HealthDataPoint>? sleepData;
  final List<Map<String, dynamic>>? recentMatches;

  /// WebCarry や Riot認証で取得した各種情報 (表示目的)
  final String? sessionKey;
  final String? riotPUUID;
  final String? riotGameName;
  final String? riotTagLine;

  const MainScreen({
    super.key,
    this.sleepData,
    this.recentMatches,
    this.sessionKey,
    this.riotPUUID,
    this.riotGameName,
    this.riotTagLine,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 2回目以降にも再取得したいので、HealthService / GameService をインスタンス化
  final HealthService _healthService = HealthService();
  final GameService _gameService = GameService();

  // 「画面表示用のデータ」を保持する変数
  // 初回起動時に引数からコピーし、2回目以降は run-time で再取得したデータを再セット
  List<HealthDataPoint> _sleepData = [];
  List<Map<String, dynamic>> _recentMatches = [];

  // 「画面下部」で表示するセッションキー・PUUID を保持
  // ここに SharedPreferences からの読み込み結果を代入する
  String? _sessionKey;
  String? _puuid;

  // 読み込み中フラグ
  bool _isLoading = false;

  // 日付切り替え用
  late List<DateTime> _dates; // 前日〜7日前の日付をまとめたもの
  int _dayIndex = 0; // 0 => 最も新しい日(前日), 6 => 最も古い日(7日前)

  @override
  void initState() {
    super.initState();

    // ① 初期設定画面から渡されたデータ(一度だけ受け取る)
    if (widget.sleepData != null) {
      _sleepData = widget.sleepData!;
    }
    if (widget.recentMatches != null) {
      _recentMatches = widget.recentMatches!;
    }

    // ② セッションキー / puuid も初回用をコピー
    _sessionKey = widget.sessionKey;
    _puuid = widget.riotPUUID;

    // ③ 日付リスト(前日〜7日前)を作る
    _setupDates();

    // ④ 2回目以降 or 毎起動時に Sleep & Match を再取得して更新
    _fetchAllData();
  }

  /// 前日〜7日前の日付リストを作る
  /// 例: 今日が3/17 → 前日は3/16 → そこから 3/16,15,14,13,12,11,10 の順で _dates に格納
  void _setupDates() {
    final now = DateTime.now();
    // 前日(今日の 00:00 から1日引く)
    final end = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));

    _dates = [];
    for (int i = 0; i < 7; i++) {
      _dates.add(end.subtract(Duration(days: i)));
    }
    // _dates[0]が最も新しい日(3/16), _dates[6]が最も古い日(3/10)など
    _dayIndex = 0;
  }

  /// 2回目以降でも SleepData & MatchData を都度再取得する
  ///  (初回時: もうすでに widget.* で渡されているが、再取得で最新化する)
  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);

    // SharedPreferences から session_key, riot_puuid を読み取り
    final prefs = await SharedPreferences.getInstance();
    _sessionKey = prefs.getString('session_key') ?? _sessionKey;
    _puuid = prefs.getString('riot_puuid') ?? _puuid;

    // ① HealthService: 権限リクエスト → 過去(8日ぶん)の睡眠を取得
    final authorized = await _healthService.requestPermissions();
    if (authorized) {
      final newSleepData = await _healthService.fetchSleepData();
      setState(() {
        _sleepData = newSleepData;
      });
    }

    // ② GameService: _puuid があれば 1週間分のマッチを取得
    if (_puuid != null && _puuid!.isNotEmpty) {
      final newMatches = await _gameService.getRecentMatches(_puuid!);
      setState(() {
        _recentMatches = newMatches;
      });
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    // 現在選択されている日付
    final date = currentDate;
    // 文字列
    final dateStr = currentDateString;

    // 指定日の睡眠/マッチを絞り込み
    final sleepsOfDay = _filterSleepData(date);
    final matchesOfDay = _filterMatchData(date);

    return Scaffold(
      appBar: AppBar(title: const Text("Carry App - Main Screen")),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ＜日付切り替えUI＞
                    _buildDateNavigator(),

                    const SizedBox(height: 20),

                    // 日付別 睡眠データ
                    Text(
                      "【$dateStr】の睡眠データ",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (sleepsOfDay.isEmpty)
                      const Text("睡眠データなし")
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:
                            sleepsOfDay.map((pt) {
                              final start = pt.dateFrom.toLocal();
                              final end = pt.dateTo.toLocal();
                              return Text("開始: $start, 終了: $end");
                            }).toList(),
                      ),
                    const SizedBox(height: 20),

                    // 日付別 マッチデータ
                    Text(
                      "【$dateStr】のマッチ情報",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (matchesOfDay.isEmpty)
                      const Text("マッチ情報なし")
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: matchesOfDay.map(_buildMatchItem).toList(),
                      ),

                    const SizedBox(height: 30),
                    const Divider(),

                    // 画面下部にセッションキー/PUUID/その他表示
                    Text("セッションキー: ${_sessionKey ?? '未取得'}"),
                    Text("PUUID: ${_puuid ?? '未取得'}"),
                    Text("Game Name: ${widget.riotGameName ?? '未取得'}"),
                    Text("Tag Line: ${widget.riotTagLine ?? '未取得'}"),
                  ],
                ),
              ),
    );
  }

  /// 日付ナビゲーション (＜＞) ボタン
  Widget _buildDateNavigator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 左(＜) => _dayIndex++ => より過去の日付へ
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed:
              _dayIndex >= 6
                  ? null
                  : () {
                    setState(() {
                      _dayIndex++;
                    });
                  },
        ),

        // 選択中の日付(yyyy-mm-dd)
        Text(
          currentDateString,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        // 右(＞) => _dayIndex-- => より新しい日付へ
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed:
              _dayIndex <= 0
                  ? null
                  : () {
                    setState(() {
                      _dayIndex--;
                    });
                  },
        ),
      ],
    );
  }

  /// 現在の日付 (0番目 => 前日, 6番目 => 1週間前)
  DateTime get currentDate => _dates[_dayIndex];

  /// 日付の文字列表現
  String get currentDateString {
    final d = currentDate;
    return "${d.year}-${_twoDigits(d.month)}-${_twoDigits(d.day)}";
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  /// 指定日の「終了日時が date の睡眠データ」だけを抽出
  List<HealthDataPoint> _filterSleepData(DateTime date) {
    return _sleepData.where((pt) {
      final end = pt.dateTo.toLocal();
      return (end.year == date.year &&
          end.month == date.month &&
          end.day == date.day);
    }).toList();
  }

  /// 指定日の「開始日時が date のマッチ情報」だけを抽出
  List<Map<String, dynamic>> _filterMatchData(DateTime date) {
    return _recentMatches.where((m) {
      final startMs = m["gameStartMillis"] as int? ?? 0;
      final startDt = DateTime.fromMillisecondsSinceEpoch(startMs).toLocal();
      return (startDt.year == date.year &&
          startDt.month == date.month &&
          startDt.day == date.day);
    }).toList();
  }

  /// マッチ情報の個別表示
  Widget _buildMatchItem(Map<String, dynamic> match) {
    final matchId = match["matchId"] ?? "";
    final mapId = match["mapId"] ?? "";
    final gameMode = match["gameMode"] ?? "";
    final startMs = match["gameStartMillis"] as int? ?? 0;
    final lengthMs = match["gameLengthMillis"] as int? ?? 0;

    final startTime = DateTime.fromMillisecondsSinceEpoch(startMs).toLocal();
    final lengthMin = (lengthMs / 60000).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("matchId: $matchId"),
          Text("  map: $mapId, mode: $gameMode"),
          Text("  start: $startTime"),
          Text("  length: $lengthMin 分"),
        ],
      ),
    );
  }
}
