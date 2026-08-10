import '../models/animal_profile.dart';
import '../models/species_requirement.dart';

/// Resolves the closest matching [SpeciesRequirement] for a given
/// [AnimalProfile] out of the loaded requirements catalog. Kept stateless
/// and context-free so [AnimalProfile] can stay a plain data model.
class NutritionTargetResolver {
  static SpeciesRequirement? resolve(
    AnimalProfile profile,
    List<SpeciesRequirement> catalog,
  ) {
    final speciesText = profile.species.toLowerCase();
    final candidates = catalog
        .where((r) => r.species.isNotEmpty && speciesText.contains(r.species.toLowerCase()))
        .toList();

    if (candidates.isEmpty) return null;
    if (candidates.length == 1) return candidates.first;

    final stageKeyword = _lifeStageKeyword(profile.productionStage);
    final stageMatches = candidates.where((r) => r.lifeStage == stageKeyword).toList();
    if (stageMatches.isNotEmpty) return stageMatches.first;

    return candidates.first;
  }

  static String _lifeStageKeyword(String productionStage) {
    final p = productionStage.toLowerCase();
    if (p.contains('breeder')) return 'breeder';
    if (p.contains('layer')) return 'layer';
    if (p.contains('lactating') || p.contains('nursing')) return 'lactating';
    if (p.contains('juvenile') || p.contains('growth')) return 'starter';
    if (p.contains('molting') || p.contains('recovery')) return 'maintenance';
    return 'maintenance';
  }
}
