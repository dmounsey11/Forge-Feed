import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forge_feed/services/database_service.dart';
import 'package:forge_feed/services/tier_service.dart';
import 'package:forge_feed/widgets/add_profile_dialog.dart';

typedef _Candidate = ({String category, String subgroup, String species});

/// Finds the first catalog species (in its category/subgroup context) that
/// [DatabaseService.unsupportedSpecies] says has no matching
/// animal_requirements.json entry - a real example of the "no data yet" case
/// Phase 4 is meant to surface directly in the picker.
_Candidate? _findUnsupportedCandidate(DatabaseService db) {
  for (final category in db.speciesCatalog) {
    for (final subgroup in category.subgroups) {
      for (final species in subgroup.species) {
        if (db.unsupportedSpecies.contains('${category.name}: $species')) {
          return (category: category.name, subgroup: subgroup.name, species: species);
        }
      }
    }
  }
  return null;
}

Future<void> _openDropdownAndTap(WidgetTester tester, Key dropdownKey, String optionText) async {
  await tester.tap(find.byKey(dropdownKey));
  await tester.pumpAndSettle();
  await tester.tap(find.text(optionText).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'species picker greys out and blocks selection of a species with no nutrition data',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final db = DatabaseService();
      final tier = TierService();
      // Real asset/prefs I/O needs the real event loop - testWidgets' default
      // fake-async zone never resolves it otherwise.
      await tester.runAsync(() async {
        await db.initialize();
        await tier.initialize();
      });
      // Pro tier so the tier-lock icon/dialog never masks the no-data case.
      tier.cycleTier();
      tier.cycleTier();

      final candidate = _findUnsupportedCandidate(db);
      expect(
        candidate,
        isNotNull,
        reason: 'expected at least one species_catalog.json entry with no matching animal_requirements.json record',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DatabaseService>.value(value: db),
            ChangeNotifierProvider<TierService>.value(value: tier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => AddProfileDialog(onProfileSaved: (_) {}),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await _openDropdownAndTap(tester, const Key('categoryDropdown'), candidate!.category);

      // Only present when the category has more than one subgroup.
      if (find.byKey(const Key('subgroupDropdown')).evaluate().isNotEmpty) {
        await _openDropdownAndTap(tester, const Key('subgroupDropdown'), candidate.subgroup);
      }

      // Open the species dropdown. Its menu is a lazily-built ListView, so
      // an off-screen item (like our candidate, which may sort well away
      // from the currently-selected one) won't exist in the tree until
      // scrolled into view - scroll to the top of the menu, then search
      // downward for it.
      await tester.tap(find.byKey(const Key('speciesDropdown')));
      await tester.pumpAndSettle();
      final menuScrollable = find.byType(Scrollable).last;
      await tester.drag(menuScrollable, const Offset(0, 10000));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(candidate.species), 80, scrollable: menuScrollable);

      expect(find.byIcon(Icons.info_outline), findsWidgets);

      final beforeSelection = find.text(candidate.species).evaluate().isNotEmpty;
      expect(beforeSelection, isTrue, reason: 'the no-data species should still be listed, just marked');

      await tester.tap(find.text(candidate.species).last);
      await tester.pumpAndSettle();

      // Selecting it should be blocked with an explanatory dialog rather
      // than silently committing the selection.
      expect(find.text('No Nutrition Data Yet'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    },
  );
}
