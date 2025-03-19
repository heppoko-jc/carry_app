import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final String baseUrl = "https://milc.dev.sharo-dev.com";
  List<String> logs = [];

  /// ログ追加
  void _addLog(String message) {
    logs.add(message);
    print(message); // ターミナルにも表示
  }

  /// セッションキーを取得
  Future<String?> getSessionKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('session_key');
  }

  /// CarryのアプリIDを取得 (存在しなければ作成)
  Future<int?> getCarryId() async {
    final String? sessionKey = await getSessionKey();
    if (sessionKey == null) {
      _addLog("セッションキーがありません");
      return null;
    }

    // carryディレクトリの検索
    final response = await http.get(
      Uri.parse("$baseUrl/contents/item/search?app=carry&type=dir&parent=0"),
      headers: {"apikey": sessionKey},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      if (data.isNotEmpty) {
        // 既に存在する
        int carryId = data.first["id"];
        _addLog("取得した CarryID: $carryId");
        return carryId;
      } else {
        // 存在しない -> 新規作成
        _addLog("Carryディレクトリが存在しないため、新規作成します...");
        final createdId = await createDirectory("carry", 0);
        if (createdId != null) {
          _addLog("Carryディレクトリを作成, ID=$createdId");
          return createdId;
        } else {
          _addLog("Carryディレクトリの作成に失敗...");
          return null;
        }
      }
    } else {
      _addLog("CarryID の取得に失敗 (ステータス: ${response.statusCode})");
      return null;
    }
  }

  /// ディレクトリを作成 (type="dir")
  Future<int?> createDirectory(String name, int parentId) async {
    final String? sessionKey = await getSessionKey();
    if (sessionKey == null) return null;

    final response = await http.post(
      Uri.parse("$baseUrl/contents/item/add"),
      headers: {"Content-Type": "application/json", "apikey": sessionKey},
      body: json.encode({
        "name": name,
        "app": "carry",
        "key": name,
        "type": "dir",
        "meta": {},
        "parent": parentId,
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      int dirId = data["id"];
      _addLog("ディレクトリ作成成功: $name (ID: $dirId)");
      return dirId;
    }
    _addLog("ディレクトリ作成失敗: $name (ステータス: ${response.statusCode})");
    return null;
  }

  /// データエントリを作成 (type="data")
  /// e.g. body, feedback, userInfo, gametime
  Future<int?> createDataEntry(String name, int parentId) async {
    final String? sessionKey = await getSessionKey();
    if (sessionKey == null) return null;

    final response = await http.post(
      Uri.parse("$baseUrl/contents/item/add"),
      headers: {"Content-Type": "application/json", "apikey": sessionKey},
      body: json.encode({
        "name": name,
        "app": "carry",
        "key": name,
        "type": "data",
        "meta": {},
        "parent": parentId,
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      int dataEntryId = data["id"];
      _addLog("データエントリ作成成功: $name (ID: $dataEntryId)");
      return dataEntryId;
    }
    _addLog("データエントリ作成失敗: $name (ステータス: ${response.statusCode})");
    return null;
  }

  /// 管理者のロールIDを取得
  Future<Map<String, String>?> getAdminRoles() async {
    final String? sessionKey = await getSessionKey();
    if (sessionKey == null) return null;

    final response = await http.get(
      Uri.parse(
        "$baseUrl/account/organization/config/adminRole,medicalRole,coachRole,studentRole",
      ),
      headers: {"apikey": sessionKey},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      Map<String, String> roles = {
        "admin": data["adminRole"]?.split("<")[1]?.split(">")[0] ?? "",
        "medical": data["medicalRole"]?.split("<")[1]?.split(">")[0] ?? "",
        "coach": data["coachRole"]?.split("<")[1]?.split(">")[0] ?? "",
      };
      _addLog("取得した Admin Role UUID: ${roles["admin"]}");
      _addLog("取得した Medical Role UUID: ${roles["medical"]}");
      _addLog("取得した Coach Role UUID: ${roles["coach"]}");
      return roles;
    }
    _addLog("管理者ロールの取得に失敗 (ステータス: ${response.statusCode})");
    return null;
  }

  /// ディレクトリの権限を設定
  Future<bool> setDirectoryPermissions(int dirId, List<String> roleIds) async {
    final String? sessionKey = await getSessionKey();
    if (sessionKey == null) return false;

    final List<Map<String, dynamic>> permissions =
        roleIds.map((roleId) {
          return {"flag": 7, "kind": 5, "uuid": roleId};
        }).toList();

    final response = await http.post(
      Uri.parse("$baseUrl/contents/item/$dirId/permission/set"),
      headers: {"Content-Type": "application/json", "apikey": sessionKey},
      body: json.encode(permissions),
    );

    if (response.statusCode == 200) {
      _addLog("ディレクトリ (ID: $dirId) に権限設定成功");
      return true;
    }
    _addLog("ディレクトリ (ID: $dirId) の権限設定失敗 (ステータス: ${response.statusCode})");
    return false;
  }

  /// 初期設定（ディレクトリ作成 + 権限設定 + エントリ作成）
  Future<bool> initializeDirectories() async {
    // 1) CarryID取得 (無ければ作成)
    final int? carryId = await getCarryId();
    if (carryId == null) return false;

    // 2) health / game ディレクトリを作成
    final int? healthDirId = await createDirectory("health", carryId);
    final int? gameDirId = await createDirectory("game", carryId);
    if (healthDirId == null || gameDirId == null) return false;

    // 3) ロール取得
    final roles = await getAdminRoles();
    if (roles == null) return false;

    // 4) healthディレクトリ -> Admin,Medical
    bool healthPermOk = await setDirectoryPermissions(healthDirId, [
      roles["admin"]!,
      roles["medical"]!,
    ]);

    // 5) gameディレクトリ -> Admin,Coach
    bool gamePermOk = await setDirectoryPermissions(gameDirId, [
      roles["admin"]!,
      roles["coach"]!,
    ]);
    if (!healthPermOk || !gamePermOk) {
      _addLog("ディレクトリ権限設定に失敗, 初期設定を中断します");
      return false;
    }

    // ========== ここから データエントリ(health) + ディレクトリ/エントリ(game) 作成 ==========

    // 6) healthディレクトリに data entry: body, feedback
    _addLog("=== healthディレクトリに [body], [feedback] データエントリ作成 ===");
    final bodyId = await createDataEntry("body", healthDirId);
    if (bodyId == null) return false;
    final feedbackId = await createDataEntry("feedback", healthDirId);
    if (feedbackId == null) return false;

    // 7) gameディレクトリ -> valorant ディレクトリ
    _addLog("=== gameディレクトリ内に [valorant] ディレクトリを作成 ===");
    final valorantDirId = await createDirectory("valorant", gameDirId);
    if (valorantDirId == null) return false;

    //    valorantディレクトリ内に userInfo data
    final userInfoId = await createDataEntry("userInfo", valorantDirId);
    if (userInfoId == null) return false;

    // 8) gameディレクトリに data entry: gametime
    final gametimeId = await createDataEntry("gametime", gameDirId);
    if (gametimeId == null) return false;

    _addLog("=== 全エントリ作成完了 ===");

    // すべて成功
    return true;
  }
}
