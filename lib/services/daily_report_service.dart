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

  Future<String?> _getSessionKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('session_key');
  }

  /// healthディレクトリのIDを検索
  Future<int?> _findHealthDirId() async {
    final sessionKey = await _getSessionKey();
    if (sessionKey == null) {
      _addLog("❌ セッションキーなし");
      return null;
    }

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
      _addLog("❌ Healthディレクトリが見つからない");
    } else {
      _addLog("❌ Health検索失敗 code=${resp.statusCode}");
    }
    return null;
  }

  /// daily データエントリIDを検索
  Future<int?> _findDailyId() async {
    final healthId = await _findHealthDirId();
    if (healthId == null) return null;

    final sessionKey = await _getSessionKey();
    if (sessionKey == null) return null;

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
      }
      _addLog("❌ dailyエントリが見つからない");
    } else {
      _addLog("❌ dailyエントリ検索失敗 code=${resp.statusCode}");
    }
    return null;
  }

  /// 日報データの送信
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

  /// dailyエントリを検索 or 作成
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
        return dailyId;
      }
    }
    // なければ作成
    final createUrl = "$baseUrl/contents/item/add";
    final createBody = {
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
      body: json.encode(createBody),
    );
    if (createResp.statusCode == 200) {
      final Map<String, dynamic> respData = json.decode(createResp.body);
      final int newId = respData["id"];
      _addLog("✅ dailyエントリ新規作成: ID=$newId");
      return newId;
    }
    _addLog("❌ dailyエントリ作成失敗 code=${createResp.statusCode}");
    return null;
  }

  /// **(新規) 日報一覧を取得**
  /// GET /contents/item/{dailyId}/state
  /// => [ {id, iid, datetime, duration, value: {...}}, ... ]
  Future<List<Map<String, dynamic>>> fetchDailyReports() async {
    final dailyId = await _findDailyId();
    if (dailyId == null) {
      _addLog("❌ dailyIdが取得できず一覧取れない");
      return [];
    }
    final sessionKey = await _getSessionKey();
    if (sessionKey == null) return [];

    final url = "$baseUrl/contents/item/$dailyId/state";
    final resp = await http.get(
      Uri.parse(url),
      headers: {"apikey": sessionKey},
    );
    if (resp.statusCode == 200) {
      final List<dynamic> list = json.decode(resp.body);
      final reports = list.map((e) => e as Map<String, dynamic>).toList();
      _addLog("✅ 日報一覧取得: ${reports.length}件");
      return reports;
    } else {
      _addLog("❌ 日報一覧取得失敗 code=${resp.statusCode}, body=${resp.body}");
      return [];
    }
  }
}
