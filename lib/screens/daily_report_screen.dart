// daily_report_screen.dart
import 'package:flutter/material.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  // -- ゲーム --
  int _motivation = 3; // 五段階(1..5)の初期値
  int _selfEval = 3; // 五段階(1..5)の初期値
  final TextEditingController _gameCommentCtrl = TextEditingController();

  // -- 体調 --
  bool _isHealthBad = false;
  final TextEditingController _symptomCtrl = TextEditingController();
  final TextEditingController _placeCtrl = TextEditingController();
  double _painLevel = 5; // 1..10
  final TextEditingController _healthCommentCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("日報フォーム")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== ゲーム部分 ==========
            const Text(
              "■ ゲーム",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // ゲームのモチベーション(五段階)
            const Text("ゲームのモチベーション(1~5)"),
            Row(
              children: List.generate(5, (index) {
                final val = index + 1; // 1..5
                return Row(
                  children: [
                    Radio<int>(
                      value: val,
                      groupValue: _motivation,
                      onChanged: (v) {
                        setState(() {
                          _motivation = v!;
                        });
                      },
                    ),
                    Text("$val"),
                  ],
                );
              }),
            ),
            const SizedBox(height: 10),

            // ゲームの自己評価(五段階)
            const Text("ゲームの自己評価(1~5)"),
            Row(
              children: List.generate(5, (index) {
                final val = index + 1;
                return Row(
                  children: [
                    Radio<int>(
                      value: val,
                      groupValue: _selfEval,
                      onChanged: (v) {
                        setState(() {
                          _selfEval = v!;
                        });
                      },
                    ),
                    Text("$val"),
                  ],
                );
              }),
            ),
            const SizedBox(height: 10),

            // ゲームに関するコメント (記述式)
            const Text("ゲームに関するコメント"),
            TextField(
              controller: _gameCommentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '自由記述',
              ),
            ),

            const SizedBox(height: 20),

            // ========== 体調部分 ==========
            const Text(
              "■ 体調について",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                const Text("体調が悪いか？"),
                Switch(
                  value: _isHealthBad,
                  onChanged: (val) {
                    setState(() {
                      _isHealthBad = val;
                    });
                  },
                ),
              ],
            ),
            if (_isHealthBad) ...[
              // 症状(記述)
              const Text("症状"),
              TextField(
                controller: _symptomCtrl,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '症状の内容',
                ),
              ),
              const SizedBox(height: 10),

              // 場所(記述)
              const Text("場所"),
              TextField(
                controller: _placeCtrl,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '痛みや不調のある場所',
                ),
              ),
              const SizedBox(height: 10),

              // 痛み倦怠感 (1~10 slider)
              const Text("痛み/倦怠感の度合い(1~10)"),
              Slider(
                min: 1,
                max: 10,
                divisions: 9,
                value: _painLevel,
                label: "${_painLevel.toInt()}",
                onChanged: (val) {
                  setState(() {
                    _painLevel = val;
                  });
                },
              ),
              const SizedBox(height: 10),

              // 補足コメント
              const Text("補足コメント"),
              TextField(
                controller: _healthCommentCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '体調に関する補足',
                ),
              ),
              const SizedBox(height: 10),
            ],

            const SizedBox(height: 20),

            // ========== サブミットボタン ==========
            Center(
              child: ElevatedButton(
                onPressed: _submitForm,
                child: const Text("サブミット"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// フォームをJsonにしてダミー送信 → メイン画面に戻る
  void _submitForm() {
    // 1. フォームの内容をJson形式でまとめ (ダミー)
    final Map<String, dynamic> dailyReport = {
      "game": {
        "motivation": _motivation,
        "selfEvaluation": _selfEval,
        "comment": _gameCommentCtrl.text,
      },
      "health": {
        "isBad": _isHealthBad,
        if (_isHealthBad) ...{
          "symptom": _symptomCtrl.text,
          "place": _placeCtrl.text,
          "painLevel": _painLevel.toInt(),
          "comment": _healthCommentCtrl.text,
        },
      },
    };

    // TODO: ここで WebCarry へ送信
    // いまはダミーでprint
    print("DailyReport JSON => $dailyReport");

    // 2. メイン画面に戻る
    Navigator.pop(context);
  }
}
