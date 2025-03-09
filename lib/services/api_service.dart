import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final String baseUrl = "https://milc.dev.sharo-dev.com";
  List<String> logs = [];

  /// **ログを追加**
  void _addLog(String message) {
    logs.add(message);
    print(message); // ターミナルにも表示
  }

  /// **セッションキーを取得**
  Future<String?> getSessionKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('session_key');
  }

  /// **CarryのアプリIDを取得**
  Future<int?> getCarryId() async {
    final String? sessionKey = await getSessionKey();
    if (sessionKey == null) return null;

    final response = await http.get(
      Uri.parse("$baseUrl/contents/item/search?app=carry&type=dir&parent=0"),
      headers: {"apikey": sessionKey},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      if (data.isNotEmpty) {
        int carryId = data.first["id"];
        _addLog("取得した CarryID: $carryId");
        return carryId;
      }
    }
    _addLog("CarryID の取得に失敗");
    return null;
  }

  /// **ディレクトリを作成**
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
    _addLog("ディレクトリ作成失敗: $name");
    return null;
  }

  /// **管理者のロールIDを取得**
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
    _addLog("管理者ロールの取得に失敗");
    return null;
  }

  /// **ディレクトリの権限を設定**
  Future<bool> setDirectoryPermissions(int dirId, List<String> roleIds) async {
    final String? sessionKey = await getSessionKey();
    if (sessionKey == null) return false;

    final List<Map<String, dynamic>> permissions =
        roleIds.map((roleId) {
          return {"flag": 2, "kind": 7, "uuid": roleId};
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
    _addLog("ディレクトリ (ID: $dirId) の権限設定失敗");
    return false;
  }

  /// **初期設定（ディレクトリ作成 + 権限設定）**
  Future<bool> initializeDirectories() async {
    final int? carryId = await getCarryId();
    if (carryId == null) return false;

    final int? healthDirId = await createDirectory("health", carryId);
    final int? gameDirId = await createDirectory("game", carryId);

    if (healthDirId == null || gameDirId == null) return false;

    final roles = await getAdminRoles();
    if (roles == null) return false;

    bool healthPermissionSet = await setDirectoryPermissions(healthDirId, [
      roles["admin"]!,
      roles["medical"]!,
    ]);

    bool gamePermissionSet = await setDirectoryPermissions(gameDirId, [
      roles["admin"]!,
      roles["coach"]!,
    ]);

    return healthPermissionSet && gamePermissionSet;
  }
}
