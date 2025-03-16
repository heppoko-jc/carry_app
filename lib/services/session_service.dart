import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/material.dart';

class SessionService {
  String? sessionKey;

  /// **セッションキーを保存**
  Future<void> saveSessionKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_key', key);
    sessionKey = key;
  }

  /// **セッションキーを読み込む**
  Future<String?> loadSessionKey() async {
    final prefs = await SharedPreferences.getInstance();
    sessionKey = prefs.getString('session_key');
    return sessionKey;
  }

  /// **セッションキーをWebViewで取得するフローを実行**
  /// 取得したら SharedPreferences に保存し、呼び出し元に返す
  Future<String?> acquireSessionKey(BuildContext context) async {
    // WebViewを開いて、セッションキーを取得する
    final String? token = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SessionKeyWebView()),
    );

    if (token != null) {
      await saveSessionKey(token);
      return token;
    }
    return null;
  }
}

/// **WebView でセッションキーを取得**
class SessionKeyWebView extends StatefulWidget {
  const SessionKeyWebView({super.key});

  @override
  _SessionKeyWebViewState createState() => _SessionKeyWebViewState();
}

class _SessionKeyWebViewState extends State<SessionKeyWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (String url) {
                if (url.contains("generated-token=")) {
                  final Uri uri = Uri.parse(url);
                  final String? token = uri.queryParameters["generated-token"];
                  if (token != null) {
                    Navigator.pop(context, token);
                  }
                }
              },
            ),
          )
          ..loadRequest(
            Uri.parse(
              "https://milc.dev.sharo-dev.com/?app=account&dialog=registerNewApp&newApp=Carry-App",
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("セッションキー取得")),
      body: WebViewWidget(controller: _controller),
    );
  }
}
