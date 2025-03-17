import 'dart:convert';
import 'package:http/http.dart' as http;

class GameService {
  // RiotのAPIキー
  final String riotApiKey = "RGAPI-4d30ea24-b988-46f0-b15c-1710fe7d071d";

  // Valorant向けのAPIホスト
  final String valorantApiHost = "https://ap.api.riotgames.com";

  List<String> logs = [];

  /// **ログを追加**
  void _addLog(String message) {
    logs.add(message);
    print(message);
  }

  /// **(1) PUUIDからマッチリストを取得 (最大50件)**
  /// "X-Riot-Token" 形式でキーを渡す
  /// 直近1週間分をフィルタ
  Future<List<Map<String, dynamic>>> getMatchList(String puuid) async {
    final String requestUrl =
        "$valorantApiHost/val/match/v1/matchlists/by-puuid/$puuid";

    // ログ確認用
    _addLog(
      "Requesting match list from: $requestUrl, X-Riot-Token: $riotApiKey",
    );

    final response = await http.get(
      Uri.parse(requestUrl),
      headers: {"X-Riot-Token": riotApiKey},
    );

    _addLog("MatchList Response status: ${response.statusCode}");
    _addLog("MatchList Response body: ${response.body}");

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> history = data["history"];

      // 先頭50件
      final limitedHistory = history.take(50).toList();

      // 1週間の範囲
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final oneWeekAgoMs = nowMs - (7 * 24 * 60 * 60 * 1000);

      List<Map<String, dynamic>> recentList = [];
      for (var item in limitedHistory) {
        final matchId = item["matchId"].toString();
        final gameStart = item["gameStartTimeMillis"] as int;

        if (gameStart >= oneWeekAgoMs && gameStart <= nowMs) {
          recentList.add({
            "matchId": matchId,
            "gameStart": gameStart,
            "queueId": item["queueId"] ?? "",
          });
        }
      }

      _addLog(
        "🎮 直近1週間のマッチID(最大50件からフィルタ): "
        "${recentList.map((e) => e["matchId"]).join(', ')}",
      );

      return recentList;
    } else {
      _addLog("❌ マッチリストの取得に失敗 (${response.statusCode})");
      return [];
    }
  }

  /// **(2) マッチID から試合情報を取得**
  /// gameStartMillis, gameLengthMillis 等を追加で取得
  Future<Map<String, dynamic>?> getMatchInfo(String matchId) async {
    final String requestUrl = "$valorantApiHost/val/match/v1/matches/$matchId";

    _addLog(
      "Requesting match info from: $requestUrl, X-Riot-Token: $riotApiKey",
    );

    final response = await http.get(
      Uri.parse(requestUrl),
      headers: {"X-Riot-Token": riotApiKey},
    );

    _addLog("MatchInfo Response status: ${response.statusCode}");
    _addLog("MatchInfo Response body: ${response.body}");

    if (response.statusCode == 200) {
      final Map<String, dynamic> matchData = json.decode(response.body);

      final mapId = matchData["matchInfo"]["mapId"] ?? "";
      final gameMode = matchData["matchInfo"]["gameMode"] ?? "";
      final gameStart = matchData["matchInfo"]["gameStartMillis"] ?? 0;
      final gameLength = matchData["matchInfo"]["gameLengthMillis"] ?? 0;

      _addLog("📌 取得したマッチ情報: $matchId");
      _addLog("🔹 マップ: $mapId");
      _addLog("🔹 ゲームモード: $gameMode");
      _addLog("🔹 開始: $gameStart, 長さ: $gameLength ms");

      final players = matchData["players"] as List<dynamic>;
      for (var player in players) {
        _addLog(
          "👤 ${player["gameName"]}"
          " - K/D/A: ${player["stats"]["kills"]}/${player["stats"]["deaths"]}/${player["stats"]["assists"]}",
        );
      }

      return {
        "matchId": matchId,
        "mapId": mapId,
        "gameMode": gameMode,
        "gameStartMillis": gameStart,
        "gameLengthMillis": gameLength,
        "players": players,
      };
    } else {
      _addLog("❌ マッチ情報の取得に失敗 (${response.statusCode})");
      return null;
    }
  }

  /// **(3) getRecentMatches**:
  /// getMatchList → 各 matchId の詳細をまとめて返す
  Future<List<Map<String, dynamic>>> getRecentMatches(String puuid) async {
    final matchList = await getMatchList(puuid);
    if (matchList.isEmpty) return [];

    List<Map<String, dynamic>> matchDetails = [];
    for (var item in matchList) {
      final matchId = item["matchId"] as String;
      final info = await getMatchInfo(matchId);
      if (info != null) {
        matchDetails.add(info);
      }
    }
    return matchDetails;
  }
}
