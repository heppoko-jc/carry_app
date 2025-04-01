import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// 指定されたアセットパスからテキストを非同期に読み込む関数
Future<String> loadTextAsset(String assetPath) async {
  return await rootBundle.loadString(assetPath);
}

/// 利用規約画面
class TermsScreen extends StatefulWidget {
  /// 同意後に呼ばれるコールバック（例：次の画面へ遷移）
  final VoidCallback onNext;

  const TermsScreen({Key? key, required this.onNext}) : super(key: key);

  @override
  _TermsScreenState createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _agreed = false; // チェックボックスの状態
  late Future<String> _termsText; // 利用規約のテキストを保持するFuture

  @override
  void initState() {
    super.initState();
    // アセット "assets/terms.txt" から利用規約テキストを読み込む
    _termsText = loadTextAsset("assets/terms.txt");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("利用規約")),
      body: FutureBuilder<String>(
        future: _termsText,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // 読み込み中はプログレスインジケータを表示
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            // エラーがあればエラーメッセージを表示
            return Center(child: Text("エラー: ${snapshot.error}"));
          } else {
            // テキストが正常に読み込めた場合
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // テキスト内容をスクロール可能なビューで表示
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        snapshot.data ?? "",
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // チェックボックスとラベル
                  Row(
                    children: [
                      Checkbox(
                        value: _agreed,
                        onChanged: (value) {
                          setState(() {
                            _agreed = value ?? false;
                          });
                        },
                      ),
                      const Text("利用規約に同意します"),
                    ],
                  ),
                  // 「次へ」ボタン（チェック済みでなければ無効）
                  ElevatedButton(
                    onPressed: _agreed ? widget.onNext : null,
                    child: const Text("次へ"),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}

/// 研究同意書画面
class ConsentScreen extends StatefulWidget {
  final VoidCallback onNext;

  const ConsentScreen({Key? key, required this.onNext}) : super(key: key);

  @override
  _ConsentScreenState createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _agreed = false;
  late Future<String> _consentText;

  @override
  void initState() {
    super.initState();
    // アセット "assets/consent.txt" から研究同意書テキストを読み込む
    _consentText = loadTextAsset("assets/consent.txt");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("研究同意書")),
      body: FutureBuilder<String>(
        future: _consentText,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("エラー: ${snapshot.error}"));
          } else {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        snapshot.data ?? "",
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: _agreed,
                        onChanged: (value) {
                          setState(() {
                            _agreed = value ?? false;
                          });
                        },
                      ),
                      const Text("研究同意書に同意します"),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: _agreed ? widget.onNext : null,
                    child: const Text("次へ"),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
