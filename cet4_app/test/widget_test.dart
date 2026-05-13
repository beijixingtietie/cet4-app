import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cet4_app/app.dart';
import 'package:cet4_app/provider/user_provider.dart';
import 'package:cet4_app/provider/navigation_provider.dart';
import 'package:cet4_app/provider/study_provider.dart';
import 'package:cet4_app/provider/ai_provider.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => UserProvider()),
          ChangeNotifierProvider(create: (_) => NavigationProvider()),
          ChangeNotifierProvider(create: (_) => StudyProvider()),
          ChangeNotifierProvider(create: (_) => AiProvider()),
        ],
        child: const Cet4App(),
      ),
    );

    // 等待异步初始化完成
    await tester.pumpAndSettle();
  });
}
