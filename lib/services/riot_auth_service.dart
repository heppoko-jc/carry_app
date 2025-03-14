import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;

class RiotAuthService {
  final String riotAuthBaseUrl = "https://auth.riotgames.com";
  final String clientId =
      "d5f020cc-f135-45d6-b666-86564c63ac49"; // ここに登録したClient IDを入力
  final String clientSecret =
      "nUIywpxT4U2kaMAglo5Mo6HowR1R7RMf86Io6sne4Zk"; // ここに登録したClient Secretを入力
  final String redirectUri = "https://milc.dev.sharo-dev.com";
  final String tokenEndpoint = "https://auth.riotgames.com/token";
  final String userInfoEndpoint = "https://auth.riotgames.com/userinfo";

  /// **Riot Games OAuth 認証を行い、アクセストークンを取得**
  Future<String?> authenticate(BuildContext context) async {
    final String authUrl =
        "$riotAuthBaseUrl/authorize?redirect_uri=$redirectUri&client_id=$clientId&response_type=code&scope=openid";

    print("🔗 認証URL: $authUrl"); // URLをログ出力

    final String? authCode = await _launchWebViewForAuth(context, authUrl);
    if (authCode == null) {
      print("❌ 認証コードが取得できませんでした");
      return null;
    }

    print("✅ 認証コード取得成功: $authCode");

    return await _exchangeAuthCodeForToken(authCode);
  }

  /// **WebViewを開いて認証を行い、認証コードを取得**
  Future<String?> _launchWebViewForAuth(
    BuildContext context,
    String url,
  ) async {
    final Completer<String?> completer = Completer<String?>();

    final WebViewController controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (String finalUrl) {
                print("📡 ページ読み込み完了: $finalUrl"); // URL遷移のログを出す
              },
              onNavigationRequest: (NavigationRequest request) {
                print("🔍 ナビゲーションリクエスト: ${request.url}"); // 遷移のログ

                // 認証が完了し、リダイレクトURLに `code=` が含まれる場合
                if (request.url.startsWith(redirectUri) &&
                    request.url.contains("code=")) {
                  Uri uri = Uri.parse(request.url);
                  String? code = uri.queryParameters["code"];

                  if (code != null) {
                    print("✅ 認証成功！認証コード取得: $code");
                    Navigator.pop(context); // WebViewを閉じる
                    completer.complete(code);
                  }
                }
                return NavigationDecision.navigate;
              },
            ),
          )
          ..loadRequest(Uri.parse(url));

    // WebViewを表示
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              appBar: AppBar(title: const Text("Riot Games 認証")),
              body: WebViewWidget(controller: controller),
            ),
      ),
    );

    return completer.future;
  }

  /// **認証コードをアクセストークンに変換**
  Future<String?> _exchangeAuthCodeForToken(String authCode) async {
    print("🔄 認証コードをアクセストークンに交換中...");

    final response = await http.post(
      Uri.parse(tokenEndpoint),
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "Authorization":
            "Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}",
      },
      body: {
        "grant_type": "authorization_code",
        "code": authCode,
        "redirect_uri": redirectUri,
      },
    );

    print("🛜 トークンエンドポイントのレスポンス: ${response.body}");

    if (response.statusCode == 200) {
      final Map<String, dynamic> tokenData = json.decode(response.body);
      print("✅ アクセストークン取得成功: ${tokenData["access_token"]}");
      return tokenData["access_token"]; // アクセストークンを取得
    } else {
      print("❌ アクセストークンの取得に失敗: ${response.body}");
      return null;
    }
  }

  /// **アクセストークンを使用してユーザー情報を取得**
  Future<Map<String, dynamic>?> getUserInfo(String accessToken) async {
    print("🔄 Riot Games ユーザー情報取得中...");

    final response = await http.get(
      Uri.parse(userInfoEndpoint),
      headers: {"Authorization": "Bearer $accessToken"},
    );

    print("🛜 /userinfo のレスポンス: ${response.body}");

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      print("❌ ユーザー情報の取得に失敗");
      return null;
    }
  }
}
