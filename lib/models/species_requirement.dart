class SpeciesRequirement {
  final String id;
  final String name;
  final String category;
  final double minCrudeProtein;
  final double minMetabolizableEnergy;
  final double minCalcium;
  final double minPhosphorus;

  SpeciesRequirement({
    required this.id,
    required this.name,
    required this.category,
    required this.minCrudeProtein,
    required this.minMetabolizableEnergy,
    required this.minCalcium,
    required this.minPhosphorus,
  });

  factory SpeciesRequirement.fromJson(Map<String, dynamic> json) {
    return SpeciesRequirement(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? 'General',
      minCrudeProtein: (json['minCrudeProtein'] ?? 0).toDouble(),
      minMetabolizableEnergy: (json['minMetabolizableEnergy'] ?? 0).toDouble(),
      minCalcium: (json['minCalcium'] ?? 0).toDouble(),
      minPhosphorus: (json['minPhosphorus'] ?? 0).toDouble(),
    );
  }
}