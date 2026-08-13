import 'ingredient.dart';

class RationLineItem {
  final Ingredient ingredient;
  final double lbs;

  const RationLineItem({required this.ingredient, required this.lbs});
}

enum NutrientStatus { onTrack, low, high, unknown }

/// Ordered most- to least-severe so callers can sort a warning list simply
/// by `severity.index`. Mirrors the severities used in safety_rules.json
/// ('CRITICAL'|'HIGH'|'MEDIUM'|'LOW') plus covers the calculator's own
/// hand-written advisory notes, which aren't backed by a SafetyRule.
enum WarningSeverity {
  critical,
  high,
  medium,
  low;

  static WarningSeverity parse(String raw) {
    switch (raw.trim().toUpperCase()) {
      case 'CRITICAL':
        return WarningSeverity.critical;
      case 'HIGH':
        return WarningSeverity.high;
      case 'MEDIUM':
        return WarningSeverity.medium;
      default:
        return WarningSeverity.low;
    }
  }
}

class RationWarning {
  final String message;
  final WarningSeverity severity;

  const RationWarning({required this.message, required this.severity});
}

class NutrientComparison {
  final String label;
  final String unit;
  final double? targetMin;
  final double? targetMax;
  final double actual;
  final NutrientStatus status;

  const NutrientComparison({
    required this.label,
    required this.unit,
    required this.targetMin,
    required this.targetMax,
    required this.actual,
    required this.status,
  });
}

/// A pantry/supplement item that was available for this batch but didn't
/// make it into the final blend, plus a plain-language reason why - so the
/// UI can explain the omission instead of just naming it.
class ExcludedItem {
  final String name;
  final String reason;

  const ExcludedItem({required this.name, required this.reason});
}

class RationResult {
  final double totalWeightLbs;
  final List<RationLineItem> baseItems;
  final List<RationLineItem> supplementItems;
  final List<NutrientComparison> nutrientComparisons;
  final List<RationWarning> warnings;
  final List<String> healthNotes;
  final List<ExcludedItem> excludedItems;
  final List<String> instructionSteps;
  final int? portionCount;
  final double? portionSizeOz;

  const RationResult({
    required this.totalWeightLbs,
    required this.baseItems,
    required this.supplementItems,
    required this.nutrientComparisons,
    required this.warnings,
    required this.healthNotes,
    this.excludedItems = const [],
    this.instructionSteps = const [],
    this.portionCount,
    this.portionSizeOz,
  });
}

/// Why [RationCalculationError] was returned instead of a [RationResult] -
/// lets the UI tell a genuine nutrient-target conflict (which the
/// calculator's diagnostic pass can explain and offer to relax) apart from
/// an input problem no diagnostic can help with.
enum DietFailureReason {
  /// No pantry/supplement candidates were available, or the batch weight
  /// was <= 0 - nothing for a diagnostic pass to explain or relax.
  noCandidates,

  /// The primary solve failed, but the diagnostic pass confirmed which
  /// nutrient-target bound(s) are the bottleneck by actually re-solving the
  /// LP - see [RationCalculationError.bottlenecks].
  nutrientInfeasibility,

  /// The primary solve failed and the diagnostic pass could not pin the
  /// conflict to one nutrient bound or one pair of them (a deeper conflict,
  /// or one rooted in a hard safety constraint, which is never a relaxation
  /// candidate) - reported the same as before, with no bottleneck detail.
  unexplainedInfeasibility,
}

/// One nutrient-target bound the diagnostic pass identified as (part of)
/// why the primary solve was infeasible, plus the real achievable extreme
/// for that nutrient - computed by re-solving the LP with every hard safety
/// constraint and every *other* nutrient bound still active, never
/// estimated or interpolated.
class NutrientBottleneck {
  /// Matches a [NutrientComparison.label] (e.g. 'Protein', 'Fat').
  final String label;
  final String unit;

  /// The original target's bound value, in display units (e.g. 30.0 for
  /// "30%"), before this diagnostic ever ran.
  final double blockedBoundValue;

  /// True if [blockedBoundValue] is a floor that can't be reached; false if
  /// it's a ceiling that can't be stayed under.
  final bool isMinBound;

  /// The true achievable extreme (max reachable if [isMinBound], min
  /// reachable otherwise) for this nutrient given every other original
  /// constraint, including every hard safety constraint.
  final double achievableValue;

  const NutrientBottleneck({
    required this.label,
    required this.unit,
    required this.blockedBoundValue,
    required this.isMinBound,
    required this.achievableValue,
  });
}

/// Identifies exactly one nutrient-target bound to loosen for a single
/// "allow temporary target relaxation" re-solve of [DietCalculator.calculate]
/// - built directly from a [NutrientBottleneck] the diagnostic pass already
/// computed, so only the handful of addRange-based nutrient bounds are ever
/// reachable here - hard safety constraints have no corresponding label and
/// can never be constructed into one of these.
class NutrientRelaxation {
  final String label;
  final String unit;
  final bool isMinBound;
  final double relaxedValue;

  const NutrientRelaxation({
    required this.label,
    required this.unit,
    required this.isMinBound,
    required this.relaxedValue,
  });
}

/// Returned instead of a [RationResult] when the calculator can't run yet
/// (no species data, no pantry items) or the primary LP solve found no
/// feasible ration - the screen shows [message] rather than crashing or
/// showing an empty/misleading result. [reason] and [bottlenecks] are
/// additive/optional: existing callers that only read [message] are
/// unaffected.
class RationCalculationError {
  final String message;
  final DietFailureReason reason;
  final List<NutrientBottleneck> bottlenecks;

  const RationCalculationError(
    this.message, {
    this.reason = DietFailureReason.unexplainedInfeasibility,
    this.bottlenecks = const [],
  });
}
