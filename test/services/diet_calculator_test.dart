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
  double? minFatPerc,
  double? maxFatPerc,
  double minCalciumPerc = 0,
  double maxCalciumPerc = 100,
  double minPhosphorusPerc = 0,
  double maxPhosphorusPerc = 100,
  double minSodiumPerc = 0,
  double maxSodiumPerc = 100,
  double minMeKcal = 0,
  double maxMeKcal = 1000000,
  double minLysinePerc = 0,
  double minMethioninePerc = 0,
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
    minFatPerc: minFatPerc,
    maxFatPerc: maxFatPerc,
    minMeKcal: minMeKcal,
    maxMeKcal: maxMeKcal,
    minCalciumPerc: minCalciumPerc,
    maxCalciumPerc: maxCalciumPerc,
    minPhosphorusPerc: minPhosphorusPerc,
    maxPhosphorusPerc: maxPhosphorusPerc,
    minSodiumPerc: minSodiumPerc,
    maxSodiumPerc: maxSodiumPerc,
    minLysinePerc: minLysinePerc,
    minMethioninePerc: minMethioninePerc,
  );
}

Ingredient _food(
  String id, {
  double proteinPct = 10,
  double fatPct = 0,
  double calciumPct = 0,
  double phosphorusPct = 0,
  double sodiumPct = 0,
  double copperPpm = 0,
  double molybdenumPpm = 0,
  double oxalatePct = 0,
  double lysinePct = 0,
  double methioninePct = 0,
  double? dryMatterPct,
}) {
  return Ingredient(
    id: id,
    name: id,
    category: 'Proteins & Meal',
    asFedMetrics: AsFedMetrics(
      crudeProteinPct: proteinPct,
      fatPct: fatPct,
      calciumPct: calciumPct,
      phosphorusPct: phosphorusPct,
      sodiumPct: sodiumPct,
      copperPpm: copperPpm,
      molybdenumPpm: molybdenumPpm,
      oxalatePct: oxalatePct,
      lysinePct: lysinePct,
      methioninePct: methioninePct,
      dryMatterPct: dryMatterPct,
    ),
  );
}

AnimalProfile _profile({String species = 'Livestock: Generic', String productionStage = 'Healthy / Normal'}) {
  return AnimalProfile(id: 'p1', name: 'Test Animal', species: species, productionStage: productionStage);
}

const _fixedAmount = PrepAmountResult(mode: PrepMode.amount, value: 10.0);

/// [DietCalculator.calculate] returns either a [RationResult] or a
/// [RationCalculationError] - callers pick whichever they expect for a
/// given scenario (`as RationResult`, or an `is RationCalculationError`
/// check). Nutrient-target conflicts no longer produce an error at all -
/// see [DietCalculator._autoRelax] - only [DietFailureReason.noCandidates]
/// and [DietFailureReason.safetyConflict] still do.
Object _calc({
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
  group('LP-enforced nutrient ranges', () {
    test('a single ingredient that can never satisfy the protein range gets a real ration back, '
        'with the unreachable ceiling reported as a shortfall instead of blocking the batch', () {
      // Only one food, fixed at 100% of the batch by the total-weight
      // equality constraint - its 50% protein has no room to blend down
      // into a 10-20% range. Nutrient-target ranges are cumulative/
      // preference-shaped, not safety limits, so the calculator still
      // produces this batch (using the only food available) and reports
      // the 20% protein ceiling as unreachable rather than refusing to
      // produce anything.
      final result = _calc(
        profile: _profile(),
        target: _target(minProteinPerc: 10, maxProteinPerc: 20),
        pantryItems: [_food('a', proteinPct: 50)],
      ) as RationResult;

      final protein = result.nutrientComparisons.firstWhere((c) => c.label == 'Protein');
      // The comparison still reports against the real, un-relaxed target -
      // 50% is honestly flagged high, never silently redefined as on track.
      expect(protein.status, NutrientStatus.high);
      expect(protein.actual, closeTo(50.0, 0.01));

      expect(result.nutrientShortfalls, hasLength(1));
      final shortfall = result.nutrientShortfalls.single;
      expect(shortfall.label, 'Protein');
      expect(shortfall.isMinBound, isFalse);
      expect(shortfall.targetValue, 20.0);
      expect(shortfall.achievableValue, closeTo(50.0, 0.01));
      expect(shortfall.suggestion, isNotEmpty);

      expect(
        result.warnings.any((w) => w.message.contains('Protein') && w.severity == WarningSeverity.medium),
        isTrue,
      );
    });

    test('a feasible blend never reports a hard-constrained nutrient as low or high', () {
      // Two foods whose protein straddles the 14-16% range force a real
      // blend; because protein min/max are now hard LP constraints, the
      // solved batch's Protein comparison can only ever be onTrack (or the
      // solve fails outright) - never low/high as the old heuristic could
      // silently produce.
      final result = _calc(
        profile: _profile(),
        target: _target(minProteinPerc: 14, maxProteinPerc: 16),
        pantryItems: [_food('high', proteinPct: 30), _food('low', proteinPct: 5)],
      ) as RationResult;
      final protein = result.nutrientComparisons.firstWhere((c) => c.label == 'Protein');
      expect(protein.status, NutrientStatus.onTrack);
      expect(protein.actual, inInclusiveRange(14.0, 16.0));
      // Neither ingredient alone satisfies the range, so a real blend of
      // both is required - confirms the LP actually mixed them rather than
      // picking one at 100%.
      expect(result.baseItems.length, 2);
      expect(result.nutrientShortfalls, isEmpty);
    });
  });

  group('dry-matter basis conversion + hard toxicity ceilings', () {
    final copperRule = SafetyRule(
      ruleId: 'cu_cap',
      targetType: 'dm_concentration',
      targetName: 'Cu_ppm_DM',
      maxValue: 10.0,
      severity: 'HIGH',
      warningMessage: 'Copper level unsafe',
    );

    test('as-fed copper below the DM-basis cap solves fine with no warning', () {
      // 4 ppm as-fed / 50% DM = 8 ppm DM, under the 10 ppm cap.
      final result = _calc(
        profile: _profile(),
        target: _target(),
        pantryItems: [_food('a', proteinPct: 20, copperPpm: 4, dryMatterPct: 50)],
        safetyRules: [copperRule],
      ) as RationResult;
      expect(result.warnings.any((w) => w.message.contains('Copper level unsafe')), isFalse);
    });

    test('a single ingredient that would breach the DM-basis copper cap is infeasible, not just warned about', () {
      // 6 ppm as-fed / 50% DM = 12 ppm DM, over the 10 ppm cap - and with
      // only this one ingredient available, there's no way to dilute it
      // down. The DM-basis cap is a hard safety constraint (see
      // _hardSafetyConstraints), never a relaxation candidate, so this
      // correctly fails to solve at all rather than quietly producing an
      // over-cap blend.
      final result = _calc(
        profile: _profile(),
        target: _target(),
        pantryItems: [_food('a', proteinPct: 20, copperPpm: 6, dryMatterPct: 50)],
        safetyRules: [copperRule],
      );
      expect(result, isA<RationCalculationError>());
      expect((result as RationCalculationError).reason, DietFailureReason.safetyConflict);
    });

    test('given an alternative, the LP routes around a copper cap instead of tripping it', () {
      // A high-copper item alone would breach the cap, but a clean
      // alternative lets the solver dilute it down (or avoid it) to stay
      // under 10 ppm DM - demonstrating the ceiling actually shapes the
      // blend rather than merely being checked after the fact.
      final result = _calc(
        profile: _profile(),
        target: _target(),
        pantryItems: [
          _food('risky', proteinPct: 20, copperPpm: 6, dryMatterPct: 50),
          _food('clean', proteinPct: 20, copperPpm: 0, dryMatterPct: 50),
        ],
        safetyRules: [copperRule],
      ) as RationResult;
      expect(result.warnings.any((w) => w.message.contains('Copper level unsafe')), isFalse);
    });

    test('a null dry matter % is treated as fully dry (100%), not a guess', () {
      // 6 ppm as-fed / 100% DM = 6 ppm DM, under the 10 ppm cap, even
      // though the same as-fed value was infeasible in the 50%-DM case
      // above.
      final result = _calc(
        profile: _profile(),
        target: _target(),
        pantryItems: [_food('a', proteinPct: 20, copperPpm: 6, dryMatterPct: null)],
        safetyRules: [copperRule],
      );
      expect(result, isA<RationResult>());
      expect((result as RationResult).warnings.any((w) => w.message.contains('Copper level unsafe')), isFalse);
    });

    test('the same DM-basis logic applies to the oxalate cap', () {
      final oxalateRule = SafetyRule(
        ruleId: 'ox_cap',
        targetType: 'dm_concentration',
        targetName: 'Oxalate_pct_DM',
        maxValue: 1.0,
        severity: 'HIGH',
        warningMessage: 'Oxalate level unsafe',
      );
      // 0.6% as-fed / 50% DM = 1.2% DM, over the 1.0% cap, with no
      // alternative ingredient to dilute it.
      final result = _calc(
        profile: _profile(),
        target: _target(),
        pantryItems: [_food('a', proteinPct: 20, oxalatePct: 0.6, dryMatterPct: 50)],
        safetyRules: [oxalateRule],
      );
      expect(result, isA<RationCalculationError>());
      expect((result as RationCalculationError).reason, DietFailureReason.safetyConflict);
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

    test('a sheep-scoped Cu:Mo rule makes an all-high-ratio pantry infeasible for a sheep profile', () {
      // Ratio 20:2 = 10:1, over the 8:1 cap - hard-enforced only when the
      // rule applies to this species, and with only this ingredient
      // available there's no way to bring the ratio down.
      final result = _calc(
        profile: _profile(species: 'Livestock: Sheep'),
        target: _target(),
        pantryItems: [_food('a', proteinPct: 20, copperPpm: 20, molybdenumPpm: 2)],
        safetyRules: [cuMoRule],
      );
      expect(result, isA<RationCalculationError>());
    });

    test('the same pantry stays feasible for a goat profile since the rule is species-scoped', () {
      final result = _calc(
        profile: _profile(species: 'Livestock: Goat'),
        target: _target(),
        pantryItems: [_food('a', proteinPct: 20, copperPpm: 20, molybdenumPpm: 2)],
        safetyRules: [cuMoRule],
      ) as RationResult;
      expect(result.warnings.any((w) => w.message.contains('Cu:Mo ratio unsafe for sheep')), isFalse);
    });

    test('the Cu:Mo Ratio nutrient comparison only appears for sheep', () {
      final sheep = _calc(
        profile: _profile(species: 'Livestock: Sheep'),
        target: _target(),
        pantryItems: [_food('a', proteinPct: 20, copperPpm: 20, molybdenumPpm: 2)],
      ) as RationResult;
      final goat = _calc(
        profile: _profile(species: 'Livestock: Goat'),
        target: _target(),
        pantryItems: [_food('a', proteinPct: 20, copperPpm: 20, molybdenumPpm: 2)],
      ) as RationResult;
      expect(sheep.nutrientComparisons.any((c) => c.label == 'Cu:Mo Ratio'), isTrue);
      expect(goat.nutrientComparisons.any((c) => c.label == 'Cu:Mo Ratio'), isFalse);
    });
  });

  group('warning severity ordering', () {
    test('warnings come back sorted most- to least-severe across mixed sources', () {
      // targetType 'advisory' is deliberately not one of the five shapes
      // _hardSafetyConstraints recognizes (dm_concentration/ratio/
      // category_total/ingredient_category/ingredient_keyword), so these
      // stay soft/advisory rather than turning this scenario infeasible -
      // _runSafetyChecks' final fallthrough still name-matches and warns
      // on them regardless of targetType.
      final highRule = SafetyRule(
        ruleId: 'soft_high',
        targetType: 'advisory',
        targetName: 'special',
        maxInclusionPerc: 5,
        severity: 'HIGH',
        warningMessage: 'Special ingredient should stay minimal',
      );
      final lowRule = SafetyRule(
        ruleId: 'soft_low',
        targetType: 'advisory',
        targetName: 'filler',
        maxInclusionPerc: 5,
        severity: 'LOW',
        warningMessage: 'Filler ingredient should stay minimal',
      );
      // Protein range forces a real blend of both named ingredients (see
      // the LP-enforced range test above), so both inclusion percentages
      // land well over the 5% caps regardless of which range boundary the
      // solver settles on. stageHasDedicatedData:false injects a medium-
      // severity advisory note with no SafetyRule behind it at all - the
      // final list should still come back high, medium, low regardless of
      // insertion order or source.
      final result = _calc(
        profile: _profile(),
        target: _target(minProteinPerc: 14, maxProteinPerc: 16),
        pantryItems: [_food('special item', proteinPct: 30), _food('filler item', proteinPct: 5)],
        safetyRules: [lowRule, highRule],
        stageHasDedicatedData: false,
      ) as RationResult;

      expect(
        result.warnings.map((w) => w.severity).toList(),
        [WarningSeverity.high, WarningSeverity.medium, WarningSeverity.low],
      );
    });
  });

  group('Auto-relax: nutrient targets are loosened automatically, never blocked', () {
    // 'meat' is the only source of protein and it's also the only source of
    // fat - a 30% protein floor forces at least ~6.5 lbs of it into a
    // 10-lb batch, but a 10% fat ceiling caps it at ~4.67 lbs. There is no
    // blend of these two ingredients that satisfies both at once.
    List<Ingredient> proteinFatConflictPantry() => [
          _food('meat', proteinPct: 38, fatPct: 18),
          _food('lean', proteinPct: 15, fatPct: 3),
        ];

    SpeciesRequirement proteinFatConflictTarget() => _target(minProteinPerc: 30, maxFatPerc: 10);

    test(
        'protein floor vs. fat ceiling: still produces a real ration, with the fat ceiling (added '
        'after the protein floor in build order) reported as the shortfall and a matching medium-'
        'severity warning', () {
      final result = _calc(
        profile: _profile(),
        target: proteinFatConflictTarget(),
        pantryItems: proteinFatConflictPantry(),
      ) as RationResult;

      expect(result.nutrientShortfalls, hasLength(1));
      final shortfall = result.nutrientShortfalls.single;
      expect(shortfall.label, 'Fat');
      expect(shortfall.isMinBound, isFalse);
      expect(shortfall.targetValue, 10.0);
      // With the protein floor kept, minimizing fat still requires enough
      // 'meat' to clear 30% protein: at that boundary (m ~= 6.52 lbs of a
      // 10-lb batch), fat comes out to ~12.78%, not the 10% ceiling.
      expect(shortfall.achievableValue, closeTo(12.78, 0.05));

      final warning = result.warnings.firstWhere((w) => w.message.contains('Fat'));
      expect(warning.severity, WarningSeverity.medium);
      expect(warning.message, contains('running/cumulative'));
    });

    test(
        'pairwise conflict: two independent conflicts (protein/fat and calcium/sodium) that share no '
        'ingredient both surface as separate shortfalls', () {
      // 'meat'/'lean' reproduce the protein/fat conflict above; 'mineralMix'
      // is the only calcium source but also carries sodium, so reaching the
      // calcium floor necessarily blows the sodium ceiling. The two
      // conflicts don't share an ingredient, so keeping one pair's bounds
      // doesn't help the other - this is exactly the shape the old single/
      // pair-removal diagnostic could miss.
      final result = _calc(
        profile: _profile(),
        target: _target(minProteinPerc: 30, maxFatPerc: 10, minCalciumPerc: 5, maxSodiumPerc: 1),
        pantryItems: [
          _food('meat', proteinPct: 38, fatPct: 18),
          _food('lean', proteinPct: 15, fatPct: 3),
          _food('mineralMix', calciumPct: 30, sodiumPct: 20),
        ],
      ) as RationResult;

      expect(result.nutrientShortfalls, hasLength(2));
      expect(result.nutrientShortfalls.map((s) => s.label).toSet(), hasLength(2));
    });

    test(
        'two simultaneously-unreachable floors (e.g. lysine and methionine on a pantry with no amino '
        'acid data) are both reported - the exact case the old single/pair-removal diagnostic could '
        'never explain', () {
      // A single ingredient, forced to 100% of the batch, with real but
      // tiny lysine/methionine values - nowhere near the floors below, and
      // with only one candidate there's no blend to change that.
      final result = _calc(
        profile: _profile(),
        target: _target(minLysinePerc: 0.5, minMethioninePerc: 0.3),
        pantryItems: [_food('a', proteinPct: 20, lysinePct: 0.1, methioninePct: 0.05)],
      ) as RationResult;

      expect(result.nutrientShortfalls, hasLength(2));
      final lysine = result.nutrientShortfalls.firstWhere((s) => s.label == 'Lysine');
      expect(lysine.isMinBound, isTrue);
      expect(lysine.targetValue, 0.5);
      expect(lysine.achievableValue, closeTo(0.1, 0.01));

      final methionine = result.nutrientShortfalls.firstWhere((s) => s.label == 'Methionine');
      expect(methionine.isMinBound, isTrue);
      expect(methionine.targetValue, 0.3);
      expect(methionine.achievableValue, closeTo(0.05, 0.01));
    });

    test(
        'a safety-rule-driven infeasibility is a genuine block: even relaxing every nutrient target '
        'still can\'t clear the hard copper cap, so this reports safetyConflict, not a shortfall', () {
      final copperRule = SafetyRule(
        ruleId: 'cu_cap',
        targetType: 'dm_concentration',
        targetName: 'Cu_ppm_DM',
        maxValue: 10.0,
        severity: 'HIGH',
        warningMessage: 'Copper level unsafe',
      );
      // Wide-open nutrient target - the only possible source of
      // infeasibility is the hard copper cap, which auto-relax must never
      // treat as a removable/relaxable nutrient bound.
      final result = _calc(
        profile: _profile(),
        target: _target(),
        pantryItems: [_food('a', proteinPct: 20, copperPpm: 6, dryMatterPct: 50)],
        safetyRules: [copperRule],
      );

      expect(result, isA<RationCalculationError>());
      final error = result as RationCalculationError;
      expect(error.reason, DietFailureReason.safetyConflict);
    });

    test('no pantry or supplement items at all is reported as noCandidates', () {
      final result = _calc(
        profile: _profile(),
        target: _target(),
        pantryItems: const [],
      );

      expect(result, isA<RationCalculationError>());
      final error = result as RationCalculationError;
      expect(error.reason, DietFailureReason.noCandidates);
    });
  });
}
