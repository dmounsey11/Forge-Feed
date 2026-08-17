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

  /// Nutrient-target bounds the calculator couldn't hit for this batch and
  /// automatically relaxed rather than refusing to produce a ration - see
  /// [DietCalculator._autoRelax]. Empty when every target was met. These are
  /// preference/cumulative-style ranges, not safety limits, so their
  /// presence here is informational (also surfaced as a matching
  /// medium-severity entry in [warnings]), never a reason to block the
  /// batch.
  final List<NutrientShortfall> nutrientShortfalls;

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
    this.nutrientShortfalls = const [],
  });
}

/// Why [RationCalculationError] was returned instead of a [RationResult].
/// Nutrient-target conflicts no longer produce an error at all - see
/// [DietCalculator._autoRelax] - so this only covers cases nothing can
/// relax around.
enum DietFailureReason {
  /// No pantry/supplement candidates were available, or the batch weight
  /// was <= 0.
  noCandidates,

  /// Even after relaxing every nutrient-target bound, a hard safety
  /// constraint (or the candidate pool itself) still can't be satisfied -
  /// a genuine danger/feasibility conflict, not a preference-range miss.
  safetyConflict,
}

/// One nutrient-target bound the calculator couldn't hit for this batch and
/// relaxed instead of blocking, plus the real achievable extreme for that
/// nutrient - computed by re-solving the LP with every hard safety
/// constraint and every *other* nutrient bound still active, never
/// estimated or interpolated - and a plain-language suggestion for a
/// natural food/supplement that would close the gap.
class NutrientShortfall {
  /// Matches a [NutrientComparison.label] (e.g. 'Protein', 'Fat').
  final String label;
  final String unit;

  /// True if [targetValue] is a floor that couldn't be reached; false if
  /// it's a ceiling that couldn't be stayed under.
  final bool isMinBound;

  /// This nutrient's normal target bound, in display units (e.g. 30.0 for
  /// "30%"), before it was relaxed.
  final double targetValue;

  /// The true achievable extreme (max reachable if [isMinBound], min
  /// reachable otherwise) for this nutrient given every other constraint
  /// this batch actually satisfies, including every hard safety constraint.
  final double achievableValue;

  /// Plain-language "what to stock" suggestion for closing this gap.
  final String suggestion;

  const NutrientShortfall({
    required this.label,
    required this.unit,
    required this.isMinBound,
    required this.targetValue,
    required this.achievableValue,
    required this.suggestion,
  });
}

/// Returned instead of a [RationResult] when the calculator can't run yet
/// (no species data, no pantry items) or even relaxing every nutrient
/// target still can't clear a hard safety constraint - the screen shows
/// [message] rather than crashing or showing an empty/misleading result.
class RationCalculationError {
  final String message;
  final DietFailureReason reason;

  const RationCalculationError(
    this.message, {
    this.reason = DietFailureReason.safetyConflict,
  });
}
