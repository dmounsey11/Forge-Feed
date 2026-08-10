import 'package:flutter_test/flutter_test.dart';
import 'package:forge_feed/models/species_requirement.dart';
import 'package:forge_feed/services/ration_calculator.dart';

void main() {
  group('RationCalculator Unit Tests', () {
    test('Returns zeroed result when items list is empty', () {
      final defaultReq = SpeciesRequirement(
        id: 'test',
        name: 'Test Requirement',
        category: 'Poultry',
        minCrudeProtein: 16.0,
        minMetabolizableEnergy: 1300.0,
        minCalcium: 1.0,
        minPhosphorus: 0.45,
      );

      final result = RationCalculator.calculateRation(
        items: [],
        targetRequirements: defaultReq,
      );

      expect(result.totalWeight, 0.0);
      expect(result.crudeProteinPercentage, 0.0);
      expect(result.metabolizableEnergy, 0.0);
    });
  });
}