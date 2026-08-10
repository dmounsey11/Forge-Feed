class AnimalProfile {
  final String id;
  final String name;
  final String species;
  final int headCount;
  final String productionStage;
  final String environment;

  AnimalProfile({
    required this.id,
    required this.name,
    required this.species,
    this.headCount = 1,
    String? productionStage,
    String? stage, // Alias for backward compatibility
    this.environment = 'Outdoor',
  }) : productionStage = productionStage ?? stage ?? 'Healthy / Normal';

  // --- ALIAS GETTERS ---
  String get stage => productionStage;

  // --- DYNAMIC NUTRITIONAL TARGET CALCULATIONS FOR DIET ENGINE ---
  double get targetProteinPct {
    final s = species.toLowerCase();
    final p = productionStage.toLowerCase();

    if (s.contains('quail')) {
      if (p.contains('breeder') || p.contains('high output')) return 24.0;
      if (p.contains('growth')) return 26.0;
      return 20.0;
    }
    if (s.contains('chicken')) {
      if (p.contains('active layer') || p.contains('breeder')) return 16.5;
      if (p.contains('growth') || p.contains('molting')) return 18.0;
      return 15.0;
    }
    if (s.contains('turkey') || s.contains('waterfowl')) {
      if (p.contains('growth')) return 22.0;
      return 18.0;
    }
    if (s.contains('swine') || s.contains('pig')) {
      if (p.contains('lactating')) return 18.0;
      if (p.contains('growth')) return 16.0;
      return 14.0;
    }
    return 16.0; // Default baseline
  }

  double get targetCalciumPct {
    final s = species.toLowerCase();
    final p = productionStage.toLowerCase();

    if (s.contains('chicken') && (p.contains('layer') || p.contains('breeder'))) return 3.8;
    if (s.contains('quail') && (p.contains('breeder') || p.contains('high output'))) return 3.0;
    if (s.contains('ruminant') || s.contains('swine')) return 0.8;
    return 1.2;
  }

  double get targetPhosphorusPct {
    final s = species.toLowerCase();
    if (s.contains('quail')) return 0.45;
    if (s.contains('chicken')) return 0.40;
    return 0.35;
  }

  double get targetFatPct => species.toLowerCase().contains('quail') ? 5.0 : 3.5;
  double get targetFiberPct => species.toLowerCase().contains('ruminant') ? 16.0 : 5.0;
  double get targetEnergyMeKcalLb => species.toLowerCase().contains('quail') ? 1350 : 1300;

  factory AnimalProfile.fromJson(Map<String, dynamic> json) {
    return AnimalProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      species: json['species'] as String,
      headCount: json['headCount'] as int? ?? 1,
      productionStage: (json['productionStage'] ?? json['stage']) as String? ?? 'Healthy / Normal',
      environment: json['environment'] as String? ?? 'Outdoor',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'species': species,
      'headCount': headCount,
      'productionStage': productionStage,
      'environment': environment,
    };
  }

  AnimalProfile copyWith({
    String? id,
    String? name,
    String? species,
    int? headCount,
    String? productionStage,
    String? environment,
  }) {
    return AnimalProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      species: species ?? this.species,
      headCount: headCount ?? this.headCount,
      productionStage: productionStage ?? this.productionStage,
      environment: environment ?? this.environment,
    );
  }
}