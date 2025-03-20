import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health/health.dart';

class SleepDataService {
  final String baseUrl = "https://milc.dev.sharo-dev.com";

  List<String> logs = [];

  void _addLog(String message) {
    logs.add(message);
    print(message);
  }

  /// セッションキー取得
  Future<String?> _getSessionKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('session_key');
  }

  /// health ディレクトリの ID を検索 (初期フローで既に作成済み)
  Future<int?> _findHealthDirId() async {
    final sessionKey = await _getSessionKey();
    if (sessionKey == null) {
      _addLog("❌ セッションキーがありません");
      return null;
    }

    // 1) health ディレクトリを検索
    //    /contents/item/search?app=carry&key=health&type=dir
    final response = await http.get(
      Uri.parse("$baseUrl/contents/item/search?app=carry&key=health&type=dir"),
      headers: {"apikey": sessionKey},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      if (data.isNotEmpty) {
        final int healthId = data.first["id"];
        _addLog("✅ 取得した HealthディレクトリID: $healthId");
        return healthId;
      }
      _addLog("❌ healthディレクトリが存在しません");
    } else {
      _addLog("❌ healthディレクトリ検索失敗 code=${response.statusCode}");
    }
    return null;
  }

  /// sleep データエントリID を検索 or 作成
  /// body: {...}, key="sleep", name="sleep", parent=healthId, type="data"
  Future<int?> _findOrCreateSleepDataEntry(int healthId) async {
    final sessionKey = await _getSessionKey();
    if (sessionKey == null) {
      _addLog("❌ セッションキーがありません");
      return null;
    }

    // すでに "sleep" という data entry があるか?
    final searchUrl =
        "$baseUrl/contents/item/search?app=carry&key=sleep&type=data&parent=$healthId";
    final searchRes = await http.get(
      Uri.parse(searchUrl),
      headers: {"apikey": sessionKey},
    );

    if (searchRes.statusCode == 200) {
      final List<dynamic> items = json.decode(searchRes.body);
      if (items.isNotEmpty) {
        final int dataEntryId = items.first["id"];
        _addLog("✅ sleepデータエントリのID: $dataEntryId");
        return dataEntryId;
      } else {
        _addLog("sleepデータエントリが存在しないので作成します...");
      }
    } else {
      _addLog("❌ sleepデータエントリ検索失敗 code=${searchRes.statusCode}");
      return null;
    }

    // 作成
    final createUrl = "$baseUrl/contents/item/add";
    final createBody = {
      "name": "sleep",
      "app": "carry",
      "key": "sleep",
      "type": "data",
      "meta": {},
      "parent": healthId,
    };
    final createRes = await http.post(
      Uri.parse(createUrl),
      headers: {"Content-Type": "application/json", "apikey": sessionKey},
      body: json.encode(createBody),
    );

    if (createRes.statusCode == 200) {
      final Map<String, dynamic> respData = json.decode(createRes.body);
      final int newId = respData["id"];
      _addLog("✅ sleepデータエントリを新規作成: ID=$newId");
      return newId;
    } else {
      _addLog("❌ sleepデータエントリの作成に失敗 code=${createRes.statusCode}");
      return null;
    }
  }

  /// 一週間の SleepData を送信
  /// - すでに health ディレクトリが初期設定で作られている前提
  /// - "sleep" data entry に state.add
  Future<bool> sendSleepData(List<HealthDataPoint> weekOfSleeps) async {
    // 1) health ディレクトリのIDを検索
    final healthId = await _findHealthDirId();
    if (healthId == null) return false;

    // 2) sleep data entry
    final sleepEntryId = await _findOrCreateSleepDataEntry(healthId);
    if (sleepEntryId == null) return false;

    // 3) データ変換
    //    datetime= dateFrom(UNIX ms), duration= (dateTo - dateFrom) ms
    List<Map<String, dynamic>> states = [];
    for (var dp in weekOfSleeps) {
      final startMs = dp.dateFrom.millisecondsSinceEpoch;
      final durationMs = dp.dateTo.difference(dp.dateFrom).inMilliseconds;
      states.add({"datetime": startMs, "duration": durationMs});
    }

    final sessionKey = await _getSessionKey();
    if (sessionKey == null) return false;

    final url = "$baseUrl/contents/item/$sleepEntryId/state/add";
    final res = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json", "apikey": sessionKey},
      body: json.encode(states),
    );

    if (res.statusCode == 200) {
      _addLog("✅ 一週間の睡眠データ送信成功！ [${states.length}件]");
      _addLog("レスポンス: ${res.body}");
      return true;
    } else {
      _addLog("❌ 一週間睡眠データ送信失敗 code=${res.statusCode} body=${res.body}");
      return false;
    }
  }
}
