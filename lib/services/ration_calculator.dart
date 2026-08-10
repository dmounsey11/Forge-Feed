import 'database_service.dart';
import '../models/species_requirement.dart';

/// Represents a single ingredient entry in a proposed ration recipe.
class RationItem {
  final String ingredientId;
  final double weight; // Weight in lbs or kg

  RationItem({
    required this.ingredientId,
    required this.weight,
  });
}

/// Stores calculated nutritional values for a feed blend and compares them against target goals.
class RationResult {
  final double totalWeight;
  final double crudeProteinPercentage;
  final double metabolizableEnergy; // kcal/kg
  final double calciumPercentage;
  final double phosphorusPercentage;
  final Map<String, double> deltas; // Positive = excess, Negative = deficiency

  RationResult({
    required this.totalWeight,
    required this.crudeProteinPercentage,
    required this.metabolizableEnergy,
    required this.calciumPercentage,
    required this.phosphorusPercentage,
    required this.deltas,
  });
}

class RationCalculator {
  /// Analyzes a list of batch ingredient weights against species nutrient targets.
  static RationResult calculateRation({
    required List<RationItem> items,
    required SpeciesRequirement targetRequirements,
  }) {
    final db = DatabaseService.instance;

    double totalWeight = 0.0;
    double totalProtein = 0.0;
    double totalEnergy = 0.0;
    double totalCalcium = 0.0;
    double totalPhosphorus = 0.0;

    for (var item in items) {
      if (item.weight <= 0) continue;

      // Find ingredient in loaded database
      final ingredient = db.ingredients.firstWhere(
        (i) => i.id == item.ingredientId,
        orElse: () => throw Exception('Ingredient not found: ${item.ingredientId}'),
      );

      totalWeight += item.weight;
      totalProtein += item.weight * (ingredient.asFedMetrics.crudeProteinPct / 100.0);
      totalEnergy += item.weight * ingredient.asFedMetrics.metabolicEnergyKcal;
      totalCalcium += item.weight * (ingredient.asFedMetrics.calciumPct / 100.0);
      totalPhosphorus += item.weight * (ingredient.asFedMetrics.phosphorusPct / 100.0);
    }

    if (totalWeight == 0) {
      return RationResult(
        totalWeight: 0,
        crudeProteinPercentage: 0,
        metabolizableEnergy: 0,
        calciumPercentage: 0,
        phosphorusPercentage: 0,
        deltas: {},
      );
    }

    final calculatedProteinPct = (totalProtein / totalWeight) * 100.0;
    final calculatedEnergy = totalEnergy / totalWeight;
    final calculatedCalciumPct = (totalCalcium / totalWeight) * 100.0;
    final calculatedPhosPct = (totalPhosphorus / totalWeight) * 100.0;

    return RationResult(
      totalWeight: totalWeight,
      crudeProteinPercentage: calculatedProteinPct,
      metabolizableEnergy: calculatedEnergy,
      calciumPercentage: calculatedCalciumPct,
      phosphorusPercentage: calculatedPhosPct,
      deltas: {
        'protein': calculatedProteinPct - targetRequirements.minCrudeProtein,
        'energy': calculatedEnergy - targetRequirements.minMetabolizableEnergy,
        'calcium': calculatedCalciumPct - targetRequirements.minCalcium,
        'phosphorus': calculatedPhosPct - targetRequirements.minPhosphorus,
      },
    );
  }
}