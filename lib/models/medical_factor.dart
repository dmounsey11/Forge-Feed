class MedicalFactor {
  final String conditionId;
  final String category;
  final String conditionName;
  final String affectedSpecies;
  final double proteinMultiplier;
  final double energyMultiplier;
  final double calciumMultiplier;
  final String criticalNutrientFocus;
  final String description;

  MedicalFactor({
    required this.conditionId,
    required this.category,
    required this.conditionName,
    required this.affectedSpecies,
    required this.proteinMultiplier,
    required this.energyMultiplier,
    required this.calciumMultiplier,
    required this.criticalNutrientFocus,
    required this.description,
  });

  factory MedicalFactor.fromJson(Map<String, dynamic> json) {
    return MedicalFactor(
      conditionId: json['conditionId'] as String? ?? '',
      category: json['category'] as String? ?? '',
      conditionName: json['conditionName'] as String? ?? '',
      affectedSpecies: json['affectedSpecies'] as String? ?? '',
      proteinMultiplier: (json['proteinMultiplier'] as num?)?.toDouble() ?? 1.0,
      energyMultiplier: (json['energyMultiplier'] as num?)?.toDouble() ?? 1.0,
      calciumMultiplier: (json['calciumMultiplier'] as num?)?.toDouble() ?? 1.0,
      criticalNutrientFocus: json['criticalNutrientFocus'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conditionId': conditionId,
      'category': category,
      'conditionName': conditionName,
      'affectedSpecies': affectedSpecies,
      'proteinMultiplier': proteinMultiplier,
      'energyMultiplier': energyMultiplier,
      'calciumMultiplier': calciumMultiplier,
      'criticalNutrientFocus': criticalNutrientFocus,
      'description': description,
    };
  }
}