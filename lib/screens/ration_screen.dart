import 'package:flutter/material.dart';
import '../models/ingredient.dart';

class RationScreen extends StatefulWidget {
  const RationScreen({super.key});

  @override
  State<RationScreen> createState() => _RationScreenState();
}

class _RationScreenState extends State<RationScreen> {
  final List<Map<String, dynamic>> _recipeItems = [
    {
      'ingredient': Ingredient(
        id: '1',
        name: 'Corn, Ground',
        category: 'Grains',
        proteinPct: 8.5,
        calciumPctValue: 0.02,
        phosphorusPctValue: 0.28,
        fatPctValue: 3.8,
        fiberPctValue: 2.2,
        energyMeKcalLb: 1550,
      ),
      'weightLbs': 60.0,
    },
    {
      'ingredient': Ingredient(
        id: '2',
        name: 'Soybean Meal 48%',
        category: 'Proteins',
        proteinPct: 48.0,
        calciumPctValue: 0.20,
        phosphorusPctValue: 0.65,
        fatPctValue: 1.0,
        fiberPctValue: 3.5,
        energyMeKcalLb: 1100,
      ),
      'weightLbs': 40.0,
    },
  ];

  double get _totalWeightLbs {
    return _recipeItems.fold(0.0, (sum, item) => sum + (item['weightLbs'] as double));
  }

  double get _blendedProteinPct {
    if (_totalWeightLbs == 0) return 0.0;
    double totalProteinLbs = _recipeItems.fold(0.0, (sum, item) {
      final ing = item['ingredient'] as Ingredient;
      final w = item['weightLbs'] as double;
      return sum + (w * (ing.proteinPct / 100));
    });
    return (totalProteinLbs / _totalWeightLbs) * 100;
  }

  double get _blendedCalciumPct {
    if (_totalWeightLbs == 0) return 0.0;
    double totalCaLbs = _recipeItems.fold(0.0, (sum, item) {
      final ing = item['ingredient'] as Ingredient;
      final w = item['weightLbs'] as double;
      return sum + (w * (ing.calciumPctValue / 100));
    });
    return (totalCaLbs / _totalWeightLbs) * 100;
  }

  double get _blendedPhosphorusPct {
    if (_totalWeightLbs == 0) return 0.0;
    double totalPLbs = _recipeItems.fold(0.0, (sum, item) {
      final ing = item['ingredient'] as Ingredient;
      final w = item['weightLbs'] as double;
      return sum + (w * (ing.phosphorusPctValue / 100));
    });
    return (totalPLbs / _totalWeightLbs) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ration & Feed Balancer'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nutritional Breakdown',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildNutrientStat('Total Batch Weight', '${_totalWeightLbs.toStringAsFixed(1)} lbs'),
                        _buildNutrientStat('Crude Protein', '${_blendedProteinPct.toStringAsFixed(2)}%'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildNutrientStat('Calcium (Ca)', '${_blendedCalciumPct.toStringAsFixed(2)}%'),
                        _buildNutrientStat('Phosphorus (P)', '${_blendedPhosphorusPct.toStringAsFixed(2)}%'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Mix Ingredients',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _recipeItems.length,
                itemBuilder: (context, index) {
                  final item = _recipeItems[index];
                  final ing = item['ingredient'] as Ingredient;
                  final weight = item['weightLbs'] as double;
                  final pctOfBatch = _totalWeightLbs > 0 ? (weight / _totalWeightLbs) * 100 : 0.0;

                  return Card(
                    child: ListTile(
                      title: Text(ing.name),
                      subtitle: Text('Protein: ${ing.proteinPct}% | Ca: ${ing.calciumPctValue}%'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${weight.toStringAsFixed(1)} lbs', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${pctOfBatch.toStringAsFixed(1)}% of blend', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}