import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth_2048/l10n/qa_feedback_strings.dart';

void main() {
  testWidgets('Q&A and feedback strings follow the active locale', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: const [Locale('en'), Locale('zh')],
        home: Builder(
          builder: (context) {
            final strings = QaFeedbackStrings.of(context);
            return Column(
              children: [
                Text(strings.qaTitle),
                Text(strings.qaQuestion1),
                Text(strings.feedbackTitle),
                Text(strings.feedbackSendFailed),
              ],
            );
          },
        ),
      ),
    );

    expect(find.text('常見問題'), findsOneWidget);
    expect(find.text('如何遊玩重生 2048？'), findsOneWidget);
    expect(find.text('聯絡／意見回饋'), findsOneWidget);
    expect(find.text('無法送出訊息，請稍後再試。'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('zh')],
        home: Builder(
          builder: (context) {
            final strings = QaFeedbackStrings.of(context);
            return Column(
              children: [
                Text(strings.qaTitle),
                Text(strings.qaQuestion1),
                Text(strings.feedbackTitle),
                Text(strings.feedbackSendFailed),
              ],
            );
          },
        ),
      ),
    );

    expect(find.text('Q&A'), findsOneWidget);
    expect(find.text('How do I play Rebirth 2048?'), findsOneWidget);
    expect(find.text('Contact / Feedback'), findsOneWidget);
    expect(find.text('Unable to send your message. Please try again.'), findsOneWidget);
  });
}
