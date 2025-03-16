import 'package:flutter/material.dart';
import 'package:health/health.dart';

class MainScreen extends StatelessWidget {
  final String? sessionKey; // WebCarry セッションキー
  final String? riotPUUID; // Riot認証で取得した PUUID
  final String? riotGameName; // Riot認証で取得した gameName
  final String? riotTagLine; // Riot認証で取得した tagLine
  final List<HealthDataPoint>? sleepData; // 過去7日分の睡眠データ

  const MainScreen({
    super.key,
    this.sessionKey,
    this.riotPUUID,
    this.riotGameName,
    this.riotTagLine,
    this.sleepData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Carry App - Main Screen")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1) WebCarryセッションキーの表示
            Text(
              "【WebCarry】セッションキー: ${sessionKey ?? '未取得'}",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            // 2) Riot認証で取得した情報
            const Text(
              "【Riot認証】ユーザー情報",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text("PUUID: ${riotPUUID ?? '未取得'}"),
            Text("Game Name: ${riotGameName ?? '未取得'}"),
            Text("Tag Line: ${riotTagLine ?? '未取得'}"),
            const SizedBox(height: 20),

            // 3) 過去7日分の睡眠データの表示
            const Text(
              "過去7日分の睡眠データ",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (sleepData != null && sleepData!.isNotEmpty)
              ...sleepData!.map((data) {
                final start = data.dateFrom.toLocal();
                final end = data.dateTo.toLocal();
                return Text("開始: $start, 終了: $end");
              }).toList()
            else
              const Text("睡眠データはありません"),
          ],
        ),
      ),
    );
  }
}
