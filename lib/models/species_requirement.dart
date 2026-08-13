class SpeciesRequirement {
  final String id;
  final String species;
  final String displayName;
  final String lifeStage;
  final double targetWeightKg;
  final double minProteinPerc;
  final double maxProteinPerc;
  final double? minFatPerc;
  final double? maxFatPerc;
  final double? minFiberPerc;
  final double? maxFiberPerc;
  final double minMeKcal;
  final double maxMeKcal;
  final double minCalciumPerc;
  final double maxCalciumPerc;
  final double minPhosphorusPerc;
  final double maxPhosphorusPerc;
  final double minSodiumPerc;
  final double maxSodiumPerc;
  final double minLysinePerc;
  final double minMethioninePerc;
  final double minTaurinePerc;
  final double minNiacinMgKg;
  final String notes;

  SpeciesRequirement({
    required this.id,
    required this.species,
    required this.displayName,
    required this.lifeStage,
    required this.targetWeightKg,
    required this.minProteinPerc,
    required this.maxProteinPerc,
    this.minFatPerc,
    this.maxFatPerc,
    this.minFiberPerc,
    this.maxFiberPerc,
    required this.minMeKcal,
    required this.maxMeKcal,
    required this.minCalciumPerc,
    required this.maxCalciumPerc,
    required this.minPhosphorusPerc,
    required this.maxPhosphorusPerc,
    required this.minSodiumPerc,
    required this.maxSodiumPerc,
    required this.minLysinePerc,
    required this.minMethioninePerc,
    this.minTaurinePerc = 0.0,
    this.minNiacinMgKg = 0.0,
    this.notes = '',
  });

  factory SpeciesRequirement.fromJson(Map<String, dynamic> json) {
    return SpeciesRequirement(
      id: json['id'] as String? ?? '',
      species: json['species'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      lifeStage: json['lifeStage'] as String? ?? '',
      targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble() ?? 0.0,
      minProteinPerc: (json['minProteinPerc'] as num?)?.toDouble() ?? 0.0,
      maxProteinPerc: (json['maxProteinPerc'] as num?)?.toDouble() ?? 0.0,
      minFatPerc: (json['minFatPerc'] as num?)?.toDouble(),
      maxFatPerc: (json['maxFatPerc'] as num?)?.toDouble(),
      minFiberPerc: (json['minFiberPerc'] as num?)?.toDouble(),
      maxFiberPerc: (json['maxFiberPerc'] as num?)?.toDouble(),
      minMeKcal: (json['minMeKcal'] as num?)?.toDouble() ?? 0.0,
      maxMeKcal: (json['maxMeKcal'] as num?)?.toDouble() ?? 0.0,
      minCalciumPerc: (json['minCalciumPerc'] as num?)?.toDouble() ?? 0.0,
      maxCalciumPerc: (json['maxCalciumPerc'] as num?)?.toDouble() ?? 0.0,
      minPhosphorusPerc: (json['minPhosphorusPerc'] as num?)?.toDouble() ?? 0.0,
      maxPhosphorusPerc: (json['maxPhosphorusPerc'] as num?)?.toDouble() ?? 0.0,
      minSodiumPerc: (json['minSodiumPerc'] as num?)?.toDouble() ?? 0.0,
      maxSodiumPerc: (json['maxSodiumPerc'] as num?)?.toDouble() ?? 0.0,
      minLysinePerc: (json['minLysinePerc'] as num?)?.toDouble() ?? 0.0,
      minMethioninePerc: (json['minMethioninePerc'] as num?)?.toDouble() ?? 0.0,
      minTaurinePerc: (json['minTaurinePerc'] as num?)?.toDouble() ?? 0.0,
      minNiacinMgKg: (json['minNiacinMgKg'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String? ?? '',
    );
  }
}
