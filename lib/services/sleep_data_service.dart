import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health/health.dart';

class SleepDataService {
  final String baseUrl = "https://milc.dev.sharo-dev.com";
  List<String> logs = [];

  /// **ログを追加**
  void _addLog(String message) {
    logs.add(message);
    print(message); // ターミナルにも表示
  }

  /// **セッションキーを取得**
  Future<String?> _getSessionKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('session_key');
  }

  /// **CarryID を取得**
  Future<int?> _getCarryId() async {
    final String? sessionKey = await _getSessionKey();
    if (sessionKey == null) return null;

    final response = await http.get(
      Uri.parse("$baseUrl/contents/item/search?app=carry&type=dir&parent=0"),
      headers: {"apikey": sessionKey},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      if (data.isNotEmpty) {
        int carryId = data.first["id"];
        _addLog("✅ 取得した CarryID: $carryId");
        return carryId;
      }
    }
    _addLog("❌ CarryID の取得に失敗");
    return null;
  }

  /// **HealthID を取得**
  Future<int?> _getHealthId(int carryId) async {
    final String? sessionKey = await _getSessionKey();
    if (sessionKey == null) return null;

    final response = await http.get(
      Uri.parse(
        "$baseUrl/contents/item/search?app=carry&key=health&type=dir&parent=$carryId",
      ),
      headers: {"apikey": sessionKey},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      if (data.isNotEmpty) {
        int healthId = data.first["id"];
        _addLog("✅ 取得した HealthID: $healthId");
        return healthId;
      }
    }
    _addLog("❌ HealthID の取得に失敗");
    return null;
  }

  /// **SleepID を取得（なければ作成）**
  Future<int?> _getOrCreateSleepId(int healthId) async {
    final String? sessionKey = await _getSessionKey();
    if (sessionKey == null) return null;

    final response = await http.get(
      Uri.parse(
        "$baseUrl/contents/item/search?app=carry&key=sleep&type=dir&parent=$healthId",
      ),
      headers: {"apikey": sessionKey},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      if (data.isNotEmpty) {
        int sleepId = data.first["id"];
        _addLog("✅ 取得した SleepID: $sleepId");
        return sleepId;
      }
    }

    // Sleepディレクトリがない場合、新規作成
    final createResponse = await http.post(
      Uri.parse("$baseUrl/contents/item/add"),
      headers: {"Content-Type": "application/json", "apikey": sessionKey},
      body: json.encode({
        "name": "sleep",
        "app": "carry",
        "key": "sleep",
        "type": "dir",
        "meta": {},
        "parent": healthId,
      }),
    );

    if (createResponse.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(createResponse.body);
      int sleepId = data["id"];
      _addLog("✅ Sleep ディレクトリを新規作成: $sleepId");
      return sleepId;
    }

    _addLog("❌ Sleep ディレクトリの作成に失敗");
    return null;
  }

  /// **データエントリID を取得（なければ作成）**
  Future<int?> _getOrCreateDataEntryId(int sleepId) async {
    final String? sessionKey = await _getSessionKey();
    if (sessionKey == null) return null;

    final response = await http.get(
      Uri.parse(
        "$baseUrl/contents/item/search?app=carry&key=sleep&type=data&name=sleep&parent=$sleepId",
      ),
      headers: {"apikey": sessionKey},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      if (data.isNotEmpty) {
        int dataEntryId = data.first["id"];
        _addLog("✅ 取得したデータエントリID: $dataEntryId");
        return dataEntryId;
      }
    }

    // データエントリがない場合、新規作成
    final createResponse = await http.post(
      Uri.parse("$baseUrl/contents/item/add"),
      headers: {"Content-Type": "application/json", "apikey": sessionKey},
      body: json.encode({
        "name": "sleep",
        "app": "carry",
        "key": "sleep",
        "type": "data",
        "meta": {},
        "parent": sleepId,
      }),
    );

    if (createResponse.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(createResponse.body);
      int dataEntryId = data["id"];
      _addLog("✅ データエントリを新規作成: $dataEntryId");
      return dataEntryId;
    }

    _addLog("❌ データエントリの作成に失敗");
    return null;
  }

  /// **睡眠データを送信**
  Future<bool> sendSleepData(List<HealthDataPoint> sleepData) async {
    final int? carryId = await _getCarryId();
    if (carryId == null) return false;

    final int? healthId = await _getHealthId(carryId);
    if (healthId == null) return false;

    final int? sleepId = await _getOrCreateSleepId(healthId);
    if (sleepId == null) return false;

    final int? dataEntryId = await _getOrCreateDataEntryId(sleepId);
    if (dataEntryId == null) return false;

    final String? sessionKey = await _getSessionKey();
    if (sessionKey == null) return false;

    // データ変換
    List<Map<String, dynamic>> formattedData =
        sleepData.map((data) {
          return {
            "datetime": data.dateFrom.millisecondsSinceEpoch,
            "duration": data.dateTo.difference(data.dateFrom).inMilliseconds,
          };
        }).toList();

    _addLog("📦 送信データ: ${json.encode(formattedData)}"); // JSONログを記録

    final response = await http.post(
      Uri.parse("$baseUrl/contents/item/$dataEntryId/state/add"),
      headers: {"Content-Type": "application/json", "apikey": sessionKey},
      body: json.encode(formattedData),
    );

    if (response.statusCode == 200) {
      _addLog("✅ 睡眠データ送信成功！ (${formattedData.length}件)");
      _addLog("📡 WebCarry レスポンス: ${response.body}");
      return true;
    }

    _addLog("❌ 睡眠データ送信失敗...");
    _addLog("📡 WebCarry エラー: ${response.statusCode} - ${response.body}");
    return false;
  }
}
