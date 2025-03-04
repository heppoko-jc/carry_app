import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carry_app/main.dart';

void main() {
  testWidgets('アプリが起動し、ボタンが表示されているか確認', (WidgetTester tester) async {
    // ウィジェットを構築
    await tester.pumpWidget(MyApp());

    // "睡眠データを取得" ボタンがあることを確認
    expect(find.text('睡眠データを取得'), findsOneWidget);
  });
}
