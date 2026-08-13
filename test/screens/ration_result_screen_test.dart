import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:forge_feed/models/ration_result.dart';
import 'package:forge_feed/screens/ration_result_screen.dart';
import 'package:forge_feed/services/tier_service.dart';

void main() {
  testWidgets(
    'critical warnings render as a bordered icon banner, low warnings as muted subtext',
    (tester) async {
      const result = RationResult(
        totalWeightLbs: 5.0,
        baseItems: [],
        supplementItems: [],
        nutrientComparisons: [],
        warnings: [
          RationWarning(message: 'Copper is dangerously high', severity: WarningSeverity.critical),
          RationWarning(message: 'Just a heads up', severity: WarningSeverity.low),
        ],
        healthNotes: [],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<TierService>(
          create: (_) => TierService(),
          child: const MaterialApp(
            home: RationResultScreen(result: result, profileName: 'Test Animal'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Copper is dangerously high'), findsOneWidget);
      expect(find.text('Just a heads up'), findsOneWidget);
      // The banner treatment (icon + bold white text) is unique to
      // critical/high severity - a plain low-severity warning gets neither.
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      final criticalText = tester.widget<Text>(find.text('Copper is dangerously high'));
      expect(criticalText.style?.fontWeight, FontWeight.bold);
      expect(criticalText.style?.color, Colors.white);

      final lowText = tester.widget<Text>(find.text('Just a heads up'));
      expect(lowText.style?.color, Colors.white54);
    },
  );
}
