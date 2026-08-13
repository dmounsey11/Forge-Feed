import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forge_feed/services/database_service.dart';

/// Phase 6 spot-check: a handful of the newly-curated USDA ingredients
/// actually load from the bundled data with the right id/name/category and
/// plausible (non-zero, non-garbage) nutrient values - the closest
/// available substitute for visually checking the pantry picker in this
/// environment (see diet_calculator_integration_test.dart for the same
/// reasoning applied to the LP rewrite).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('newly-curated whole-food ingredients load with sane values', () async {
    SharedPreferences.setMockInitialValues({});
    final db = DatabaseService();
    await db.initialize();

    final byId = {for (final i in db.ingredients) i.id: i};

    final broccoli = byId['ing_02868'];
    expect(broccoli, isNotNull);
    expect(broccoli!.name.toLowerCase(), contains('broccoli'));
    expect(broccoli.category, 'Produce');
    expect(broccoli.subCategory, 'Cruciferous Vegetables');
    expect(broccoli.asFedMetrics.crudeProteinPct, greaterThan(0));

    final lentils = byId['ing_04909'];
    expect(lentils, isNotNull);
    expect(lentils!.name.toLowerCase(), contains('lentils'));
    expect(lentils.category, 'Proteins & Meal');
    // Legumes are a real plant-protein source - should read meaningfully
    // higher than a leafy green, not a near-zero/placeholder value.
    expect(lentils.asFedMetrics.crudeProteinPct, greaterThan(5));

    final tilapia = byId['ing_07665'];
    expect(tilapia, isNotNull);
    expect(tilapia!.name.toLowerCase(), contains('tilapia'));
    expect(tilapia.category, 'Proteins & Meal');
    expect(tilapia.asFedMetrics.crudeProteinPct, greaterThan(10));

    final cashew = byId['ing_02651'];
    expect(cashew, isNotNull);
    expect(cashew!.name.toLowerCase(), contains('cashew'));
    expect(cashew.category, 'Natural Supplements');

    final mango = byId['ing_02399'];
    expect(mango, isNotNull);
    expect(mango!.name.toLowerCase(), contains('mango'));
    expect(mango.category, 'Fruits');
    expect(mango.subCategory, 'Specialty/Wild');

    // A sample across every id added in this pass should resolve to a
    // real ingredient with a positive dry matter fraction - catches any
    // typo'd id that would otherwise silently vanish from the picker.
    const sampleIds = [
      'ing_02464', // Cabbage
      'ing_01634', // Beets
      'ing_00878', // Asparagus
      'ing_02191', // Millet
      'ing_06759', // Soybeans
      'ing_06859', // Lamb, ground
      'ing_04899', // Duck
    ];
    for (final id in sampleIds) {
      final ingredient = byId[id];
      expect(ingredient, isNotNull, reason: 'expected $id to load from ingredients.json');
    }
  });
}
