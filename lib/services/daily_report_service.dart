// lib/services/daily_report_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DailyReportService {
  final String baseUrl = "https://milc.dev.sharo-dev.com";
  List<String> logs = [];

  void _addLog(String message) {
    logs.add(message);
    print(message);
  }

  /// セッションキーの取得
  Future<String?> _getSessionKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('session_key');
  }

  /// healthディレクトリID を検索
  Future<int?> _findHealthDirId() async {
    final sessionKey = await _getSessionKey();
    if (sessionKey == null) return null;

    final url = "$baseUrl/contents/item/search?app=carry&type=dir&key=health";
    final resp = await http.get(
      Uri.parse(url),
      headers: {"apikey": sessionKey},
    );
    if (resp.statusCode == 200) {
      final List<dynamic> data = json.decode(resp.body);
      if (data.isNotEmpty) {
        final int healthId = data.first["id"];
        _addLog("✅ HealthディレクトリID: $healthId");
        return healthId;
      }
      _addLog("❌ Healthディレクトリが見つかりません");
    } else {
      _addLog("❌ Healthディレクトリ検索失敗 code=${resp.statusCode}");
    }
    return null;
  }

  /// daily データエントリを検索/作成
  Future<int?> _findOrCreateDailyEntry(int healthId) async {
    final sessionKey = await _getSessionKey();
    if (sessionKey == null) return null;

    // 検索
    final searchUrl =
        "$baseUrl/contents/item/search?app=carry&key=daily&type=data&parent=$healthId";
    final resp = await http.get(
      Uri.parse(searchUrl),
      headers: {"apikey": sessionKey},
    );
    if (resp.statusCode == 200) {
      final List<dynamic> items = json.decode(resp.body);
      if (items.isNotEmpty) {
        final int dailyId = items.first["id"];
        _addLog("✅ dailyエントリID: $dailyId");
        return dailyId;
      } else {
        _addLog("dailyエントリが無いので作成します...");
      }
    } else {
      _addLog("❌ dailyエントリ検索失敗 code=${resp.statusCode}");
      return null;
    }

    // 作成
    final createUrl = "$baseUrl/contents/item/add";
    final body = {
      "name": "daily",
      "app": "carry",
      "key": "daily",
      "type": "data",
      "meta": {},
      "parent": healthId,
    };
    final createResp = await http.post(
      Uri.parse(createUrl),
      headers: {"Content-Type": "application/json", "apikey": sessionKey},
      body: json.encode(body),
    );
    if (createResp.statusCode == 200) {
      final Map<String, dynamic> respData = json.decode(createResp.body);
      final int newId = respData["id"];
      _addLog("✅ dailyエントリ新規作成: ID=$newId");
      return newId;
    } else {
      _addLog("❌ dailyエントリ作成失敗 code=${createResp.statusCode}");
      return null;
    }
  }

  /// **日報データを送信**
  /// [reportData] はフォーム内容
  /// [reportDateMs] はその日付を「日本時間12:00」などに変換したUnixTime(ms)
  ///
  /// POST => /contents/item/{dailyId}/state/add
  /// body: {
  ///   "datetime": reportDateMs,
  ///   "value": { ...reportData... }
  /// }
  Future<bool> sendDailyReport({
    required Map<String, dynamic> reportData,
    required int reportDateMs,
  }) async {
    final healthId = await _findHealthDirId();
    if (healthId == null) return false;

    final dailyId = await _findOrCreateDailyEntry(healthId);
    if (dailyId == null) return false;

    final sessionKey = await _getSessionKey();
    if (sessionKey == null) return false;

    final url = "$baseUrl/contents/item/$dailyId/state/add";
    final bodyObj = {"datetime": reportDateMs, "value": reportData};
    final resp = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json", "apikey": sessionKey},
      body: json.encode(bodyObj),
    );
    if (resp.statusCode == 200) {
      _addLog("✅ 日報送信成功 dailyId=$dailyId");
      return true;
    } else {
      _addLog("❌ 日報送信失敗 code=${resp.statusCode}, body=${resp.body}");
      return false;
    }
  }
}
