import '../models/animal_profile.dart';
import '../models/ingredient.dart';
import '../models/ration_result.dart';
import '../models/health_screening_result.dart';
import '../models/safety_rule.dart';
import '../models/species_requirement.dart';
import '../widgets/prep_amount_dialog.dart';
import 'simplex_solver.dart';

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
/// to close nutrient gaps the base feed can't cover. See the plan notes in
/// lib/services (and the project plan file) for what this does and does
/// not attempt precisely - this is a helpful estimate, not a vet-verified
/// formulation.
///
/// The core blend is produced by a single Linear Program (see
/// [_solveDietLp]/[SimplexSolver]) that jointly satisfies crude protein,
/// amino acid minimums, mineral ranges, energy, and every hard safety
/// ceiling this data can express, rather than a sequential heuristic. If no
/// combination of the available pantry/supplement items can satisfy every
/// constraint at once, [calculate] returns a [RationCalculationError]
/// instead of silently producing an out-of-range blend.
class DietCalculator {
  static Object calculate({
    required AnimalProfile profile,
    required SpeciesRequirement target,
    required HealthScreeningResult? health,
    required PrepAmountResult prep,
    required List<Ingredient> pantryItems,
    required List<Ingredient> supplementItems,
    required List<SafetyRule> safetyRules,
    bool stageHasDedicatedData = true,
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
    // belong with the supplements in the LP's candidate pool, not blended
    // in as if they were food, no matter which list the user happened to
    // put them in.
    var foodCandidates = pantryItems.where((i) => !_isMineralLike(i)).toList();
    var feedingSystemFilteredIds = <String>{};
    if (profile.feedingSystem == 'Raw / Whole Food + Premix') {
      // Prefer genuinely fresh/whole ingredients over processed grains/meals
      // when the pantry has any, since that's the point of this mode; if it
      // doesn't, fall back to the full candidate list rather than returning
      // an empty ration.
      final wholeFoodItems =
          foodCandidates.where((i) => _isFreshOrFrozenProtein(i) || _isFreshProduce(i)).toList();
      if (wholeFoodItems.isNotEmpty) {
        feedingSystemFilteredIds = foodCandidates
            .where((i) => !wholeFoodItems.any((w) => w.id == i.id))
            .map((i) => i.id)
            .toSet();
        foodCandidates = wholeFoodItems;
      }
    }
    final mineralPantryItems = pantryItems.where(_isMineralLike).toList();
    final supplementPool = [
      ...supplementItems,
      ...mineralPantryItems.where((m) => !supplementItems.any((s) => s.id == m.id)),
    ];

    // 2. Solve one Linear Program across every food + supplement candidate
    // at once - jointly satisfying every nutrient/amino-acid/mineral target
    // and hard safety ceiling this data can express - rather than hand-
    // picking a small anchor set and gap-filling afterward. See
    // _solveDietLp for the constraint matrix.
    final candidates = [...foodCandidates, ...supplementPool];
    final lpOutcome = _solveDietLp(
      candidates: candidates,
      lowCostIds: foodCandidates.map((i) => i.id).toSet(),
      totalWeightLbs: totalWeightLbs,
      target: target,
      adjMinProtein: adjMinProtein,
      adjMaxProtein: adjMaxProtein,
      adjMinCalcium: adjMinCalcium,
      adjMaxCalcium: adjMaxCalcium,
      adjMinEnergyKcalLb: adjMinEnergyKcalLb,
      adjMaxEnergyKcalLb: adjMaxEnergyKcalLb,
      safetyRules: safetyRules,
      profile: profile,
    );
    if (!lpOutcome.feasible) {
      return const RationCalculationError(
        "No combination of your selected pantry and supplement items can satisfy every nutrient and "
        "safety target at once for this batch. Try adding more pantry variety (especially items higher "
        "in protein, calcium, or phosphorus) or stocking a broader supplement/mineral base, then "
        "recalculate.",
      );
    }
    final allLbs = lpOutcome.lbsByIngredientId;
    final allItems = candidates.where((i) => allLbs.containsKey(i.id)).toList();
    final finalTotalLbs = allLbs.values.fold(0.0, (sum, v) => sum + v);

    final usedIds = allItems.map((i) => i.id).toSet();
    final excludedItems = <ExcludedItem>[];
    final seenExcludedIds = <String>{};
    for (final i in [...pantryItems, ...supplementItems]) {
      if (usedIds.contains(i.id) || !seenExcludedIds.add(i.id)) continue;
      excludedItems.add(ExcludedItem(
        name: i.name,
        reason: _explainExclusion(item: i, feedingSystemFilteredIds: feedingSystemFilteredIds),
      ));
    }

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

    double finalNiacinMgKg() {
      if (finalTotalLbs <= 0) return 0;
      double sum = 0;
      for (final i in allItems) {
        sum += (allLbs[i.id] ?? 0) * i.asFedMetrics.niacinMgKg;
      }
      return sum / finalTotalLbs;
    }

    double finalCopperPpm() {
      if (finalTotalLbs <= 0) return 0;
      double sum = 0;
      for (final i in allItems) {
        sum += (allLbs[i.id] ?? 0) * i.asFedMetrics.copperPpm;
      }
      return sum / finalTotalLbs;
    }

    double finalMolybdenumPpm() {
      if (finalTotalLbs <= 0) return 0;
      double sum = 0;
      for (final i in allItems) {
        sum += (allLbs[i.id] ?? 0) * i.asFedMetrics.molybdenumPpm;
      }
      return sum / finalTotalLbs;
    }

    // Weighted-average % dry matter of the blend, treating any item with no
    // known dry matter % as fully dry (100%) rather than guessing - see
    // AsFedMetrics.dryMatterPct. Used to convert as-fed concentrations onto
    // a dry-matter basis for absolute toxicity thresholds that are
    // published DM-basis (e.g. sheep copper, horse oxalate), since a wet
    // ingredient's as-fed ppm/% understates how concentrated it really is
    // once water is excluded.
    double finalDryMatterPct() {
      if (finalTotalLbs <= 0) return 100;
      double sum = 0;
      for (final i in allItems) {
        sum += (allLbs[i.id] ?? 0) * (i.asFedMetrics.dryMatterPct ?? 100.0);
      }
      return sum / finalTotalLbs;
    }

    final finalProteinPct = finalPct((i) => i.asFedMetrics.crudeProteinPct);
    final finalFatPct = finalPct((i) => i.asFedMetrics.fatPct);
    final finalFiberPct = finalPct((i) => i.asFedMetrics.fiberPct);
    final finalCalciumPct = finalPct((i) => i.asFedMetrics.calciumPct);
    final finalPhosphorusPct = finalPct((i) => i.asFedMetrics.phosphorusPct);
    final finalEnergy = finalEnergyKcalLb();
    final finalTaurinePct = finalPct((i) => i.asFedMetrics.taurinePct);
    final finalNiacin = finalNiacinMgKg();
    final finalCopper = finalCopperPpm();
    final finalMolybdenum = finalMolybdenumPpm();
    final finalOxalatePct = finalPct((i) => i.asFedMetrics.oxalatePct);
    final finalSugarPct = finalPct((i) => i.asFedMetrics.sugarPct);
    final finalDMPct = finalDryMatterPct();

    final speciesText = profile.species.toLowerCase();
    final isSheep = speciesText.contains('sheep');
    // Oxalate/"Big Head" and hypocalcemia risk is documented primarily in
    // horses, with secondary relevance in ruminants that graze the same
    // tropical/subtropical pastures.
    final isOxalateRiskSpecies = ['horse', 'cattle', 'sheep', 'goat'].any((s) => speciesText.contains(s));

    final comparisons = [
      _compare('Protein', '%', adjMinProtein, adjMaxProtein, finalProteinPct),
      _compare('Fat', '%', target.minFatPerc, target.maxFatPerc, finalFatPct),
      _compare('Fiber', '%', target.minFiberPerc, target.maxFiberPerc, finalFiberPct),
      _compare('Calcium', '%', adjMinCalcium, adjMaxCalcium, finalCalciumPct),
      _compare('Phosphorus', '%', target.minPhosphorusPerc, target.maxPhosphorusPerc, finalPhosphorusPct),
      _compare('Energy', 'kcal/lb', adjMinEnergyKcalLb, adjMaxEnergyKcalLb, finalEnergy),
      if (target.minTaurinePerc > 0) _compare('Taurine', '%', target.minTaurinePerc, null, finalTaurinePct),
      if (target.minNiacinMgKg > 0) _compare('Niacin', 'mg/kg', target.minNiacinMgKg, null, finalNiacin),
      if (isSheep && finalMolybdenum > 0)
        _compare('Cu:Mo Ratio', ':1', 3.0, 10.0, finalCopper / finalMolybdenum),
      if (isOxalateRiskSpecies && finalOxalatePct > 0)
        _compare('Ca:Oxalate Ratio', ':1', 0.5, null, finalCalciumPct / finalOxalatePct),
    ];

    // 3. Safety rule checks against the final blend. The LP above already
    // treats every rule it can express as a hard constraint, so this is
    // largely a redundant safety net plus coverage for rule shapes the LP
    // doesn't linearize (nothing with a maxValue/maxInclusionPerc should
    // actually fire here in practice).
    final warnings = _runSafetyChecks(
      profile: profile,
      allItems: allItems,
      allLbs: allLbs,
      finalTotalLbs: finalTotalLbs,
      finalCalciumPct: finalCalciumPct,
      finalPhosphorusPct: finalPhosphorusPct,
      finalCopperPpm: finalCopper,
      finalMolybdenumPpm: finalMolybdenum,
      finalOxalatePct: finalOxalatePct,
      finalSugarPct: finalSugarPct,
      finalDMPct: finalDMPct,
      safetyRules: safetyRules,
    );
    if (!stageHasDedicatedData) {
      warnings.insert(
        0,
        RationWarning(
          message:
              'No dedicated nutrition data yet for the "${profile.productionStage}" stage of this species - '
              'this ration uses general/maintenance-level targets instead. Treat it as a rough starting point, '
              'not a stage-tuned recipe.',
          severity: WarningSeverity.medium,
        ),
      );
    }
    if (profile.feedingSystem == 'Pasture / Forage-First' && prep.mode == PrepMode.days) {
      warnings.insert(
        0,
        RationWarning(
          message:
              'Assuming grazing covers about ${(_assumedPastureCoverageFraction * 100).round()}% of daily intake - '
              'a flat default, not a real assessment of your pasture. This batch is sized to cover the rest. If your '
              'grazing coverage is better or worse than that, enter a direct lbs amount instead of a number of days.',
          severity: WarningSeverity.low,
        ),
      );
    }
    if (profile.feedingSystem == 'Pasture / Forage-First' && profile.environment == 'Indoor') {
      warnings.add(
        const RationWarning(
          message: 'This profile is set to "Pasture / Forage-First" but the environment is "Indoor" - '
              'double check that\'s intentional.',
          severity: WarningSeverity.low,
        ),
      );
    }
    final hasPerishableItems = allItems.any((i) => _isFreshOrFrozenProtein(i) || _isFreshProduce(i));
    if (hasPerishableItems && prep.mode == PrepMode.days && prep.value > _maxFrozenStorageDays) {
      warnings.add(
        RationWarning(
          message: 'You\'re prepping ${prep.value.round()} days\' worth of portions containing fresh/frozen meat or '
              'produce. That\'s beyond the roughly $_maxFrozenStorageDays-day (3-month) window recommended for '
              'frozen raw ingredients before quality and safety start to degrade. Consider freezing this in two '
              'or more smaller batches instead of one long-dated batch.',
          severity: WarningSeverity.medium,
        ),
      );
    }
    warnings.sort((a, b) => a.severity.index.compareTo(b.severity.index));

    final finalBaseItems = foodCandidates
        .where((i) => (allLbs[i.id] ?? 0) > 0)
        .map((i) => RationLineItem(ingredient: i, lbs: allLbs[i.id]!))
        .toList();
    final finalSupplementItems = supplementPool
        .where((i) => (allLbs[i.id] ?? 0) > 0)
        .map((i) => RationLineItem(ingredient: i, lbs: allLbs[i.id]!))
        .toList();

    final instructions = _buildInstructions(
      profile: profile,
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
      excludedItems: excludedItems,
      instructionSteps: instructions.steps,
      portionCount: instructions.portionCount,
      portionSizeOz: instructions.portionSizeOz,
    );
  }

  /// Builds and solves the Linear Program that produces the ration blend:
  /// one variable per candidate ingredient (pounds used), constrained to
  /// sum to [totalWeightLbs] and to keep every nutrient this app tracks
  /// within its target range (or above its minimum, for amino acids/
  /// taurine/niacin), plus every hard safety ceiling [safetyRules] can
  /// express (see [_hardSafetyConstraints]). The objective prefers whole
  /// foods ([lowCostIds], cost 0) over supplements/minerals (cost 1), so
  /// supplements are only used to the extent the foods alone can't meet a
  /// target - mirroring the old heuristic's intent, just solved jointly
  /// instead of as a separate gap-fill pass.
  static ({bool feasible, Map<String, double> lbsByIngredientId}) _solveDietLp({
    required List<Ingredient> candidates,
    required Set<String> lowCostIds,
    required double totalWeightLbs,
    required SpeciesRequirement target,
    required double adjMinProtein,
    required double adjMaxProtein,
    required double adjMinCalcium,
    required double adjMaxCalcium,
    required double adjMinEnergyKcalLb,
    required double adjMaxEnergyKcalLb,
    required List<SafetyRule> safetyRules,
    required AnimalProfile profile,
  }) {
    if (candidates.isEmpty || totalWeightLbs <= 0) {
      return (feasible: false, lbsByIngredientId: <String, double>{});
    }

    final n = candidates.length;
    List<double> pctCoeffs(double Function(AsFedMetrics) pctOf) =>
        candidates.map((i) => pctOf(i.asFedMetrics) / 100.0).toList();
    List<double> rawCoeffs(double Function(AsFedMetrics) valOf) =>
        candidates.map((i) => valOf(i.asFedMetrics)).toList();

    final constraints = <LpConstraint>[
      LpConstraint(List.filled(n, 1.0), ConstraintType.equal, totalWeightLbs),
    ];

    // A minimum of <= 0 is already guaranteed by x >= 0 and would just add
    // a needless artificial variable to the solve, so those are skipped;
    // a maximum is only skipped when genuinely absent (null), since a real
    // max of 0 is meaningful (forces that nutrient out entirely).
    void addRange(List<double> coeffs, double? minTotal, double? maxTotal) {
      if (minTotal != null && minTotal > 0) {
        constraints.add(LpConstraint(coeffs, ConstraintType.greaterOrEqual, minTotal));
      }
      if (maxTotal != null && maxTotal > 0) {
        constraints.add(LpConstraint(coeffs, ConstraintType.lessOrEqual, maxTotal));
      }
    }

    addRange(pctCoeffs((m) => m.crudeProteinPct), adjMinProtein / 100 * totalWeightLbs,
        adjMaxProtein / 100 * totalWeightLbs);
    addRange(pctCoeffs((m) => m.calciumPct), adjMinCalcium / 100 * totalWeightLbs,
        adjMaxCalcium / 100 * totalWeightLbs);
    addRange(pctCoeffs((m) => m.phosphorusPct), target.minPhosphorusPerc / 100 * totalWeightLbs,
        target.maxPhosphorusPerc / 100 * totalWeightLbs);
    addRange(pctCoeffs((m) => m.sodiumPct), target.minSodiumPerc / 100 * totalWeightLbs,
        target.maxSodiumPerc / 100 * totalWeightLbs);
    if (target.minFatPerc != null || target.maxFatPerc != null) {
      addRange(
        pctCoeffs((m) => m.fatPct),
        target.minFatPerc == null ? null : target.minFatPerc! / 100 * totalWeightLbs,
        target.maxFatPerc == null ? null : target.maxFatPerc! / 100 * totalWeightLbs,
      );
    }
    if (target.minFiberPerc != null || target.maxFiberPerc != null) {
      addRange(
        pctCoeffs((m) => m.fiberPct),
        target.minFiberPerc == null ? null : target.minFiberPerc! / 100 * totalWeightLbs,
        target.maxFiberPerc == null ? null : target.maxFiberPerc! / 100 * totalWeightLbs,
      );
    }
    addRange(pctCoeffs((m) => m.lysinePct), target.minLysinePerc / 100 * totalWeightLbs, null);
    addRange(pctCoeffs((m) => m.methioninePct), target.minMethioninePerc / 100 * totalWeightLbs, null);
    addRange(pctCoeffs((m) => m.taurinePct), target.minTaurinePerc / 100 * totalWeightLbs, null);
    addRange(rawCoeffs((m) => m.niacinMgKg), target.minNiacinMgKg * totalWeightLbs, null);
    addRange(rawCoeffs((m) => m.energyKcalLb), adjMinEnergyKcalLb * totalWeightLbs,
        adjMaxEnergyKcalLb * totalWeightLbs);

    constraints.addAll(_hardSafetyConstraints(
      candidates: candidates,
      totalWeightLbs: totalWeightLbs,
      safetyRules: safetyRules,
      profile: profile,
    ));

    final costs = candidates.map((i) => lowCostIds.contains(i.id) ? 0.0 : 1.0).toList();
    final result = SimplexSolver.minimize(costs: costs, constraints: constraints);
    if (!result.feasible) {
      return (feasible: false, lbsByIngredientId: <String, double>{});
    }

    final lbsByIngredientId = <String, double>{};
    for (var i = 0; i < n; i++) {
      if (result.solution[i] > 1e-6) {
        lbsByIngredientId[candidates[i].id] = result.solution[i];
      }
    }
    return (feasible: true, lbsByIngredientId: lbsByIngredientId);
  }

  /// Turns every species-applicable [SafetyRule] with a hard numeric cap
  /// into a linear constraint on the LP's candidate variables, so the
  /// solver can't propose a blend that would trip it in the first place.
  /// Mirrors the same rule interpretation as [_runSafetyChecks] (dry-matter
  /// basis conversion, ratio bands, category/keyword inclusion caps) but
  /// as `coefficients · x {<=,>=} rhs` instead of a post-hoc percentage
  /// check - see the doc comment on [_solveDietLp] for why both exist.
  static List<LpConstraint> _hardSafetyConstraints({
    required List<Ingredient> candidates,
    required double totalWeightLbs,
    required List<SafetyRule> safetyRules,
    required AnimalProfile profile,
  }) {
    final constraints = <LpConstraint>[];
    final speciesText = profile.species.toLowerCase();
    final n = candidates.length;

    List<double> field(double Function(AsFedMetrics) f) => candidates.map((i) => f(i.asFedMetrics)).toList();

    for (final rule in safetyRules) {
      if (rule.appliesToSpecies.isNotEmpty &&
          !rule.appliesToSpecies.any((s) => _speciesTextMatches(speciesText, s))) {
        continue;
      }

      if (rule.targetType == 'dm_concentration') {
        List<double>? valueField;
        switch (rule.targetName) {
          case 'Cu_ppm_DM':
            valueField = field((m) => m.copperPpm);
            break;
          case 'Oxalate_pct_DM':
            valueField = field((m) => m.oxalatePct);
            break;
          case 'Sugar_pct_DM':
            valueField = field((m) => m.sugarPct);
            break;
        }
        if (valueField == null) continue;
        final dm = field((m) => m.dryMatterPct ?? 100.0);
        if (rule.maxValue != null) {
          final coeffs = List<double>.generate(n, (i) => valueField![i] - (rule.maxValue! / 100.0) * dm[i]);
          constraints.add(LpConstraint(coeffs, ConstraintType.lessOrEqual, 0));
        }
        if (rule.minValue != null) {
          final coeffs = List<double>.generate(n, (i) => valueField![i] - (rule.minValue! / 100.0) * dm[i]);
          constraints.add(LpConstraint(coeffs, ConstraintType.greaterOrEqual, 0));
        }
        continue;
      }

      if (rule.targetType == 'ratio') {
        List<double>? numerator;
        List<double>? denominator;
        switch (rule.targetName) {
          case 'Ca:AvailP_grower':
          case 'Ca:AvailP_layer':
          case 'Ca:AvailP_general':
            if (!_caAvailPRuleApplies(rule, profile)) continue;
            numerator = field((m) => m.calciumPct);
            denominator = field((m) => m.phosphorusPct);
            break;
          case 'Cu:Mo':
            numerator = field((m) => m.copperPpm);
            denominator = field((m) => m.molybdenumPpm);
            break;
          case 'Ca:Oxalate':
            numerator = field((m) => m.calciumPct);
            denominator = field((m) => m.oxalatePct);
            break;
        }
        if (numerator == null || denominator == null) continue;
        if (rule.minRatio != null) {
          final coeffs = List<double>.generate(n, (i) => numerator![i] - rule.minRatio! * denominator![i]);
          constraints.add(LpConstraint(coeffs, ConstraintType.greaterOrEqual, 0));
        }
        if (rule.maxRatio != null) {
          final coeffs = List<double>.generate(n, (i) => numerator![i] - rule.maxRatio! * denominator![i]);
          constraints.add(LpConstraint(coeffs, ConstraintType.lessOrEqual, 0));
        }
        continue;
      }

      if (rule.targetType == 'category_total' && rule.maxInclusionPerc != null) {
        final coeffs = List<double>.generate(
          n,
          (i) => candidates[i].category.toLowerCase() == rule.targetName.toLowerCase() ? 1.0 : 0.0,
        );
        constraints
            .add(LpConstraint(coeffs, ConstraintType.lessOrEqual, rule.maxInclusionPerc! / 100.0 * totalWeightLbs));
        continue;
      }

      if ((rule.targetType == 'ingredient_category' || rule.targetType == 'ingredient_keyword') &&
          rule.maxInclusionPerc != null) {
        for (var i = 0; i < n; i++) {
          if (!candidates[i].name.toLowerCase().contains(rule.targetName.toLowerCase())) continue;
          final coeffs = List<double>.filled(n, 0.0);
          coeffs[i] = 1.0;
          constraints.add(
              LpConstraint(coeffs, ConstraintType.lessOrEqual, rule.maxInclusionPerc! / 100.0 * totalWeightLbs));
        }
      }
    }
    return constraints;
  }

  /// Whether a Ca:AvailP_* ratio rule variant applies to this profile's
  /// current production stage - mirrors the stage matching in
  /// [_runSafetyChecks] exactly, since both need to agree on which single
  /// Ca:P band is "the" applicable one for a given stage.
  static bool _caAvailPRuleApplies(SafetyRule rule, AnimalProfile profile) {
    final stage = profile.productionStage.toLowerCase();
    final isStarterStage = stage.contains('grower') || stage.contains('starter') || stage.contains('juvenile');
    final isLayerStage = stage.contains('layer');
    switch (rule.targetName) {
      case 'Ca:AvailP_grower':
        return isStarterStage;
      case 'Ca:AvailP_layer':
        return isLayerStage;
      case 'Ca:AvailP_general':
        return !isStarterStage && !isLayerStage;
      default:
        return false;
    }
  }

  static const double _lbToOz = 16.0;

  static ({List<String> steps, int? portionCount, double? portionSizeOz}) _buildInstructions({
    required AnimalProfile profile,
    required List<RationLineItem> baseItems,
    required List<RationLineItem> supplementItems,
    required PrepAmountResult prep,
    required double totalWeightLbs,
  }) {
    final steps = <String>[
      ..._equipmentSteps(profile: profile, baseItems: baseItems, supplementItems: supplementItems),
    ];

    final isFreeChoice = profile.feedingSystem == 'Free-Choice Grain + Supplement';
    final isRaw = profile.feedingSystem == 'Raw / Whole Food + Premix';

    if (baseItems.isEmpty) {
      steps.add('No base pantry items in this batch.');
    } else if (baseItems.length == 1) {
      steps.add('Prepare ${baseItems.first.ingredient.name}.');
    } else if (isFreeChoice) {
      steps.add(
        'Offer these separately rather than mixing them into one ration - keep each available '
        'free-choice so the animal can self-balance intake: ${baseItems.map((i) => i.ingredient.name).join(', ')}.',
      );
    } else {
      final sorted = [...baseItems]..sort((a, b) => a.lbs.compareTo(b.lbs));
      final lighter = sorted.sublist(0, sorted.length - 1);
      final heaviest = sorted.last;
      final verb = isRaw ? 'Combine' : 'Blend';
      steps.add(
        '$verb ${lighter.map((i) => i.ingredient.name).join(', ')} together, '
        'then mix in ${heaviest.ingredient.name}.',
      );
    }

    if (supplementItems.isNotEmpty) {
      steps.add(
        isFreeChoice
            ? 'Provide free-choice: ${supplementItems.map((i) => i.ingredient.name).join(', ')} '
                '(e.g. a mineral block or top-dress station), separate from the base feed.'
            : isRaw
                ? 'Mix in a vitamin/mineral premix to close the gap: '
                    '${supplementItems.map((i) => i.ingredient.name).join(', ')}, and mix well.'
                : 'Add supplements: ${supplementItems.map((i) => i.ingredient.name).join(', ')}, and mix well.',
      );
    }

    int? portionCount;
    double? portionSizeOz;
    if (isFreeChoice) {
      steps.add(
        'Total to have on hand: ~${totalWeightLbs.toStringAsFixed(2)} lb. Restock the free-choice '
        'station(s) as they run low rather than doling out fixed daily portions.',
      );
    } else if (prep.mode == PrepMode.days && prep.value > 0) {
      final days = prep.value.round();
      final dailyOz = (totalWeightLbs / prep.value) * _lbToOz;
      portionCount = days;
      portionSizeOz = dailyOz;
      final dayWord = 'day${days == 1 ? '' : 's'}';
      final options = [1, 2, 3].map((feedingsPerDay) {
        final count = days * feedingsPerDay;
        final sizeOz = dailyOz / feedingsPerDay;
        return '$count portions (~${sizeOz.toStringAsFixed(1)} oz each) for $feedingsPerDay '
            'time${feedingsPerDay == 1 ? '' : 's'} a day';
      }).join(', OR ');
      steps.add('Divide into $options - pick whichever feeding frequency you\'re using for these $days $dayWord.');
    } else {
      steps.add('Store as a single ~${totalWeightLbs.toStringAsFixed(2)} lb batch.');
    }

    return (steps: steps, portionCount: portionCount, portionSizeOz: portionSizeOz);
  }

  /// Species catalog categories (the part of [AnimalProfile.species] before
  /// the colon) whose members are typically small/young enough to need food
  /// ground or pureed rather than just cut into pieces.
  static const _fineTextureCategories = {'rodent', 'amphibian', 'marsupial', 'bird'};

  static bool _needsFineTexture(AnimalProfile profile) {
    if (profile.ageGroup == 'Baby') return true;
    final category = profile.species.split(':').first.trim().toLowerCase();
    return _fineTextureCategories.contains(category);
  }

  static bool _isFreshOrFrozenProtein(Ingredient i) =>
      i.category == 'Proteins & Meal' && (i.subCategory == 'fresh' || i.subCategory == 'frozen');

  static bool _isFreshProduce(Ingredient i) =>
      (i.category == 'Produce' || i.category == 'Fruits') && i.subCategory == 'fresh';

  /// Recommends the kitchen tools needed to get this batch's fresh/frozen
  /// ingredients to the right texture before blending. Dry, grain, mineral,
  /// and forage items don't need any prep tools - only raw meat and fresh
  /// produce do, and how fine they need to be depends on the animal's size.
  static List<String> _equipmentSteps({
    required AnimalProfile profile,
    required List<RationLineItem> baseItems,
    required List<RationLineItem> supplementItems,
  }) {
    final allIngredients = [...baseItems, ...supplementItems].map((li) => li.ingredient);
    final hasFreshProtein = allIngredients.any(_isFreshOrFrozenProtein);
    final hasFreshProduce = allIngredients.any(_isFreshProduce);
    if (!hasFreshProtein && !hasFreshProduce) return [];

    final needsFine = _needsFineTexture(profile);
    final steps = <String>[];
    if (hasFreshProtein) {
      steps.add(needsFine
          ? 'Use a meat grinder (or food processor) to grind the meat into a fine texture.'
          : 'Use a sharp knife to cut the meat into bite-sized pieces.');
    }
    if (hasFreshProduce) {
      steps.add(needsFine
          ? 'Use a blender to puree the fresh produce into a smooth texture.'
          : 'Use a knife to chop the fresh produce into small pieces.');
    }
    return steps;
  }

  /// A large calcium+phosphorus contribution with almost no protein/fat/
  /// fiber is a mineral supplement (limestone, oyster shell, dicalcium
  /// phosphate) rather than a food item, regardless of which list the user
  /// put it in - blending it in as if it were food would just dilute
  /// everything else.
  static bool _isMineralLike(Ingredient i) {
    final m = i.asFedMetrics;
    final combinedMinerals = m.calciumPct + m.phosphorusPct;
    return combinedMinerals > 10.0 && m.crudeProteinPct < 5.0;
  }

  /// Plain-language reason a given pantry/supplement item didn't make it
  /// into this batch: either the feeding-system whole-food filter excluded
  /// it outright, or the LP solve simply didn't need it to satisfy every
  /// target/safety constraint at once.
  static String _explainExclusion({
    required Ingredient item,
    required Set<String> feedingSystemFilteredIds,
  }) {
    if (feedingSystemFilteredIds.contains(item.id)) {
      return 'Your feeding system (Raw / Whole Food + Premix) prioritizes fresh/frozen protein and fresh '
          'produce over this kind of item, so it was left out of the base blend.';
    }
    return "Not needed to meet every nutrient and safety target at once for this batch - the optimizer "
        'found a combination that works without it. That can change with a different batch size or pantry mix.';
  }

  /// Rough default share of daily dry matter intake assumed to come from
  /// grazing on a "Pasture / Forage-First" profile - a flat, clearly-
  /// caveated estimate (surfaced in the ration's warnings), not a real
  /// pasture-quality assessment. Only applied when the batch size itself is
  /// being estimated from body weight (prep.mode == days); if the user
  /// enters a direct lbs amount, that's already the supplemental amount
  /// they want prepared and is used as-is.
  static const double _assumedPastureCoverageFraction = 0.5;

  /// Rough upper bound on how long portioned-and-frozen fresh/frozen meat or
  /// produce should sit in a freezer before quality/safety are assumed to
  /// start degrading - a conservative, general "3 months" home-freezer
  /// guideline, not an ingredient-specific shelf-life figure (the app has no
  /// per-ingredient freezer-life data to be more precise than that).
  static const int _maxFrozenStorageDays = 90;

  static double _estimateBatchWeightLbs({
    required PrepAmountResult prep,
    required AnimalProfile profile,
    required SpeciesRequirement target,
  }) {
    if (prep.mode == PrepMode.amount) return prep.value;

    final bodyWeightLb = target.targetWeightKg * _kgToLb;
    final intakeRate = _dailyIntakeRateByCategory(profile.species);
    var dailyIntakeLbs = bodyWeightLb > 0 ? bodyWeightLb * intakeRate : 0.5;
    if (profile.feedingSystem == 'Pasture / Forage-First') {
      dailyIntakeLbs *= (1 - _assumedPastureCoverageFraction);
    }
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

  // A plain substring check (speciesText.contains(keyword)) would wrongly
  // match e.g. "cattle - angus".contains("cat") - this requires the
  // keyword to sit on a word boundary, so short species keywords can't be
  // fooled by a longer species name that happens to start with them.
  static bool _speciesTextMatches(String speciesText, String keyword) {
    final pattern = RegExp('(?<![a-z0-9])${RegExp.escape(keyword.toLowerCase())}(?![a-z0-9])');
    return pattern.hasMatch(speciesText);
  }

  // When a batch blows well past a safety cap (not just a hair over it),
  // a bare percentage isn't actionable - nudge toward swapping/reducing the
  // offending ingredient instead of leaving the user to guess what to do.
  static String _overCapSuffix(double inclusionPct, double maxPct) {
    if (maxPct <= 0 || inclusionPct < maxPct * 2) return '';
    return ' This is well over double the safe limit - look for a substitute ingredient or reduce this item\'s share of the batch.';
  }

  static List<RationWarning> _runSafetyChecks({
    required AnimalProfile profile,
    required List<Ingredient> allItems,
    required Map<String, double> allLbs,
    required double finalTotalLbs,
    required double finalCalciumPct,
    required double finalPhosphorusPct,
    required double finalCopperPpm,
    required double finalMolybdenumPpm,
    required double finalOxalatePct,
    required double finalSugarPct,
    required double finalDMPct,
    required List<SafetyRule> safetyRules,
  }) {
    final warnings = <RationWarning>[];
    if (finalTotalLbs <= 0) return warnings;

    final speciesText = profile.species.toLowerCase();
    for (final rule in safetyRules) {
      if (rule.appliesToSpecies.isNotEmpty &&
          !rule.appliesToSpecies.any((s) => _speciesTextMatches(speciesText, s))) {
        continue;
      }
      if (rule.targetType == 'dm_concentration') {
        // Absolute concentration cap/floor expressed on a dry-matter basis
        // (e.g. "copper must stay under 10 ppm DM for sheep") - converts
        // this blend's as-fed concentration using finalDMPct, since a
        // published DM-basis threshold isn't directly comparable to an
        // as-fed number for anything with meaningful moisture content.
        final dmFraction = finalDMPct / 100.0;
        if (dmFraction <= 0) continue;
        double value;
        switch (rule.targetName) {
          case 'Cu_ppm_DM':
            if (finalCopperPpm <= 0) continue;
            value = finalCopperPpm / dmFraction;
            break;
          case 'Oxalate_pct_DM':
            if (finalOxalatePct <= 0) continue;
            value = finalOxalatePct / dmFraction;
            break;
          case 'Sugar_pct_DM':
            if (finalSugarPct <= 0) continue;
            value = finalSugarPct / dmFraction;
            break;
          default:
            continue;
        }
        if ((rule.minValue != null && value < rule.minValue!) ||
            (rule.maxValue != null && value > rule.maxValue!)) {
          warnings.add(RationWarning(
            message: '${rule.warningMessage} (currently ~${value.toStringAsFixed(1)} DM basis)',
            severity: WarningSeverity.parse(rule.severity),
          ));
        }
        continue;
      }

      if (rule.targetType == 'ratio') {
        double? ratio;
        switch (rule.targetName) {
          case 'Ca:AvailP_grower':
          case 'Ca:AvailP_layer':
          case 'Ca:AvailP_general':
            if (!_caAvailPRuleApplies(rule, profile)) continue;
            if (finalPhosphorusPct <= 0) continue;
            ratio = finalCalciumPct / finalPhosphorusPct;
            break;
          case 'Cu:Mo':
            if (finalMolybdenumPpm <= 0) continue;
            ratio = finalCopperPpm / finalMolybdenumPpm;
            break;
          case 'Ca:Oxalate':
            if (finalOxalatePct <= 0) continue;
            ratio = finalCalciumPct / finalOxalatePct;
            break;
          default:
            continue;
        }
        if ((rule.minRatio != null && ratio < rule.minRatio!) ||
            (rule.maxRatio != null && ratio > rule.maxRatio!)) {
          warnings.add(RationWarning(message: rule.warningMessage, severity: WarningSeverity.parse(rule.severity)));
        }
        continue;
      }

      if (rule.targetType == 'category_total') {
        // Sums inclusion % across every item whose real Ingredient.category
        // matches, rather than a single item's name - used for checks like
        // "total grain/concentrate share of the ration," where no single
        // ingredient name would ever match but the combined total matters.
        final categoryLbs = allItems
            .where((item) => item.category.toLowerCase() == rule.targetName.toLowerCase())
            .fold(0.0, (sum, item) => sum + (allLbs[item.id] ?? 0));
        final inclusionPct = (categoryLbs / finalTotalLbs) * 100.0;
        if (rule.maxInclusionPerc != null && inclusionPct > rule.maxInclusionPerc!) {
          warnings.add(RationWarning(
            message: '${rule.warningMessage} (currently ${inclusionPct.toStringAsFixed(1)}%)'
                '${_overCapSuffix(inclusionPct, rule.maxInclusionPerc!)}',
            severity: WarningSeverity.parse(rule.severity),
          ));
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
          warnings.add(RationWarning(
            message: '${item.name}: ${rule.warningMessage} (currently ${inclusionPct.toStringAsFixed(1)}%)'
                '${_overCapSuffix(inclusionPct, rule.maxInclusionPerc!)}',
            severity: WarningSeverity.parse(rule.severity),
          ));
        }
      }
    }
    return warnings;
  }
}
