class SpeciesSubgroup {
  final String name;
  final List<String> species;

  const SpeciesSubgroup({required this.name, required this.species});

  factory SpeciesSubgroup.fromJson(Map<String, dynamic> json) {
    return SpeciesSubgroup(
      name: json['name'] as String? ?? '',
      species: (json['species'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    );
  }
}

class SpeciesCategory {
  final String name;
  final List<SpeciesSubgroup> subgroups;

  const SpeciesCategory({required this.name, required this.subgroups});

  factory SpeciesCategory.fromJson(Map<String, dynamic> json) {
    return SpeciesCategory(
      name: json['name'] as String? ?? '',
      subgroups: (json['subgroups'] as List<dynamic>? ?? [])
          .map((e) => SpeciesSubgroup.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
