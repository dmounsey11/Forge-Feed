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