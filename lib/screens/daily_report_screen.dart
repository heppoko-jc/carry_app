import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/daily_report_service.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  // ゲーム部分
  int _motivation = 3;
  int _selfEval = 3;
  final TextEditingController _gameCommentCtrl = TextEditingController();

  // 体調部分
  bool _isHealthBad = false;
  final TextEditingController _symptomCtrl = TextEditingController();
  final TextEditingController _placeCtrl = TextEditingController();
  double _painLevel = 5; // Slider
  final TextEditingController _healthCommentCtrl = TextEditingController();

  // 日付の項目 (前日が初期値)
  DateTime _selectedDate = DateTime.now().subtract(const Duration(days: 1));

  bool _isLoading = false;
  final DailyReportService _dailyService = DailyReportService();

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat("yyyy-MM-dd").format(_selectedDate);

    return Scaffold(
      appBar: AppBar(title: const Text("日報フォーム")),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 日付選択UI
                    Row(
                      children: [
                        const Text("日報日付: "),
                        Text(dateStr),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _pickDate,
                          child: const Text("日付変更"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ================== ゲーム関連UI (略) ==================
                    const Text(
                      "■ ゲーム",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // モチベ(ラジオ 1..5)
                    const Text("ゲームのモチベーション(1~5)"),
                    Row(
                      children: List.generate(5, (index) {
                        final val = index + 1;
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

                    // 自己評価(ラジオ 1..5)
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

                    // コメント(TextField)
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

                    // ================== 体調関連UI ==================
                    const Text(
                      "■ 体調について",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
                      const Text("症状"),
                      TextField(
                        controller: _symptomCtrl,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '症状の内容',
                        ),
                      ),
                      const SizedBox(height: 10),

                      const Text("場所"),
                      TextField(
                        controller: _placeCtrl,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '痛みや不調のある場所',
                        ),
                      ),
                      const SizedBox(height: 10),

                      const Text("痛み/倦怠感(1~10)"),
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

                    // サブミット
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

  /// 日付選択
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final pick = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.subtract(const Duration(days: 1)), // 当日以降不可
    );
    if (pick != null) {
      setState(() {
        _selectedDate = pick;
      });
    }
  }

  /// フォーム送信
  Future<void> _submitForm() async {
    setState(() => _isLoading = true);

    // 1) 選択日付 -> 12:00 → ms
    final localDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      12,
    );
    final reportDateMs = localDate.millisecondsSinceEpoch;

    // 2) 全キーを作る
    //   ゲームコメントや体調情報が空文字なら "" を入れる
    //   painLevelは文字列で送る => ex. "5"
    final dailyReport = <String, dynamic>{};

    // ゲーム
    dailyReport["motivation"] = _motivation;
    dailyReport["selfEvaluation"] = _selfEval;
    dailyReport["G-comment"] = _gameCommentCtrl.text.trim(); // 空なら ""

    // 体調
    dailyReport["isBad"] = _isHealthBad;
    if (_isHealthBad) {
      dailyReport["symptom"] = _symptomCtrl.text.trim();
      dailyReport["place"] = _placeCtrl.text.trim();
      dailyReport["painLevel"] = _painLevel.toInt().toString(); // ex. "5"
      dailyReport["M-comment"] = _healthCommentCtrl.text.trim();
    } else {
      // 悪くない場合もキーを追加して空を入れる
      dailyReport["symptom"] = "";
      dailyReport["place"] = "";
      dailyReport["painLevel"] = ""; // 文字列で空
      dailyReport["M-comment"] = "";
    }

    // 3) 送信
    final ok = await _dailyService.sendDailyReport(
      reportData: dailyReport,
      reportDateMs: reportDateMs,
    );

    if (!ok) {
      print("❌ 日報送信に失敗");
    } else {
      print("✅ 日報送信成功 => $dailyReport");
    }

    setState(() => _isLoading = false);

    // メイン画面にtureを返して戻る
    Navigator.pop(context, true);
  }
}
