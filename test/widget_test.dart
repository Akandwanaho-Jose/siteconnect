import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siteconnect/shared/widgets/app_button.dart';

void main() {
  testWidgets('AppButton renders and handles taps', (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(label: 'Sign in', onPressed: () => tapCount++),
        ),
      ),
    );

    expect(find.text('Sign in'), findsOneWidget);

    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(tapCount, 1);
  });
}
