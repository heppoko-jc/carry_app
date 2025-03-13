import 'dart:convert';
import 'package:http/http.dart' as http;

class GameService {
  final String riotApiKey = "RGAPI-4d30ea24-b988-46f0-b15c-1710fe7d071d";
  final String riotApiBaseUrl = "https://asia.api.riotgames.com";

  List<String> logs = [];

  /// **ログを追加**
  void _addLog(String message) {
    logs.add(message);
    print(message); // ターミナルにも表示
  }

  /// **ゲームネームとタグラインから PUUID を取得**
  Future<String?> getPUUID(String gameName, String tagLine) async {
    final response = await http.get(
      Uri.parse(
        "$riotApiBaseUrl/riot/account/v1/accounts/by-riot-id/$gameName/$tagLine?api_key=$riotApiKey",
      ),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      String puuid = data["puuid"];
      _addLog("✅ 取得した PUUID: $puuid");
      return puuid;
    } else {
      _addLog("❌ PUUID の取得に失敗 (${response.statusCode})");
      return null;
    }
  }

  /// **PUUID からマッチリストを取得（最新5件）**
  Future<List<String>?> getMatchList(String puuid) async {
    final response = await http.get(
      Uri.parse(
        "https://ap.api.riotgames.com/val/match/v1/matchlists/by-puuid/$puuid?api_key=$riotApiKey",
      ),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      List<dynamic> history = data["history"];
      List<String> matchIds =
          history.take(5).map((match) => match["matchId"].toString()).toList();

      _addLog("🎮 最新のマッチID（5件）: ${matchIds.join(', ')}");
      return matchIds;
    } else {
      _addLog("❌ マッチリストの取得に失敗 (${response.statusCode})");
      return null;
    }
  }

  /// **マッチID から試合情報を取得**
  Future<Map<String, dynamic>?> getMatchInfo(String matchId) async {
    final response = await http.get(
      Uri.parse(
        "https://ap.api.riotgames.com/val/match/v1/matches/$matchId?api_key=$riotApiKey",
      ),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> matchData = json.decode(response.body);
      String mapId = matchData["matchInfo"]["mapId"];
      String gameMode = matchData["matchInfo"]["gameMode"];
      List<dynamic> players = matchData["players"];

      _addLog("📌 取得したマッチ情報: ");
      _addLog("🔹 マップ: $mapId");
      _addLog("🔹 ゲームモード: $gameMode");

      for (var player in players) {
        _addLog(
          "👤 ${player["gameName"]} - K/D/A: "
          "${player["stats"]["kills"]}/${player["stats"]["deaths"]}/${player["stats"]["assists"]}",
        );
      }

      return matchData;
    } else {
      _addLog("❌ マッチ情報の取得に失敗 (${response.statusCode})");
      return null;
    }
  }
}
