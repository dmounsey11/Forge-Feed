class AnimalProfile {
  final String id;
  final String name;
  final String species;
  final int headCount;
  final String productionStage;
  final String environment;
  final String sex;
  final String ageGroup;

  AnimalProfile({
    required this.id,
    required this.name,
    required this.species,
    this.headCount = 1,
    String? productionStage,
    String? stage, // Alias for backward compatibility
    this.environment = 'Outdoor',
    this.sex = 'Unknown',
    this.ageGroup = 'Adult',
  }) : productionStage = productionStage ?? stage ?? 'Healthy / Normal';

  // --- ALIAS GETTERS ---
  String get stage => productionStage;

  factory AnimalProfile.fromJson(Map<String, dynamic> json) {
    return AnimalProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      species: json['species'] as String,
      headCount: json['headCount'] as int? ?? 1,
      productionStage: (json['productionStage'] ?? json['stage']) as String? ?? 'Healthy / Normal',
      environment: json['environment'] as String? ?? 'Outdoor',
      sex: json['sex'] as String? ?? 'Unknown',
      ageGroup: json['ageGroup'] as String? ?? 'Adult',
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
      'sex': sex,
      'ageGroup': ageGroup,
    };
  }

  AnimalProfile copyWith({
    String? id,
    String? name,
    String? species,
    int? headCount,
    String? productionStage,
    String? environment,
    String? sex,
    String? ageGroup,
  }) {
    return AnimalProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      species: species ?? this.species,
      headCount: headCount ?? this.headCount,
      productionStage: productionStage ?? this.productionStage,
      environment: environment ?? this.environment,
      sex: sex ?? this.sex,
      ageGroup: ageGroup ?? this.ageGroup,
    );
  }
}
