import 'dart:convert';
import 'package:http/http.dart' as http;

/// VALORANTのゲームデータ取得サービス
/// - キャラクターID→キャラ名のマッピング
/// - マッチリストの取得
/// - マッチ詳細の取得(チーム/デスマッチ対応)
class GameService {
  final String riotApiKey =
      "RGAPI-4d30ea24-b988-46f0-b15c-1710fe7d071d"; // 独自APIキー
  final String valorantApiHost = "https://ap.api.riotgames.com";
  final String locale = "ja-JP"; // キャラ名を日本語で取得

  // キャラID -> キャラ名
  Map<String, String> _characterMap = {};

  List<String> logs = [];

  void _addLog(String message) {
    logs.add(message);
    print(message);
  }

  /// (A) VALORANTのコンテンツリソースを取得し、キャラクターID→名前を_mapに格納
  ///    e.g. "E370FA57-..." -> "ゲッコー"
  Future<void> fetchValContent() async {
    final url = "$valorantApiHost/val/content/v1/contents?locale=$locale";
    _addLog("Fetching VAL content from $url");
    final response = await http.get(
      Uri.parse(url),
      headers: {"X-Riot-Token": riotApiKey},
    );

    _addLog("ValContent Response status: ${response.statusCode}");

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> chars = data["characters"] ?? [];
      _addLog("characters count: ${chars.length}");
      for (var c in chars) {
        final String rawId = c["id"]; // "DADE69B4-4F5A-8528-247B-219E5A1FACD6"
        final String normId = rawId.toLowerCase(); // 小文字処理
        final String name = c["name"] ?? "unknown";
        _characterMap[normId] = name;
      }
    } else {
      _addLog("❌ キャラクターリソース取得に失敗 (${response.statusCode})");
    }
  }

  /// (B) 1週間のマッチリスト(最大50件)を取得
  ///    "gameStartTimeMillis" が直近7日以内だけ返す
  Future<List<Map<String, dynamic>>> getMatchList(String puuid) async {
    final String requestUrl =
        "$valorantApiHost/val/match/v1/matchlists/by-puuid/$puuid";

    _addLog("Requesting match list: $requestUrl, X-Riot-Token: $riotApiKey");
    final response = await http.get(
      Uri.parse(requestUrl),
      headers: {"X-Riot-Token": riotApiKey},
    );

    _addLog("MatchList Response status: ${response.statusCode}");
    _addLog("MatchList Response body: ${response.body}");

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> history = data["history"];

      final limited = history.take(50).toList();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final oneWeekAgoMs = nowMs - (7 * 24 * 60 * 60 * 1000);

      List<Map<String, dynamic>> recent = [];
      for (var item in limited) {
        final matchId = item["matchId"].toString();
        final startMs = item["gameStartTimeMillis"] as int;
        final queueId = item["queueId"] ?? "";
        if (startMs >= oneWeekAgoMs && startMs <= nowMs) {
          recent.add({
            "matchId": matchId,
            "gameStart": startMs,
            "queueId": queueId,
          });
        }
      }

      _addLog(
        "🎮 直近1週間(50件中) => ${recent.map((e) => e["matchId"]).join(', ')}",
      );

      return recent;
    } else {
      _addLog("❌ マッチリスト取得失敗 (${response.statusCode})");
      return [];
    }
  }

  /// (C) マッチID から詳細を取得し、より詳細な情報をまとめる
  ///    userPuuid: 自分のPUUID(勝敗や自分チーム判定に使用)
  ///    戻り値:
  ///      {
  ///        "matchId": ..,
  ///        "mapId": ..,
  ///        "mapName": ..(本実装では同じ),
  ///        "queueId": "deathmatch" or "competitive" etc,
  ///        "isDeathmatch": bool,
  ///        "gameStartMillis": int,
  ///        "gameLengthMillis": int,
  ///
  ///        # 以下はスコアを数値化
  ///        "teamAScore": int,
  ///        "teamBScore": int,
  ///        # deathmatchの場合は userScore, enemyScore として扱う例
  ///
  ///        "didWin": bool, // 自分が勝ったか
  ///        "self": {...},  // 自分のKDA等
  ///        "allyTeam": [ { name, character, kills, deaths, assists }, ... ],
  ///        "enemyTeam": ...
  ///      }
  Future<Map<String, dynamic>?> getMatchInfo(
    String matchId,
    String userPuuid,
  ) async {
    final String url = "$valorantApiHost/val/match/v1/matches/$matchId";
    _addLog("Fetching match info from: $url, X-Riot-Token: $riotApiKey");

    final response = await http.get(
      Uri.parse(url),
      headers: {"X-Riot-Token": riotApiKey},
    );

    _addLog("MatchInfo status: ${response.statusCode}");
    _addLog("MatchInfo body: ${response.body}");

    if (response.statusCode != 200) {
      _addLog("❌ マッチ情報の取得に失敗 (${response.statusCode})");
      return null;
    }

    final Map<String, dynamic> matchData = json.decode(response.body);
    final matchInfo = matchData["matchInfo"] ?? {};
    final String mapId = matchInfo["mapId"] ?? "";
    final String queueId = matchInfo["queueId"] ?? "unknown";
    final int startMs = matchInfo["gameStartMillis"] ?? 0;
    final int lengthMs = matchInfo["gameLengthMillis"] ?? 0;

    final List<dynamic> teams = matchData["teams"] ?? [];
    final List<dynamic> players = matchData["players"] ?? [];

    final bool isDeathmatch = (queueId.toLowerCase() == "deathmatch");

    // 自分情報
    String? userTeamId;
    int userKills = 0, userDeaths = 0, userAssists = 0;
    String? userCharName;
    String? userGameName;
    String? userTag;

    for (var p in players) {
      if (p["puuid"] == userPuuid) {
        userTeamId = p["teamId"];
        userKills = p["stats"]["kills"] ?? 0;
        userDeaths = p["stats"]["deaths"] ?? 0;
        userAssists = p["stats"]["assists"] ?? 0;
        userGameName = p["gameName"] ?? "";
        userTag = p["tagLine"] ?? "";
        final cId = p["characterId"] ?? "";
        userCharName = _characterMap[cId] ?? cId;
        break;
      }
    }

    bool didWin = false;

    // スコアを2つのintで表す
    int teamAScore = 0;
    int teamBScore = 0;

    List<Map<String, dynamic>> allyPlayers = [];
    List<Map<String, dynamic>> enemyPlayers = [];

    // (1) deathmatchの場合
    if (isDeathmatch) {
      // (A) 勝敗
      // teamIdが userPUUID, won==true なら勝ち
      bool userWon = false;
      for (var t in teams) {
        if (t["teamId"] == userTeamId && t["won"] == true) {
          userWon = true;
          break;
        }
      }
      didWin = userWon;

      // スコア: userScore=1, enemyScore=0 あるいは0,1
      // ここでは "teamAScore" "teamBScore" とは異なるが、例示として:
      if (didWin) {
        teamAScore = 1;
        teamBScore = 0;
      } else {
        teamAScore = 0;
        teamBScore = 1;
      }

      // ally: 自分, enemy: それ以外
      for (var p in players) {
        final ppuuid = p["puuid"];
        final pName = "${p["gameName"]}#${p["tagLine"]}";
        final cId = p["characterId"] ?? "";
        final kills = p["stats"]["kills"] ?? 0;
        final deaths = p["stats"]["deaths"] ?? 0;
        final assists = p["stats"]["assists"] ?? 0;
        final charName = _characterMap[cId] ?? cId;

        final info = {
          "name": pName,
          "character": charName,
          "kills": kills,
          "deaths": deaths,
          "assists": assists,
        };

        if (ppuuid == userPuuid) {
          allyPlayers.add(info);
        } else {
          enemyPlayers.add(info);
        }
      }
    } else {
      // (2) 通常モード (2チーム)
      // ex. teams => [ {teamId:'Blue', won:true, roundsWon:13 }, {teamId:'Red', ...} ]
      // userTeamId => 'Blue' or 'Red'

      // teamAScore/teamBScore に格納
      if (teams.length >= 2) {
        final tA = teams[0];
        final tB = teams[1];
        teamAScore = tA["roundsWon"] ?? 0;
        teamBScore = tB["roundsWon"] ?? 0;

        // 自分がいるチーム
        for (var t in teams) {
          if (t["teamId"] == userTeamId) {
            didWin = (t["won"] == true);
            break;
          }
        }
      }

      // ally: userTeamId, enemy: それ以外
      for (var p in players) {
        final pName = "${p["gameName"]}#${p["tagLine"]}";
        final cId = p["characterId"] ?? "";
        final charName = _characterMap[cId] ?? cId;
        final kills = p["stats"]["kills"] ?? 0;
        final deaths = p["stats"]["deaths"] ?? 0;
        final assists = p["stats"]["assists"] ?? 0;
        final pTeam = p["teamId"];

        final item = {
          "name": pName,
          "character": charName,
          "kills": kills,
          "deaths": deaths,
          "assists": assists,
        };

        if (pTeam == userTeamId) {
          allyPlayers.add(item);
        } else {
          enemyPlayers.add(item);
        }
      }
    }

    // 結果まとめ
    return {
      "matchId": matchId,
      "mapId": mapId,
      "mapName": mapId, // mapId→mapName変換が必要な場合ここを実装
      "queueId": queueId,
      "isDeathmatch": isDeathmatch,
      "gameStartMillis": startMs,
      "gameLengthMillis": lengthMs,

      // チームスコアを分割
      "teamAScore": teamAScore,
      "teamBScore": teamBScore,

      "didWin": didWin,

      "self": {
        "puuid": userPuuid,
        "name": userGameName ?? "",
        "tagLine": userTag ?? "",
        "character": userCharName ?? "unknown",
        "kills": userKills,
        "deaths": userDeaths,
        "assists": userAssists,
      },
      "allyTeam": allyPlayers,
      "enemyTeam": enemyPlayers,
    };
  }

  /// (D) getRecentMatches
  /// - fetchValContent でキャラ名マップを作成(一度だけ)
  /// - getMatchList
  /// - 各マッチIDに対しgetMatchInfo( userPUuid ) => まとめて返す
  Future<List<Map<String, dynamic>>> getRecentMatches(String puuid) async {
    // キャラ情報がまだない場合は取得 (一度だけ)
    if (_characterMap.isEmpty) {
      await fetchValContent();
    }

    // マッチリスト
    final matchList = await getMatchList(puuid);
    if (matchList.isEmpty) return [];

    List<Map<String, dynamic>> results = [];
    for (var item in matchList) {
      final matchId = item["matchId"] as String;
      final detail = await getMatchInfo(matchId, puuid);
      if (detail != null) {
        results.add(detail);
      }
    }

    return results;
  }
}
