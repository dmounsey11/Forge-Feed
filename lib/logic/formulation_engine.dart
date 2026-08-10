import '../models/ingredient.dart';
import '../models/medical_factor.dart';

/// Represents a single ingredient entry in a batch recipe with its weight/amount.
class RecipeItem {
  final Ingredient ingredient;
  final double weight; // Weight in lbs or kg

  RecipeItem({
    required this.ingredient,
    required this.weight,
  });
}

/// Dynamic target profile adjusted for climate stress and medical overrides.
class AdjustedTargets {
  final double targetProteinPct;
  final double targetCalciumPct;
  final double targetPhosphorusPct;

  AdjustedTargets({
    required this.targetProteinPct,
    required this.targetCalciumPct,
    required this.targetPhosphorusPct,
  });
}

/// The calculated nutritional output of a custom batch blend.
class FormulationResult {
  final double totalWeight;
  final double crudeProteinPct;
  final double crudeFatPct;
  final double crudeFiberPct;
  final double calciumPct;
  final double phosphorusPct;
  final double calciumToPhosphorusRatio;
  final AdjustedTargets targets;
  final List<String> safetyWarnings;

  FormulationResult({
    required this.totalWeight,
    required this.crudeProteinPct,
    required this.crudeFatPct,
    required this.crudeFiberPct,
    required this.calciumPct,
    required this.phosphorusPct,
    required this.calciumToPhosphorusRatio,
    required this.targets,
    required this.safetyWarnings,
  });

  bool get meetsProteinRequirement => crudeProteinPct >= targets.targetProteinPct;
  bool get meetsCalciumRequirement => calciumPct >= targets.targetCalciumPct;
}

/// Core Mathematical Formulation Engine
class FormulationEngine {
  /// Calculates total nutritional values for a list of recipe items and checks safety rules.
  static FormulationResult calculateBlend({
    required List<RecipeItem> items,
    required double baseProteinTargetPct,
    required double baseCalciumTargetPct,
    required double basePhosphorusTargetPct,
    double tempProteinMultiplier = 1.0,
    double tempCalciumMultiplier = 1.0,
    MedicalFactor? activeMedicalOverride,
  }) {
    // 1. Calculate Combined Multipliers
    double finalProteinMult = tempProteinMultiplier * (activeMedicalOverride?.proteinMultiplier ?? 1.0);
    double finalCalciumMult = tempCalciumMultiplier * (activeMedicalOverride?.calciumMultiplier ?? 1.0);

    final adjustedTargets = AdjustedTargets(
      targetProteinPct: baseProteinTargetPct * finalProteinMult,
      targetCalciumPct: baseCalciumTargetPct * finalCalciumMult,
      targetPhosphorusPct: basePhosphorusTargetPct,
    );

    double totalWeight = 0.0;
    double totalProteinLbs = 0.0;
    double totalFatLbs = 0.0;
    double totalFiberLbs = 0.0;
    double totalCalciumLbs = 0.0;
    double totalPhosphorusLbs = 0.0;

    final List<String> warnings = [];

    // 2. Aggregate Nutrient Amounts
    for (final item in items) {
      final w = item.weight;
      if (w <= 0) continue;

      totalWeight += w;
      totalProteinLbs += w * (item.ingredient.asFedMetrics.crudeProteinPct / 100.0);
      totalFatLbs += w * (item.ingredient.asFedMetrics.crudeFatPct / 100.0);
      totalFiberLbs += w * (item.ingredient.asFedMetrics.crudeFiberPct / 100.0);
      totalCalciumLbs += w * (item.ingredient.asFedMetrics.calciumPct / 100.0);
      totalPhosphorusLbs += w * (item.ingredient.asFedMetrics.phosphorusPct / 100.0);
    }

    if (totalWeight <= 0) {
      return FormulationResult(
        totalWeight: 0,
        crudeProteinPct: 0,
        crudeFatPct: 0,
        crudeFiberPct: 0,
        calciumPct: 0,
        phosphorusPct: 0,
        calciumToPhosphorusRatio: 0,
        targets: adjustedTargets,
        safetyWarnings: ['Batch weight is zero. Add ingredients to calculate.'],
      );
    }

    // 3. Compute Blend Percentages
    final blendProteinPct = (totalProteinLbs / totalWeight) * 100.0;
    final blendFatPct = (totalFatLbs / totalWeight) * 100.0;
    final blendFiberPct = (totalFiberLbs / totalWeight) * 100.0;
    final blendCalciumPct = (totalCalciumLbs / totalWeight) * 100.0;
    final blendPhosphorusPct = (totalPhosphorusLbs / totalWeight) * 100.0;

    final caPRatio = blendPhosphorusPct > 0 ? (blendCalciumPct / blendPhosphorusPct) : 0.0;

    // 4. Run Safety Rule Checks
    for (final item in items) {
      final inclusionPct = (item.weight / totalWeight) * 100.0;
      final nameLower = item.ingredient.name.toLowerCase();

      if (nameLower.contains('salt') && inclusionPct > 0.5) {
        warnings.add('Salt inclusion (${inclusionPct.toStringAsFixed(1)}%) exceeds maximum 0.5% limit.');
      }
      if (nameLower.contains('cottonseed') && inclusionPct > 5.0) {
        warnings.add('Cottonseed inclusion (${inclusionPct.toStringAsFixed(1)}%) exceeds 5.0% gossypol limit.');
      }
      if (nameLower.contains('fish meal') && inclusionPct > 5.0) {
        warnings.add('Fish meal inclusion (${inclusionPct.toStringAsFixed(1)}%) exceeds 5.0% flavor taint cap.');
      }
    }

    return FormulationResult(
      totalWeight: totalWeight,
      crudeProteinPct: blendProteinPct,
      crudeFatPct: blendFatPct,
      crudeFiberPct: blendFiberPct,
      calciumPct: blendCalciumPct,
      phosphorusPct: blendPhosphorusPct,
      calciumToPhosphorusRatio: caPRatio,
      targets: adjustedTargets,
      safetyWarnings: warnings,
    );
  }
}