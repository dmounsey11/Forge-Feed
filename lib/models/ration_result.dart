import 'ingredient.dart';

class RationLineItem {
  final Ingredient ingredient;
  final double lbs;

  const RationLineItem({required this.ingredient, required this.lbs});
}

enum NutrientStatus { onTrack, low, high, unknown }

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
  final List<String> warnings;
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

/// Returned instead of a [RationResult] when the calculator can't run yet
/// (no species data, no pantry items) - the screen shows [message] rather
/// than crashing or showing an empty/misleading result.
class RationCalculationError {
  final String message;
  const RationCalculationError(this.message);
}
