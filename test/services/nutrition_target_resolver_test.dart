import 'package:flutter_test/flutter_test.dart';
import 'package:forge_feed/models/animal_profile.dart';
import 'package:forge_feed/models/species_requirement.dart';
import 'package:forge_feed/services/nutrition_target_resolver.dart';

SpeciesRequirement _req(String species, {String lifeStage = 'maintenance', String id = ''}) {
  return SpeciesRequirement(
    id: id.isEmpty ? species : id,
    species: species,
    displayName: species,
    lifeStage: lifeStage,
    targetWeightKg: 1.0,
    minProteinPerc: 0,
    maxProteinPerc: 100,
    minMeKcal: 0,
    maxMeKcal: 100000,
    minCalciumPerc: 0,
    maxCalciumPerc: 100,
    minPhosphorusPerc: 0,
    maxPhosphorusPerc: 100,
    minSodiumPerc: 0,
    maxSodiumPerc: 100,
    minLysinePerc: 0,
    minMethioninePerc: 0,
  );
}

AnimalProfile _profile({required String species, String productionStage = 'Healthy / Normal'}) {
  return AnimalProfile(id: 'p1', name: 'Test', species: species, productionStage: productionStage);
}

void main() {
  group('NutritionTargetResolver.resolve', () {
    test('matches a species keyword as a whole word inside the profile species text', () {
      final catalog = [_req('hamster')];
      final result = NutritionTargetResolver.resolve(_profile(species: 'Rodent: Syrian Hamster'), catalog);
      expect(result?.species, 'hamster');
    });

    test('returns null when no catalog entry matches', () {
      final catalog = [_req('hamster')];
      final result = NutritionTargetResolver.resolve(_profile(species: 'Rodent: Chinchilla'), catalog);
      expect(result, isNull);
    });

    test('prefers the longest matching key so a specific species beats a generic one', () {
      final catalog = [_req('dog'), _req('prairie dog')];
      final result = NutritionTargetResolver.resolve(_profile(species: 'Rodent: Prairie Dog'), catalog);
      expect(result?.species, 'prairie dog');
    });

    test('breaks a tie between same-length keys using the production-stage keyword', () {
      final catalog = [
        _req('chicken', lifeStage: 'layer', id: 'chicken_layer'),
        _req('chicken', lifeStage: 'starter', id: 'chicken_starter'),
      ];
      final result = NutritionTargetResolver.resolve(
        _profile(species: 'Bird: Chicken', productionStage: 'Active Layer'),
        catalog,
      );
      expect(result?.id, 'chicken_layer');
    });

    test('falls back to the first candidate when no life-stage match exists either', () {
      final catalog = [
        _req('chicken', lifeStage: 'layer', id: 'chicken_layer'),
        _req('chicken', lifeStage: 'starter', id: 'chicken_starter'),
      ];
      final result = NutritionTargetResolver.resolve(
        _profile(species: 'Bird: Chicken', productionStage: 'Healthy / Normal'),
        catalog,
      );
      expect(result?.id, 'chicken_layer');
    });
  });

  group('NutritionTargetResolver.stageHasDedicatedData', () {
    test('true when the resolved record already matches the requested life stage', () {
      final catalog = [_req('chicken', lifeStage: 'layer', id: 'chicken_layer')];
      final hasData = NutritionTargetResolver.stageHasDedicatedData(
        _profile(species: 'Bird: Chicken', productionStage: 'Active Layer'),
        catalog,
      );
      expect(hasData, isTrue);
    });

    test('false when the resolver had to fall back to a non-matching, non-maintenance stage', () {
      final catalog = [_req('chicken', lifeStage: 'layer', id: 'chicken_layer')];
      final hasData = NutritionTargetResolver.stageHasDedicatedData(
        _profile(species: 'Bird: Chicken', productionStage: 'Working / Performance'),
        catalog,
      );
      expect(hasData, isFalse);
    });

    test('true for a plain maintenance stage even without a dedicated record', () {
      final catalog = [_req('chicken', lifeStage: 'layer', id: 'chicken_layer')];
      final hasData = NutritionTargetResolver.stageHasDedicatedData(
        _profile(species: 'Bird: Chicken', productionStage: 'Healthy / Normal'),
        catalog,
      );
      expect(hasData, isTrue);
    });
  });
}
