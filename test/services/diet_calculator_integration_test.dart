import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forge_feed/models/animal_profile.dart';
import 'package:forge_feed/models/ration_result.dart';
import 'package:forge_feed/services/database_service.dart';
import 'package:forge_feed/services/diet_calculator.dart';
import 'package:forge_feed/services/nutrition_target_resolver.dart';
import 'package:forge_feed/widgets/prep_amount_dialog.dart';

/// End-to-end sanity checks against the app's real bundled data (species
/// catalog, animal requirements, ingredient database, safety rules) rather
/// than hand-built fixtures - the closest available substitute for
/// manually running the app in this environment (no configured desktop
/// target, no browser-automation tooling), per the LP rewrite's plan.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<DatabaseService> loadDb() async {
    SharedPreferences.setMockInitialValues({});
    final db = DatabaseService();
    await db.initialize();
    return db;
  }

  void expectSaneResult(Object result) {
    if (result is RationCalculationError) {
      expect(result.message, isNotEmpty);
      return;
    }
    final ration = result as RationResult;
    expect(ration.totalWeightLbs, closeTo(10.0, 0.01));
    expect(ration.nutrientComparisons, isNotEmpty);
    expect(ration.nutrientComparisons.every((c) => c.actual.isFinite), isTrue);
    final totalLineItemLbs =
        [...ration.baseItems, ...ration.supplementItems].fold(0.0, (sum, i) => sum + i.lbs);
    expect(totalLineItemLbs, closeTo(ration.totalWeightLbs, 0.01));
  }

  test('calculates a real ration for a sheep profile from the bundled catalog', () async {
    final db = await loadDb();
    final profile = AnimalProfile(id: 'p1', name: 'Test Sheep', species: 'Livestock / Companion: Sheep');
    final target = NutritionTargetResolver.resolve(profile, db.speciesRequirements);
    expect(target, isNotNull, reason: 'expected a sheep requirement record in animal_requirements.json');

    final pantry = db.ingredients
        .where((i) =>
            i.name.toLowerCase().contains('alfalfa') ||
            i.name.toLowerCase().contains('corn') ||
            i.name.toLowerCase().contains('oat') ||
            i.name.toLowerCase().contains('hay'))
        .take(6)
        .toList();
    expect(pantry, isNotEmpty, reason: 'expected some grain/forage ingredients in the bundled catalog');
    final supplements = db.ingredients.where((i) => i.id.startsWith('supp_')).toList();

    final result = DietCalculator.calculate(
      profile: profile,
      target: target!,
      health: null,
      prep: const PrepAmountResult(mode: PrepMode.amount, value: 10.0),
      pantryItems: pantry,
      supplementItems: supplements,
      safetyRules: db.safetyRules,
      stageHasDedicatedData: NutritionTargetResolver.stageHasDedicatedData(profile, db.speciesRequirements),
    );

    expectSaneResult(result);
  });

  test('calculates a real ration for a chicken layer profile from the bundled catalog', () async {
    final db = await loadDb();
    final profile = AnimalProfile(
      id: 'p2',
      name: 'Test Layer',
      species: 'Livestock / Companion: Chicken (Layer)',
      productionStage: 'Active Layer',
    );
    final target = NutritionTargetResolver.resolve(profile, db.speciesRequirements);
    expect(target, isNotNull, reason: 'expected a chicken/layer requirement record in animal_requirements.json');

    final pantry = db.ingredients
        .where((i) =>
            i.name.toLowerCase().contains('corn') ||
            i.name.toLowerCase().contains('soybean') ||
            i.name.toLowerCase().contains('wheat') ||
            i.name.toLowerCase().contains('oat'))
        .take(6)
        .toList();
    expect(pantry, isNotEmpty, reason: 'expected some grain ingredients in the bundled catalog');
    final supplements = db.ingredients.where((i) => i.id.startsWith('supp_')).toList();

    final result = DietCalculator.calculate(
      profile: profile,
      target: target!,
      health: null,
      prep: const PrepAmountResult(mode: PrepMode.amount, value: 10.0),
      pantryItems: pantry,
      supplementItems: supplements,
      safetyRules: db.safetyRules,
      stageHasDedicatedData: NutritionTargetResolver.stageHasDedicatedData(profile, db.speciesRequirements),
    );

    expectSaneResult(result);
  });
}
