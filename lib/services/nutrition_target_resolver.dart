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
    final matches = catalog
        .where((r) => r.species.isNotEmpty && _matchesWholeWord(speciesText, r.species.toLowerCase()))
        .toList();

    if (matches.isEmpty) return null;

    // Prefer the most specific match (e.g. "prairie dog" beats "dog") so a
    // short, generic key doesn't shadow a more precise one for the same animal.
    final maxKeyLength = matches.map((r) => r.species.length).reduce((a, b) => a > b ? a : b);
    final candidates = matches.where((r) => r.species.length == maxKeyLength).toList();

    if (candidates.length == 1) return candidates.first;

    final stageKeyword = _lifeStageKeyword(profile.productionStage);
    final stageMatches = candidates.where((r) => r.lifeStage == stageKeyword).toList();
    if (stageMatches.isNotEmpty) return stageMatches.first;

    return candidates.first;
  }

  /// True if [key] appears in [text] as a whole word (or phrase), not as an
  /// incidental substring - e.g. "cat" must not match inside "Cattle" or
  /// "Sulcata".
  static bool _matchesWholeWord(String text, String key) {
    final pattern = RegExp('(?:^|[^a-z])${RegExp.escape(key)}(?:\$|[^a-z])');
    return pattern.hasMatch(text);
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
