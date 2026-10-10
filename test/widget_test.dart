import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roast_n_rizz/config/app_config.dart';
import 'package:roast_n_rizz/main.dart';

void main() {
  test('Loads the worker URL from environment config', () async {
    await dotenv.load(fileName: '.env', isOptional: true);

    expect(AppConfig.workerUrl, isNotEmpty);
    expect(AppConfig.workerUrl, contains('http'));
  });

  testWidgets('Home page renders the mode and photo controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RoastNRizzApp());
    await tester.pumpAndSettle();

    expect(find.text('ROASTNRIZZ: AI PHOTO ROAST'), findsOneWidget);
    expect(find.text('Rizz'), findsOneWidget);
    expect(find.text('Roast'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });
}
