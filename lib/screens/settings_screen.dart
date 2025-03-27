import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 設定画面では SharedPreferences に保存されている Riot のアカウント情報（PUUID、ゲームネーム、タグライン）を表示する
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _puuid;
  String? _gameName;
  String? _tagLine;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// SharedPreferencesから値を読み込み、画面に反映
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _puuid = prefs.getString('riot_puuid') ?? '未設定';
      _gameName = prefs.getString('riot_gameName') ?? '未設定';
      _tagLine = prefs.getString('riot_tagLine') ?? '未設定';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("設定")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Riotアカウント設定",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text("PUUID: $_puuid"),
            const SizedBox(height: 5),
            Text("ゲームネーム: $_gameName"),
            const SizedBox(height: 5),
            Text("タグライン: $_tagLine"),
          ],
        ),
      ),
    );
  }
}
