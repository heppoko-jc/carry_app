import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;

class RiotAuthService {
  final String riotAuthBaseUrl = "https://auth.riotgames.com";
  final String riotApiBaseUrl = "https://asia.api.riotgames.com";
  final String clientId =
      "d5f020cc-f135-45d6-b666-86564c63ac49"; // Riot APIで取得したクライアントID
  final String clientSecret =
      "nUIywpxT4U2kaMAglo5Mo6HowR1R7RMf86Io6sne4Zk"; // Riot APIで取得したクライアントシークレット
  final String redirectUri = "https://milc.dev.sharo-dev.com"; // リダイレクト先
  final String tokenEndpoint = "https://auth.riotgames.com/token";
  final String accountEndpoint = "/riot/account/v1/accounts/me";
  final String apiKey =
      "RGAPI-4d30ea24-b988-46f0-b15c-1710fe7d071d"; // Riot APIキー

  /// **Riot認証フロー**
  Future<String?> authenticate(BuildContext context) async {
    final String authUrl =
        "$riotAuthBaseUrl/authorize?redirect_uri=$redirectUri&client_id=$clientId&response_type=code&scope=openid";

    final String? authCode = await _launchWebViewForAuth(context, authUrl);
    if (authCode == null) {
      debugPrint("❌ 認証コードの取得に失敗");
      return null;
    }

    debugPrint("✅ 認証コード取得: $authCode");

    return await _exchangeAuthCodeForToken(authCode);
  }

  /// **WebViewを開き、Riot認証を行い、リダイレクトURLから認証コードを取得**
  Future<String?> _launchWebViewForAuth(
    BuildContext context,
    String url,
  ) async {
    Completer<String?> completer = Completer<String?>();

    final controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (String url) {
                debugPrint("🔗 現在のURL: $url");
                if (url.startsWith(redirectUri)) {
                  Uri uri = Uri.parse(url);
                  String? code = uri.queryParameters["code"];
                  if (code != null) {
                    debugPrint("✅ 認証コード取得成功: $code");
                    completer.complete(code);
                    Navigator.pop(context); // WebViewを閉じる
                  }
                }
              },
            ),
          )
          ..loadRequest(Uri.parse(url));

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

  /// **認証コードをアクセストークンに交換**
  Future<String?> _exchangeAuthCodeForToken(String authCode) async {
    final response = await http.post(
      Uri.parse(tokenEndpoint),
      headers: {
        "Authorization":
            "Basic ${base64Encode(utf8.encode("$clientId:$clientSecret"))}",
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: {
        "grant_type": "authorization_code",
        "code": authCode,
        "redirect_uri": redirectUri,
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      String accessToken = data["access_token"];
      debugPrint("✅ アクセストークン取得成功: $accessToken");
      return accessToken;
    } else {
      debugPrint("❌ アクセストークンの取得に失敗: ${response.body}");
      return null;
    }
  }

  /// **Riot APIからアカウント情報 (PUUID, gameName, tagLine) を取得**
  Future<Map<String, dynamic>?> getAccountInfo(String accessToken) async {
    final response = await http.get(
      Uri.parse("$riotApiBaseUrl$accountEndpoint"),
      headers: {"Authorization": "Bearer $accessToken"},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> userInfo = json.decode(response.body);
      debugPrint("✅ アカウント情報取得成功: $userInfo");
      return userInfo;
    } else {
      debugPrint("❌ アカウント情報取得に失敗: ${response.body}");
      return null;
    }
  }
}
