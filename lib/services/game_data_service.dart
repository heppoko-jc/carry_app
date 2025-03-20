import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GameDataService {
  final String baseUrl = "https://milc.dev.sharo-dev.com";
  List<String> logs = [];

  void _addLog(String message) {
    logs.add(message);
    print(message);
  }

  /// **(A) セッションキー取得**
  Future<String?> _getSessionKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('session_key');
  }

  // ------------------------------------------------------------------------
  // 1) Valorant ディレクトリの取得 (parent=gameディレクトリ)
  //    既に初期設定フローで "game" dir / "valorant" dir は作成されているはず
  //    ここでは "valorant"ディレクトリIDを検索
  // ------------------------------------------------------------------------
  Future<int?> _findValorantDirId() async {
    final sessionKey = await _getSessionKey();
    if (sessionKey == null) {
      _addLog("❌ セッションキーがありません");
      return null;
    }

    // /contents/item/search?app=carry&key=valorant&type=dir
    final url = "$baseUrl/contents/item/search?app=carry&key=valorant&type=dir";
    final resp = await http.get(
      Uri.parse(url),
      headers: {"apikey": sessionKey},
    );
    if (resp.statusCode == 200) {
      final List<dynamic> items = json.decode(resp.body);
      if (items.isNotEmpty) {
        final int valorantDirId = items.first["id"];
        _addLog("✅ valorantディレクトリID: $valorantDirId");
        return valorantDirId;
      } else {
        _addLog("❌ valorantディレクトリが見つかりません (初期設定で作成済みのはず)");
      }
    } else {
      _addLog("❌ valorantディレクトリ検索失敗 code=${resp.statusCode}");
    }
    return null;
  }

  // ------------------------------------------------------------------------
  // 2) userInfoのdataエントリを検索
  //    既に初期設定で "userInfo" data entry を作成しているはず
  // ------------------------------------------------------------------------
  Future<int?> _findUserInfoEntryId(int valorantDirId) async {
    final sessionKey = await _getSessionKey();
    if (sessionKey == null) return null;

    // /contents/item/search?app=carry&key=userInfo&type=data&parent=valorantDirId
    final url =
        "$baseUrl/contents/item/search?app=carry&key=userInfo&type=data&parent=$valorantDirId";
    final resp = await http.get(
      Uri.parse(url),
      headers: {"apikey": sessionKey},
    );

    if (resp.statusCode == 200) {
      final List<dynamic> items = json.decode(resp.body);
      if (items.isNotEmpty) {
        final int userInfoId = items.first["id"];
        _addLog("✅ userInfoエントリID: $userInfoId");
        return userInfoId;
      } else {
        _addLog("❌ userInfoエントリが見つかりません");
      }
    } else {
      _addLog("❌ userInfoエントリ検索失敗 code=${resp.statusCode}");
    }
    return null;
  }

  /// **(B) ユーザー情報を送信**
  ///    e.g. { value: { PUUID, username, tagline } }
  Future<bool> sendUserInfo({
    required String puuid,
    required String username,
    required String tagline,
  }) async {
    final valorantDirId = await _findValorantDirId();
    if (valorantDirId == null) return false;

    final userInfoId = await _findUserInfoEntryId(valorantDirId);
    if (userInfoId == null) return false;

    final sessionKey = await _getSessionKey();
    if (sessionKey == null) return false;

    // 送るデータ
    // WebCarryの "state.add" は { ... } 単一オブジェクト or 配列
    // 例: { "value": { ...ユーザー情報...} }
    final Map<String, dynamic> bodyData = {
      "value": {"PUUID": puuid, "username": username, "tagline": tagline},
    };

    final url = "$baseUrl/contents/item/$userInfoId/state/add";
    final resp = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json", "apikey": sessionKey},
      body: json.encode(bodyData),
    );

    if (resp.statusCode == 200) {
      _addLog("✅ ユーザー情報送信成功 userInfoId=$userInfoId");
      return true;
    } else {
      _addLog("❌ ユーザー情報送信失敗 code=${resp.statusCode}, body=${resp.body}");
      return false;
    }
  }

  // ------------------------------------------------------------------------
  // 3) gametimeエントリを検索
  //    /contents/item/search?app=carry&key=gametime&type=data
  //    (parent= gameDir or carryDir? => 初期設定次第)
  // ------------------------------------------------------------------------
  Future<int?> _findGameTimeEntryId() async {
    final sessionKey = await _getSessionKey();
    if (sessionKey == null) return null;

    final searchUrl =
        "$baseUrl/contents/item/search?app=carry&key=gametime&type=data";
    final resp = await http.get(
      Uri.parse(searchUrl),
      headers: {"apikey": sessionKey},
    );
    if (resp.statusCode == 200) {
      final List<dynamic> items = json.decode(resp.body);
      if (items.isNotEmpty) {
        final int gameTimeId = items.first["id"];
        _addLog("✅ gametimeデータエントリID: $gameTimeId");
        return gameTimeId;
      } else {
        _addLog("❌ gametimeエントリが見つかりません");
      }
    } else {
      _addLog("❌ gametimeエントリ検索失敗 code=${resp.statusCode}");
    }
    return null;
  }

  /// **(C) ゲームの時間（開始時間,試合時間,ゲーム名）を送信**
  ///    body = { datetime, duration, value="valorant" }
  Future<bool> sendGameTime({
    required int gameStartMillis,
    required int gameLengthMillis,
    required String gameName, // "valorant" など
  }) async {
    final gameTimeId = await _findGameTimeEntryId();
    if (gameTimeId == null) return false;

    final sessionKey = await _getSessionKey();
    if (sessionKey == null) return false;

    final url = "$baseUrl/contents/item/$gameTimeId/state/add";
    final obj = {
      "datetime": gameStartMillis,
      "duration": gameLengthMillis,
      "value": gameName,
    };

    final resp = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json", "apikey": sessionKey},
      body: json.encode(obj),
    );

    if (resp.statusCode == 200) {
      _addLog("✅ ゲーム時間送信成功 (gametimeId=$gameTimeId)");
      return true;
    } else {
      _addLog("❌ ゲーム時間送信失敗 code=${resp.statusCode}, body=${resp.body}");
      return false;
    }
  }

  // ------------------------------------------------------------------------
  // 4) matchデータエントリを検索 or 作成
  //    parent= valorantDirId, key= "match", name="match", type="data"
  // ------------------------------------------------------------------------
  Future<int?> _findOrCreateMatchEntryId(int valorantDirId) async {
    final sessionKey = await _getSessionKey();
    if (sessionKey == null) return null;

    // 検索
    final searchUrl =
        "$baseUrl/contents/item/search?app=carry&key=match&type=data&parent=$valorantDirId";
    final resp = await http.get(
      Uri.parse(searchUrl),
      headers: {"apikey": sessionKey},
    );
    if (resp.statusCode == 200) {
      final List<dynamic> items = json.decode(resp.body);
      if (items.isNotEmpty) {
        final int matchDataId = items.first["id"];
        _addLog("✅ matchエントリID: $matchDataId");
        return matchDataId;
      } else {
        _addLog("matchデータエントリが見つからないので作成します...");
      }
    } else {
      _addLog("❌ matchエントリ検索失敗 code=${resp.statusCode}");
      return null;
    }

    // 作成
    final createUrl = "$baseUrl/contents/item/add";
    final createBody = {
      "name": "match",
      "app": "carry",
      "key": "match",
      "type": "data",
      "meta": {},
      "parent": valorantDirId,
    };

    final createResp = await http.post(
      Uri.parse(createUrl),
      headers: {"Content-Type": "application/json", "apikey": sessionKey},
      body: json.encode(createBody),
    );

    if (createResp.statusCode == 200) {
      final newId = json.decode(createResp.body)["id"];
      _addLog("✅ matchデータエントリを新規作成: ID=$newId");
      return newId;
    } else {
      _addLog("❌ matchデータエントリ作成失敗 code=${createResp.statusCode}");
      return null;
    }
  }

  /// **(D) マッチ情報を送信**
  ///    data = {
  ///      "datetime": gameStartMillis,
  ///      "duration": gameLengthMillis,
  ///      "value": {
  ///         "matchId", "mapId", "queueId", ...
  ///      }
  ///    }
  Future<bool> sendMatchDetail(Map<String, dynamic> match) async {
    // match 内の startMs / lengthMs / value
    final gameStart = match["gameStartMillis"] ?? 0;
    final length = match["gameLengthMillis"] ?? 0;

    // "value" 部分に matchId, mapId, queueId など詰める
    // 例: { "matchId":"...", "mapId":"...", "queueId":"...", "kills":..., "didwin":..., ... }
    final mapValue = Map<String, dynamic>.from(match);
    // datetime/duration は外部に置くので "value" から削除しておく or ignore

    final valorantDirId = await _findValorantDirId();
    if (valorantDirId == null) return false;

    final matchEntryId = await _findOrCreateMatchEntryId(valorantDirId);
    if (matchEntryId == null) return false;

    final sessionKey = await _getSessionKey();
    if (sessionKey == null) return false;

    final url = "$baseUrl/contents/item/$matchEntryId/state/add";
    final bodyObj = {
      "datetime": gameStart,
      "duration": length,
      "value": mapValue,
    };

    final resp = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json", "apikey": sessionKey},
      body: json.encode(bodyObj),
    );

    if (resp.statusCode == 200) {
      _addLog("✅ マッチ情報送信成功 matchID=${match["matchId"]}");
      return true;
    } else {
      _addLog("❌ マッチ情報送信失敗 code=${resp.statusCode}, body=${resp.body}");
      return false;
    }
  }
}
