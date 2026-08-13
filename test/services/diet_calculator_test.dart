import 'package:flutter_test/flutter_test.dart';
import 'package:forge_feed/models/animal_profile.dart';
import 'package:forge_feed/models/ingredient.dart';
import 'package:forge_feed/models/ration_result.dart';
import 'package:forge_feed/models/safety_rule.dart';
import 'package:forge_feed/models/species_requirement.dart';
import 'package:forge_feed/services/diet_calculator.dart';
import 'package:forge_feed/widgets/prep_amount_dialog.dart';

/// A wide-open species target: every range is permissive enough that a
/// blend can't accidentally trip a comparison/warning the test isn't
/// explicitly checking for. Individual tests narrow whichever fields they
/// care about.
SpeciesRequirement _target({
  double minProteinPerc = 0,
  double maxProteinPerc = 100,
  double minCalciumPerc = 0,
  double maxCalciumPerc = 100,
  double minPhosphorusPerc = 0,
  double maxPhosphorusPerc = 100,
  double minSodiumPerc = 0,
  double maxSodiumPerc = 100,
  double minMeKcal = 0,
  double maxMeKcal = 1000000,
  double targetWeightKg = 5.0,
}) {
  return SpeciesRequirement(
    id: 'req_test',
    species: 'test species',
    displayName: 'Test Species',
    lifeStage: 'maintenance',
    targetWeightKg: targetWeightKg,
    minProteinPerc: minProteinPerc,
    maxProteinPerc: maxProteinPerc,
    minMeKcal: minMeKcal,
    maxMeKcal: maxMeKcal,
    minCalciumPerc: minCalciumPerc,
    maxCalciumPerc: maxCalciumPerc,
    minPhosphorusPerc: minPhosphorusPerc,
    maxPhosphorusPerc: maxPhosphorusPerc,
    minSodiumPerc: minSodiumPerc,
    maxSodiumPerc: maxSodiumPerc,
    minLysinePerc: 0,
    minMethioninePerc: 0,
  );
}

Ingredient _food(
  String id, {
  double proteinPct = 10,
  double calciumPct = 0,
  double phosphorusPct = 0,
  double copperPpm = 0,
  double molybdenumPpm = 0,
  double oxalatePct = 0,
  double? dryMatterPct,
}) {
  return Ingredient(
    id: id,
    name: id,
    category: 'Proteins & Meal',
    asFedMetrics: AsFedMetrics(
      crudeProteinPct: proteinPct,
      calciumPct: calciumPct,
      phosphorusPct: phosphorusPct,
      copperPpm: copperPpm,
      molybdenumPpm: molybdenumPpm,
      oxalatePct: oxalatePct,
      dryMatterPct: dryMatterPct,
    ),
  );
}

AnimalProfile _profile({String species = 'Livestock: Generic', String productionStage = 'Healthy / Normal'}) {
  return AnimalProfile(id: 'p1', name: 'Test Animal', species: species, productionStage: productionStage);
}

const _fixedAmount = PrepAmountResult(mode: PrepMode.amount, value: 10.0);

RationResult _calc({
  required AnimalProfile profile,
  required SpeciesRequirement target,
  required List<Ingredient> pantryItems,
  List<Ingredient> supplementItems = const [],
  List<SafetyRule> safetyRules = const [],
  bool stageHasDedicatedData = true,
}) {
  return DietCalculator.calculate(
    profile: profile,
    target: target,
    health: null,
    prep: _fixedAmount,
    pantryItems: pantryItems,
    supplementItems: supplementItems,
    safetyRules: safetyRules,
    stageHasDedicatedData: stageHasDedicatedData,
  );
}

void main() {
  group('baseline nutrient requirement matching', () {
    test('single high-protein ingredient reports status high against a lower max', () {
      final result = _calc(
        profile: _profile(),
        target: _target(minProteinPerc: 10, maxProteinPerc: 20),
        pantryItems: [_food('a', proteinPct: 50)],
      );
      final protein = result.nutrientComparisons.firstWhere((c) => c.label == 'Protein');
      expect(protein.status, NutrientStatus.high);
      expect(protein.actual, closeTo(50, 0.001));
    });

    test('single low-protein ingredient reports status low against a higher min', () {
      final result = _calc(
        profile: _profile(),
        target: _target(minProteinPerc: 20, maxProteinPerc: 30),
        pantryItems: [_food('a', proteinPct: 5)],
      );
      final protein = result.nutrientComparisons.firstWhere((c) => c.label == 'Protein');
      expect(protein.status, NutrientStatus.low);
    });

    test('two anchor ingredients pearson-blend to the target protein midpoint', () {
      // Anchors bracket the 15% midpoint (14-16 range); with only two
      // candidates and no calcium/phosphorus/sodium deficit to fill, the
      // final blend is exactly the two anchors solved for the midpoint.
      final result = _calc(
        profile: _profile(),
        target: _target(minProteinPerc: 14, maxProteinPerc: 16),
        pantryItems: [_food('high', proteinPct: 30), _food('low', proteinPct: 5)],
      );
      final protein = result.nutrientComparisons.firstWhere((c) => c.label == 'Protein');
      expect(protein.status, NutrientStatus.onTrack);
      expect(protein.actual, closeTo(15.0, 0.01));
    });
  });

  group('dry-matter basis conversion + toxicity ceilings', () {
    final copperRule = SafetyRule(
      ruleId: 'cu_cap',
      targetType: 'dm_concentration',
      targetName: 'Cu_ppm_DM',
      maxValue: 10.0,
      severity: 'HIGH',
      warningMessage: 'Copper level unsafe',
    );

    test('as-fed copper below the DM-basis cap does not warn', () {
      // 4 ppm as-fed / 50% DM = 8 ppm DM, under the 10 ppm cap.
      final result = _calc(
        profile: _profile(),
        target: _target(),
        pantryItems: [_food('a', proteinPct: 20, copperPpm: 4, dryMatterPct: 50)],
        safetyRules: [copperRule],
      );
      expect(result.warnings.any((w) => w.message.contains('Copper level unsafe')), isFalse);
    });

    test('as-fed copper over the DM-basis cap warns with the converted value', () {
      // 6 ppm as-fed / 50% DM = 12 ppm DM, over the 10 ppm cap.
      final result = _calc(
        profile: _profile(),
        target: _target(),
        pantryItems: [_food('a', proteinPct: 20, copperPpm: 6, dryMatterPct: 50)],
        safetyRules: [copperRule],
      );
      final warning = result.warnings.firstWhere((w) => w.message.contains('Copper level unsafe'));
      expect(warning.message, contains('12.0'));
      expect(warning.severity, WarningSeverity.high);
    });

    test('a null dry matter % is treated as fully dry (100%), not a guess', () {
      // 6 ppm as-fed / 100% DM = 6 ppm DM, under the 10 ppm cap, even though
      // the same as-fed value tripped the cap in the 50%-DM case above.
      final result = _calc(
        profile: _profile(),
        target: _target(),
        pantryItems: [_food('a', proteinPct: 20, copperPpm: 6, dryMatterPct: null)],
        safetyRules: [copperRule],
      );
      expect(result.warnings.any((w) => w.message.contains('Copper level unsafe')), isFalse);
    });

    test('oxalate DM-basis cap fires the same way as copper', () {
      final oxalateRule = SafetyRule(
        ruleId: 'ox_cap',
        targetType: 'dm_concentration',
        targetName: 'Oxalate_pct_DM',
        maxValue: 1.0,
        severity: 'HIGH',
        warningMessage: 'Oxalate level unsafe',
      );
      // 0.6% as-fed / 50% DM = 1.2% DM, over the 1.0% cap.
      final result = _calc(
        profile: _profile(),
        target: _target(),
        pantryItems: [_food('a', proteinPct: 20, oxalatePct: 0.6, dryMatterPct: 50)],
        safetyRules: [oxalateRule],
      );
      expect(result.warnings.any((w) => w.message.contains('Oxalate level unsafe')), isTrue);
    });
  });

  group('species-scoped safety rules', () {
    final cuMoRule = SafetyRule(
      ruleId: 'cu_mo_sheep',
      targetType: 'ratio',
      targetName: 'Cu:Mo',
      minRatio: 3.0,
      maxRatio: 8.0,
      severity: 'CRITICAL',
      warningMessage: 'Cu:Mo ratio unsafe for sheep',
      appliesToSpecies: const ['sheep'],
    );

    test('a sheep-scoped Cu:Mo rule fires for a sheep profile', () {
      final result = _calc(
        profile: _profile(species: 'Livestock: Sheep'),
        target: _target(),
        pantryItems: [_food('a', proteinPct: 20, copperPpm: 20, molybdenumPpm: 2)],
        safetyRules: [cuMoRule],
      );
      expect(result.warnings.any((w) => w.message.contains('Cu:Mo ratio unsafe for sheep')), isTrue);
      expect(result.warnings.first.severity, WarningSeverity.critical);
    });

    test('the same sheep-scoped Cu:Mo rule does not fire for a goat profile', () {
      final result = _calc(
        profile: _profile(species: 'Livestock: Goat'),
        target: _target(),
        pantryItems: [_food('a', proteinPct: 20, copperPpm: 20, molybdenumPpm: 2)],
        safetyRules: [cuMoRule],
      );
      expect(result.warnings.any((w) => w.message.contains('Cu:Mo ratio unsafe for sheep')), isFalse);
    });

    test('the Cu:Mo Ratio nutrient comparison only appears for sheep', () {
      final sheep = _calc(
        profile: _profile(species: 'Livestock: Sheep'),
        target: _target(),
        pantryItems: [_food('a', proteinPct: 20, copperPpm: 20, molybdenumPpm: 2)],
      );
      final goat = _calc(
        profile: _profile(species: 'Livestock: Goat'),
        target: _target(),
        pantryItems: [_food('a', proteinPct: 20, copperPpm: 20, molybdenumPpm: 2)],
      );
      expect(sheep.nutrientComparisons.any((c) => c.label == 'Cu:Mo Ratio'), isTrue);
      expect(goat.nutrientComparisons.any((c) => c.label == 'Cu:Mo Ratio'), isFalse);
    });
  });

  group('warning severity ordering', () {
    test('warnings come back sorted most- to least-severe across mixed sources', () {
      final highRule = SafetyRule(
        ruleId: 'cu_cap',
        targetType: 'dm_concentration',
        targetName: 'Cu_ppm_DM',
        maxValue: 10.0,
        severity: 'HIGH',
        warningMessage: 'Copper level unsafe',
      );
      final lowRule = SafetyRule(
        ruleId: 'trace_item',
        targetType: 'ingredient_keyword',
        targetName: 'a',
        maxInclusionPerc: 0,
        severity: 'LOW',
        warningMessage: 'Trace item present',
      );
      // safetyRules deliberately ordered low-then-high, and
      // stageHasDedicatedData:false injects a medium-severity advisory note
      // with no SafetyRule behind it at all - the final list should still
      // come back high, medium, low regardless of insertion order/source.
      final result = _calc(
        profile: _profile(),
        target: _target(),
        pantryItems: [_food('a', proteinPct: 20, copperPpm: 6, dryMatterPct: 50)],
        safetyRules: [lowRule, highRule],
        stageHasDedicatedData: false,
      );

      expect(
        result.warnings.map((w) => w.severity).toList(),
        [WarningSeverity.high, WarningSeverity.medium, WarningSeverity.low],
      );
    });
  });
}
