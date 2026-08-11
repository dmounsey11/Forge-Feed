import '../models/animal_profile.dart';
import '../models/ingredient.dart';
import '../models/ration_result.dart';
import '../models/safety_rule.dart';
import '../models/species_requirement.dart';
import '../widgets/health_screening_dialog.dart';
import '../widgets/prep_amount_dialog.dart';

const double _kgToLb = 2.20462;

class _TargetAdjustment {
  final double proteinMult;
  final double calciumMult;
  final double energyMult;
  final String note;

  const _TargetAdjustment({
    this.proteinMult = 1.0,
    this.calciumMult = 1.0,
    this.energyMult = 1.0,
    required this.note,
  });
}

/// Turns a selected animal, its resolved species targets, health screening
/// answers, and the user's pantry/supplement stock into a ration: how much
/// of each pantry item to use, plus how much of each supplement is needed
/// to close the calcium/phosphorus/sodium gap. See the plan notes in
/// lib/services (and the project plan file) for what this v1 does and does
/// not attempt precisely - this is a helpful estimate, not a vet-verified
/// formulation.
class DietCalculator {
  static RationResult calculate({
    required AnimalProfile profile,
    required SpeciesRequirement target,
    required HealthScreeningResult? health,
    required PrepAmountResult prep,
    required List<Ingredient> pantryItems,
    required List<Ingredient> supplementItems,
    required List<SafetyRule> safetyRules,
  }) {
    final adjustments = _collectAdjustments(profile, health);
    final proteinMult = adjustments.fold(1.0, (m, a) => m * a.proteinMult);
    final calciumMult = adjustments.fold(1.0, (m, a) => m * a.calciumMult);
    final energyMult = adjustments.fold(1.0, (m, a) => m * a.energyMult);
    final healthNotes = adjustments.map((a) => a.note).toList();

    final adjMinProtein = target.minProteinPerc * proteinMult;
    final adjMaxProtein = target.maxProteinPerc * proteinMult;
    final adjMinCalcium = target.minCalciumPerc * calciumMult;
    final adjMaxCalcium = target.maxCalciumPerc * calciumMult;
    final adjMinEnergyKcalLb = (target.minMeKcal * energyMult) / _kgToLb;
    final adjMaxEnergyKcalLb = (target.maxMeKcal * energyMult) / _kgToLb;

    final totalWeightLbs = _estimateBatchWeightLbs(prep: prep, profile: profile, target: target);

    // 1. Split the pantry into real "food" candidates vs. mineral-heavy
    // items (limestone, oyster shell, dicalcium phosphate, etc.) - those
    // belong in the gap-fill supplement math below, not blended at equal
    // weight into the base, no matter which list the user happened to put
    // them in.
    final foodCandidates = pantryItems.where((i) => !_isMineralLike(i)).toList();
    final mineralPantryItems = pantryItems.where(_isMineralLike).toList();
    final supplementPool = [
      ...supplementItems,
      ...mineralPantryItems.where((m) => !supplementItems.any((s) => s.id == m.id)),
    ];

    // 2. Pick a small, sensible base blend instead of using everything:
    // the highest- and lowest-protein selected foods as balancing anchors
    // (a classic "Pearson square" ration-balancing technique), plus a
    // couple of extras for variety, capped so a handful of pantry items
    // aren't drowned out by a dozen others.
    final targetProteinMidpoint = (adjMinProtein + adjMaxProtein) / 2;
    final selectedFoodItems = _selectBaseItems(foodCandidates, targetProteinMidpoint: targetProteinMidpoint);
    final baseLbs = _pearsonBlend(selectedFoodItems, totalWeightLbs, targetProteinMidpoint);

    double baseNutrientLbs(double Function(Ingredient) pctOf) {
      double sum = 0;
      for (final i in selectedFoodItems) {
        sum += (baseLbs[i.id] ?? 0) * (pctOf(i) / 100.0);
      }
      return sum;
    }

    final baseCalciumLbs = baseNutrientLbs((i) => i.asFedMetrics.calciumPct);
    final basePhosphorusLbs = baseNutrientLbs((i) => i.asFedMetrics.phosphorusPct);
    final baseSodiumLbs = baseNutrientLbs((i) => i.asFedMetrics.sodiumPct);

    // 3. Supplement gap-fill for calcium/phosphorus/sodium, aiming for the
    // midpoint of the adjusted target range.
    final calciumGoalLbs = ((adjMinCalcium + adjMaxCalcium) / 2 / 100.0) * totalWeightLbs;
    final phosphorusGoalLbs = ((target.minPhosphorusPerc + target.maxPhosphorusPerc) / 2 / 100.0) * totalWeightLbs;
    final sodiumGoalLbs = ((target.minSodiumPerc + target.maxSodiumPerc) / 2 / 100.0) * totalWeightLbs;

    final calciumFill = _fillGap(
      currentLbs: baseCalciumLbs,
      goalLbs: calciumGoalLbs,
      supplements: supplementPool,
      pctOf: (i) => i.asFedMetrics.calciumPct,
    );
    final phosphorusFill = _fillGap(
      currentLbs: basePhosphorusLbs,
      goalLbs: phosphorusGoalLbs,
      supplements: supplementPool,
      pctOf: (i) => i.asFedMetrics.phosphorusPct,
    );
    final sodiumFill = _fillGap(
      currentLbs: baseSodiumLbs,
      goalLbs: sodiumGoalLbs,
      supplements: supplementPool,
      pctOf: (i) => i.asFedMetrics.sodiumPct,
    );

    final supplementLbs = <String, double>{};
    for (final pass in [calciumFill, phosphorusFill, sodiumFill]) {
      for (final entry in pass.entries) {
        final existing = supplementLbs[entry.key];
        supplementLbs[entry.key] = (existing == null || entry.value > existing) ? entry.value : existing;
      }
    }

    // 4. Final blend across base + supplement items together.
    final allItems = [...selectedFoodItems, ...supplementPool.where((s) => (supplementLbs[s.id] ?? 0) > 0)];
    final allLbs = <String, double>{...baseLbs, ...supplementLbs};
    final finalTotalLbs = allLbs.values.fold(0.0, (sum, v) => sum + v);

    final usedIds = allItems.map((i) => i.id).toSet();
    final excludedItemNames = [...pantryItems, ...supplementItems]
        .where((i) => !usedIds.contains(i.id))
        .map((i) => i.name)
        .toSet()
        .toList();

    double finalPct(double Function(Ingredient) pctOf) {
      if (finalTotalLbs <= 0) return 0;
      double sum = 0;
      for (final i in allItems) {
        sum += (allLbs[i.id] ?? 0) * (pctOf(i) / 100.0);
      }
      return (sum / finalTotalLbs) * 100.0;
    }

    double finalEnergyKcalLb() {
      if (finalTotalLbs <= 0) return 0;
      double sum = 0;
      for (final i in allItems) {
        sum += (allLbs[i.id] ?? 0) * i.asFedMetrics.energyKcalLb;
      }
      return sum / finalTotalLbs;
    }

    final finalProteinPct = finalPct((i) => i.asFedMetrics.crudeProteinPct);
    final finalFatPct = finalPct((i) => i.asFedMetrics.fatPct);
    final finalFiberPct = finalPct((i) => i.asFedMetrics.fiberPct);
    final finalCalciumPct = finalPct((i) => i.asFedMetrics.calciumPct);
    final finalPhosphorusPct = finalPct((i) => i.asFedMetrics.phosphorusPct);
    final finalEnergy = finalEnergyKcalLb();

    final comparisons = [
      _compare('Protein', '%', adjMinProtein, adjMaxProtein, finalProteinPct),
      _compare('Fat', '%', null, null, finalFatPct),
      _compare('Fiber', '%', null, null, finalFiberPct),
      _compare('Calcium', '%', adjMinCalcium, adjMaxCalcium, finalCalciumPct),
      _compare('Phosphorus', '%', target.minPhosphorusPerc, target.maxPhosphorusPerc, finalPhosphorusPct),
      _compare('Energy', 'kcal/lb', adjMinEnergyKcalLb, adjMaxEnergyKcalLb, finalEnergy),
    ];

    // 4. Safety rule checks against the final blend.
    final warnings = _runSafetyChecks(
      profile: profile,
      allItems: allItems,
      allLbs: allLbs,
      finalTotalLbs: finalTotalLbs,
      finalCalciumPct: finalCalciumPct,
      finalPhosphorusPct: finalPhosphorusPct,
      safetyRules: safetyRules,
    );

    final finalBaseItems = selectedFoodItems
        .where((i) => (baseLbs[i.id] ?? 0) > 0)
        .map((i) => RationLineItem(ingredient: i, lbs: baseLbs[i.id]!))
        .toList();
    final finalSupplementItems = supplementPool
        .where((i) => (supplementLbs[i.id] ?? 0) > 0)
        .map((i) => RationLineItem(ingredient: i, lbs: supplementLbs[i.id]!))
        .toList();

    final instructions = _buildInstructions(
      baseItems: finalBaseItems,
      supplementItems: finalSupplementItems,
      prep: prep,
      totalWeightLbs: finalTotalLbs,
    );

    return RationResult(
      totalWeightLbs: finalTotalLbs,
      baseItems: finalBaseItems,
      supplementItems: finalSupplementItems,
      nutrientComparisons: comparisons,
      warnings: warnings,
      healthNotes: healthNotes,
      excludedItemNames: excludedItemNames,
      instructionSteps: instructions.steps,
      portionCount: instructions.portionCount,
      portionSizeOz: instructions.portionSizeOz,
    );
  }

  static const double _lbToOz = 16.0;

  static ({List<String> steps, int? portionCount, double? portionSizeOz}) _buildInstructions({
    required List<RationLineItem> baseItems,
    required List<RationLineItem> supplementItems,
    required PrepAmountResult prep,
    required double totalWeightLbs,
  }) {
    final steps = <String>[];

    if (baseItems.isEmpty) {
      steps.add('No base pantry items in this batch.');
    } else if (baseItems.length == 1) {
      steps.add('Prepare ${baseItems.first.ingredient.name}.');
    } else {
      final sorted = [...baseItems]..sort((a, b) => a.lbs.compareTo(b.lbs));
      final lighter = sorted.sublist(0, sorted.length - 1);
      final heaviest = sorted.last;
      steps.add(
        'Blend ${lighter.map((i) => i.ingredient.name).join(', ')} together, '
        'then mix in ${heaviest.ingredient.name}.',
      );
    }

    if (supplementItems.isNotEmpty) {
      steps.add(
        'Add supplements: ${supplementItems.map((i) => i.ingredient.name).join(', ')}, and mix well.',
      );
    }

    int? portionCount;
    double? portionSizeOz;
    if (prep.mode == PrepMode.days && prep.value > 0) {
      portionCount = prep.value.round();
      portionSizeOz = (totalWeightLbs / prep.value) * _lbToOz;
      steps.add(
        'Divide into $portionCount even portion${portionCount == 1 ? '' : 's'} '
        '(~${portionSizeOz.toStringAsFixed(1)} oz each) - one portion per day for $portionCount day${portionCount == 1 ? '' : 's'}.',
      );
    } else {
      steps.add('Store as a single ~${totalWeightLbs.toStringAsFixed(2)} lb batch.');
    }

    return (steps: steps, portionCount: portionCount, portionSizeOz: portionSizeOz);
  }

  /// A large calcium+phosphorus contribution with almost no protein/fat/
  /// fiber is a mineral supplement (limestone, oyster shell, dicalcium
  /// phosphate) rather than a food item, regardless of which list the user
  /// put it in - blending it at equal weight with corn/meat would just
  /// dilute everything else.
  static bool _isMineralLike(Ingredient i) {
    final m = i.asFedMetrics;
    final combinedMinerals = m.calciumPct + m.phosphorusPct;
    return combinedMinerals > 10.0 && m.crudeProteinPct < 5.0;
  }

  /// Picks a small, sensible set of base food items instead of using
  /// everything selected: the highest- and lowest-protein items as
  /// balancing anchors, plus up to 3 more items whose protein is closest
  /// to the target midpoint (for variety/micronutrients without drowning
  /// the anchors out).
  static const int _maxExtrasCount = 3;

  static List<Ingredient> _selectBaseItems(
    List<Ingredient> candidates, {
    required double targetProteinMidpoint,
  }) {
    if (candidates.length <= 2) return candidates;

    final sorted = [...candidates]
      ..sort((a, b) => a.asFedMetrics.crudeProteinPct.compareTo(b.asFedMetrics.crudeProteinPct));
    final energyAnchor = sorted.first; // lowest protein
    final proteinAnchor = sorted.last; // highest protein

    final remaining = candidates.where((i) => i.id != proteinAnchor.id && i.id != energyAnchor.id).toList()
      ..sort((a, b) => (a.asFedMetrics.crudeProteinPct - targetProteinMidpoint)
          .abs()
          .compareTo((b.asFedMetrics.crudeProteinPct - targetProteinMidpoint).abs()));
    final extras = remaining.take(_maxExtrasCount).toList();

    return [proteinAnchor, energyAnchor, ...extras];
  }

  /// Blends the protein and energy anchors using a Pearson-square-style
  /// ratio to hit the target protein midpoint as closely as those two
  /// ingredients allow, with any extras included at a small fixed
  /// inclusion rate for variety.
  static const double _extrasCapFraction = 0.08;

  static Map<String, double> _pearsonBlend(List<Ingredient> items, double totalLbs, double targetProteinPct) {
    if (items.isEmpty || totalLbs <= 0) return {};
    if (items.length == 1) return {items.first.id: totalLbs};

    final proteinAnchor = items[0];
    final energyAnchor = items[1];
    final extras = items.length > 2 ? items.sublist(2) : const <Ingredient>[];

    final extrasLbs = <String, double>{};
    var extrasFraction = 0.0;
    for (final e in extras) {
      extrasLbs[e.id] = totalLbs * _extrasCapFraction;
      extrasFraction += _extrasCapFraction;
    }

    final anchorsTotalLbs = totalLbs * (1 - extrasFraction);
    final proteinA = proteinAnchor.asFedMetrics.crudeProteinPct;
    final proteinB = energyAnchor.asFedMetrics.crudeProteinPct;

    double fractionA;
    if ((proteinA - proteinB).abs() < 0.001) {
      fractionA = 0.5;
    } else {
      final partsA = targetProteinPct - proteinB;
      final totalParts = proteinA - proteinB; // == partsA + (proteinA - target)
      fractionA = (partsA / totalParts).clamp(0.0, 1.0);
    }
    final fractionB = 1.0 - fractionA;

    return {
      proteinAnchor.id: anchorsTotalLbs * fractionA,
      energyAnchor.id: anchorsTotalLbs * fractionB,
      ...extrasLbs,
    };
  }

  static double _estimateBatchWeightLbs({
    required PrepAmountResult prep,
    required AnimalProfile profile,
    required SpeciesRequirement target,
  }) {
    if (prep.mode == PrepMode.amount) return prep.value;

    final bodyWeightLb = target.targetWeightKg * _kgToLb;
    final intakeRate = _dailyIntakeRateByCategory(profile.species);
    final dailyIntakeLbs = bodyWeightLb > 0 ? bodyWeightLb * intakeRate : 0.5;
    return dailyIntakeLbs * profile.headCount * prep.value;
  }

  /// Rough "percent of body weight eaten per day" by animal category - an
  /// industry-standard-ish estimate, not a precise figure. Used only when
  /// the user picked "days to prep" instead of a direct amount.
  static double _dailyIntakeRateByCategory(String species) {
    final s = species.toLowerCase();
    if (s.contains('poultry')) return 0.06;
    if (s.contains('ruminant')) return 0.025;
    if (s.contains('swine')) return 0.035;
    if (s.contains('reptile')) return 0.015;
    if (s.contains('companion')) return 0.025;
    return 0.03;
  }

  static List<_TargetAdjustment> _collectAdjustments(AnimalProfile profile, HealthScreeningResult? health) {
    final adjustments = <_TargetAdjustment>[];
    if (profile.ageGroup == 'Baby') {
      adjustments.add(const _TargetAdjustment(
        proteinMult: 1.2,
        energyMult: 1.15,
        note: 'Baby: increased protein and energy for growth',
      ));
    } else if (profile.ageGroup == 'Juvenile') {
      adjustments.add(const _TargetAdjustment(
        proteinMult: 1.1,
        energyMult: 1.08,
        note: 'Juvenile: moderately increased protein and energy for continued growth',
      ));
    } else if (profile.ageGroup == 'Geriatric') {
      adjustments.add(const _TargetAdjustment(
        proteinMult: 0.95,
        energyMult: 0.9,
        note: 'Geriatric: slightly reduced energy, moderate protein',
      ));
    }
    if (health != null) {
      if (health.pregnant) {
        adjustments.add(const _TargetAdjustment(
          proteinMult: 1.15,
          calciumMult: 1.2,
          energyMult: 1.1,
          note: 'Pregnant: increased protein, calcium, and energy',
        ));
      }
      if (health.breeding) {
        adjustments.add(const _TargetAdjustment(
          proteinMult: 1.1,
          energyMult: 1.05,
          note: 'Breeding: increased protein and energy',
        ));
      }
      if (health.injured) {
        adjustments.add(_TargetAdjustment(
          proteinMult: 1.15,
          note: health.injuryNotes.isEmpty
              ? 'Injured: increased protein to support tissue repair'
              : 'Injured (${health.injuryNotes}): increased protein to support tissue repair',
        ));
      }
      if (health.hibernatingOrBrumating) {
        adjustments.add(const _TargetAdjustment(
          energyMult: 0.6,
          note: 'Hibernating/brumating: significantly reduced energy needs',
        ));
      }
    }
    return adjustments;
  }

  static Map<String, double> _fillGap({
    required double currentLbs,
    required double goalLbs,
    required List<Ingredient> supplements,
    required double Function(Ingredient) pctOf,
  }) {
    final deficit = goalLbs - currentLbs;
    if (deficit <= 0) return {};
    final contributors = supplements.where((s) => pctOf(s) > 0).toList();
    if (contributors.isEmpty) return {};
    final perItemTarget = deficit / contributors.length;
    final result = <String, double>{};
    for (final s in contributors) {
      final fraction = pctOf(s) / 100.0;
      result[s.id] = perItemTarget / fraction;
    }
    return result;
  }

  static NutrientComparison _compare(String label, String unit, double? min, double? max, double actual) {
    NutrientStatus status;
    if (min == null && max == null) {
      status = NutrientStatus.unknown;
    } else if (min != null && actual < min) {
      status = NutrientStatus.low;
    } else if (max != null && actual > max) {
      status = NutrientStatus.high;
    } else {
      status = NutrientStatus.onTrack;
    }
    return NutrientComparison(
      label: label,
      unit: unit,
      targetMin: min,
      targetMax: max,
      actual: actual,
      status: status,
    );
  }

  static List<String> _runSafetyChecks({
    required AnimalProfile profile,
    required List<Ingredient> allItems,
    required Map<String, double> allLbs,
    required double finalTotalLbs,
    required double finalCalciumPct,
    required double finalPhosphorusPct,
    required List<SafetyRule> safetyRules,
  }) {
    final warnings = <String>[];
    if (finalTotalLbs <= 0) return warnings;

    for (final rule in safetyRules) {
      if (rule.targetType == 'ratio') {
        final stage = profile.productionStage.toLowerCase();
        final appliesToGrower = rule.targetName == 'Ca:AvailP_grower' &&
            (stage.contains('grower') || stage.contains('starter') || stage.contains('juvenile'));
        final appliesToLayer = rule.targetName == 'Ca:AvailP_layer' && stage.contains('layer');
        if (!appliesToGrower && !appliesToLayer) continue;
        if (finalPhosphorusPct <= 0) continue;
        final ratio = finalCalciumPct / finalPhosphorusPct;
        if ((rule.minRatio != null && ratio < rule.minRatio!) ||
            (rule.maxRatio != null && ratio > rule.maxRatio!)) {
          warnings.add(rule.warningMessage);
        }
        continue;
      }

      // ingredient_category / ingredient_keyword: check inclusion % of any
      // matching item in the final blend.
      for (final item in allItems) {
        final lbs = allLbs[item.id] ?? 0;
        if (lbs <= 0) continue;
        if (!item.name.toLowerCase().contains(rule.targetName.toLowerCase())) continue;
        final inclusionPct = (lbs / finalTotalLbs) * 100.0;
        if (rule.maxInclusionPerc != null && inclusionPct > rule.maxInclusionPerc!) {
          warnings.add(
            '${item.name}: ${rule.warningMessage} (currently ${inclusionPct.toStringAsFixed(1)}%)',
          );
        }
      }
    }
    return warnings;
  }
}
