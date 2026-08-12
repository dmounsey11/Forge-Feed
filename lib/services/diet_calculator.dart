import '../models/animal_profile.dart';
import '../models/ingredient.dart';
import '../models/ration_result.dart';
import '../models/health_screening_result.dart';
import '../models/safety_rule.dart';
import '../models/species_requirement.dart';
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
    // belong in the gap-fill supplement math below, not blended at equal
    // weight into the base, no matter which list the user happened to put
    // them in.
    var foodCandidates = pantryItems.where((i) => !_isMineralLike(i)).toList();
    if (profile.feedingSystem == 'Raw / Whole Food + Premix') {
      // Prefer genuinely fresh/whole ingredients over processed grains/meals
      // when the pantry has any, since that's the point of this mode; if it
      // doesn't, fall back to the full candidate list rather than returning
      // an empty ration.
      final wholeFoodItems =
          foodCandidates.where((i) => _isFreshOrFrozenProtein(i) || _isFreshProduce(i)).toList();
      if (wholeFoodItems.isNotEmpty) foodCandidates = wholeFoodItems;
    }
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

    // 4. Safety rule checks against the final blend.
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
      finalDMPct: finalDMPct,
      safetyRules: safetyRules,
    );
    if (!stageHasDedicatedData) {
      warnings.insert(
        0,
        'No dedicated nutrition data yet for the "${profile.productionStage}" stage of this species - '
        'this ration uses general/maintenance-level targets instead. Treat it as a rough starting point, '
        'not a stage-tuned recipe.',
      );
    }
    if (profile.feedingSystem == 'Pasture / Forage-First' && prep.mode == PrepMode.days) {
      warnings.insert(
        0,
        'Assuming grazing covers about ${(_assumedPastureCoverageFraction * 100).round()}% of daily intake - '
        'a flat default, not a real assessment of your pasture. This batch is sized to cover the rest. If your '
        'grazing coverage is better or worse than that, enter a direct lbs amount instead of a number of days.',
      );
    }
    if (profile.feedingSystem == 'Pasture / Forage-First' && profile.environment == 'Indoor') {
      warnings.add(
        'This profile is set to "Pasture / Forage-First" but the environment is "Indoor" - '
        'double check that\'s intentional.',
      );
    }
    final hasPerishableItems = allItems.any((i) => _isFreshOrFrozenProtein(i) || _isFreshProduce(i));
    if (hasPerishableItems && prep.mode == PrepMode.days && prep.value > _maxFrozenStorageDays) {
      warnings.add(
        'You\'re prepping ${prep.value.round()} days\' worth of portions containing fresh/frozen meat or '
        'produce. That\'s beyond the roughly $_maxFrozenStorageDays-day (3-month) window recommended for '
        'frozen raw ingredients before quality and safety start to degrade. Consider freezing this in two '
        'or more smaller batches instead of one long-dated batch.',
      );
    }

    final finalBaseItems = selectedFoodItems
        .where((i) => (baseLbs[i.id] ?? 0) > 0)
        .map((i) => RationLineItem(ingredient: i, lbs: baseLbs[i.id]!))
        .toList();
    final finalSupplementItems = supplementPool
        .where((i) => (supplementLbs[i.id] ?? 0) > 0)
        .map((i) => RationLineItem(ingredient: i, lbs: supplementLbs[i.id]!))
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
      excludedItemNames: excludedItemNames,
      instructionSteps: instructions.steps,
      portionCount: instructions.portionCount,
      portionSizeOz: instructions.portionSizeOz,
    );
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

  static bool _isFreshProduce(Ingredient i) => i.category == 'Produce' && i.subCategory == 'fresh';

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
    required double finalCopperPpm,
    required double finalMolybdenumPpm,
    required double finalOxalatePct,
    required double finalDMPct,
    required List<SafetyRule> safetyRules,
  }) {
    final warnings = <String>[];
    if (finalTotalLbs <= 0) return warnings;

    final speciesText = profile.species.toLowerCase();
    for (final rule in safetyRules) {
      if (rule.appliesToSpecies.isNotEmpty &&
          !rule.appliesToSpecies.any((s) => speciesText.contains(s.toLowerCase()))) {
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
          default:
            continue;
        }
        if ((rule.minValue != null && value < rule.minValue!) ||
            (rule.maxValue != null && value > rule.maxValue!)) {
          warnings.add('${rule.warningMessage} (currently ~${value.toStringAsFixed(1)} DM basis)');
        }
        continue;
      }

      if (rule.targetType == 'ratio') {
        double? ratio;
        switch (rule.targetName) {
          case 'Ca:AvailP_grower':
          case 'Ca:AvailP_layer':
          case 'Ca:AvailP_general':
            final stage = profile.productionStage.toLowerCase();
            final isStarterStage = stage.contains('grower') || stage.contains('starter') || stage.contains('juvenile');
            final isLayerStage = stage.contains('layer');
            final appliesToGrower = rule.targetName == 'Ca:AvailP_grower' && isStarterStage;
            final appliesToLayer = rule.targetName == 'Ca:AvailP_layer' && isLayerStage;
            // General livestock band (1.5:1-2:1-ish) is a fallback for any
            // stage not already covered by a more specific starter/layer
            // band above, so ruminant/other mammal stages like maintenance,
            // lactating, and breeder aren't left with no Ca:P check at all.
            final appliesToGeneral = rule.targetName == 'Ca:AvailP_general' && !isStarterStage && !isLayerStage;
            if (!appliesToGrower && !appliesToLayer && !appliesToGeneral) continue;
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
          warnings.add(rule.warningMessage);
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
          warnings.add('${rule.warningMessage} (currently ${inclusionPct.toStringAsFixed(1)}%)');
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
