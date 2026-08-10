class AsFedMetrics {
  final double crudeProteinPct;
  final double calciumPct;
  final double phosphorusPct;
  final double fatPct;
  final double fiberPct;
  final double energyKcalLb;

  AsFedMetrics({
    this.crudeProteinPct = 0.0,
    this.calciumPct = 0.0,
    this.phosphorusPct = 0.0,
    this.fatPct = 0.0,
    this.fiberPct = 0.0,
    this.energyKcalLb = 0.0,
  });

  // Expected getters in logic files
  double get crudeFatPct => fatPct;
  double get crudeFiberPct => fiberPct;
  double get metabolicEnergyKcal => energyKcalLb;

  Map<String, dynamic> toJson() => {
        'crudeProteinPct': crudeProteinPct,
        'calciumPct': calciumPct,
        'phosphorusPct': phosphorusPct,
        'fatPct': fatPct,
        'fiberPct': fiberPct,
        'energyKcalLb': energyKcalLb,
      };

  factory AsFedMetrics.fromJson(Map<String, dynamic> json) => AsFedMetrics(
        crudeProteinPct: (json['crudeProteinPct'] as num?)?.toDouble() ?? 0.0,
        calciumPct: (json['calciumPct'] as num?)?.toDouble() ?? 0.0,
        phosphorusPct: (json['phosphorusPct'] as num?)?.toDouble() ?? 0.0,
        fatPct: (json['fatPct'] as num?)?.toDouble() ?? (json['crudeFatPct'] as num?)?.toDouble() ?? 0.0,
        fiberPct: (json['fiberPct'] as num?)?.toDouble() ?? (json['crudeFiberPct'] as num?)?.toDouble() ?? 0.0,
        energyKcalLb: (json['energyKcalLb'] as num?)?.toDouble() ?? (json['metabolicEnergyKcal'] as num?)?.toDouble() ?? 0.0,
      );
}

class Ingredient {
  final String id;
  final String name;
  final String brand;
  final String category;
  final String catalogSource;
  final String subCategory;
  final AsFedMetrics asFedMetrics;

  Ingredient({
    required this.id,
    required this.name,
    this.brand = 'Generic',
    this.category = 'General',
    this.catalogSource = 'User',
    this.subCategory = 'General',
    AsFedMetrics? asFedMetrics,
    double? proteinPct,
    double? calciumPctValue,
    double? phosphorusPctValue,
    double? fatPctValue,
    double? fiberPctValue,
    double? crudeFatPct,
    double? crudeFiberPct,
    double? energyMeKcalLb,
  }) : asFedMetrics = asFedMetrics ??
            AsFedMetrics(
              crudeProteinPct: proteinPct ?? 0.0,
              calciumPct: calciumPctValue ?? 0.0,
              phosphorusPct: phosphorusPctValue ?? 0.0,
              fatPct: crudeFatPct ?? fatPctValue ?? 0.0,
              fiberPct: crudeFiberPct ?? fiberPctValue ?? 0.0,
              energyKcalLb: energyMeKcalLb ?? 0.0,
            );

  // Convenience getters
  double get calciumPctValue => asFedMetrics.calciumPct;
  double get phosphorusPctValue => asFedMetrics.phosphorusPct;
  double get proteinPct => asFedMetrics.crudeProteinPct;
  double get fatPctValue => asFedMetrics.fatPct;
  double get fiberPctValue => asFedMetrics.fiberPct;
  double get energyMeKcalLb => asFedMetrics.energyKcalLb;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'brand': brand,
        'category': category,
        'catalogSource': catalogSource,
        'subCategory': subCategory,
        'asFedMetrics': asFedMetrics.toJson(),
      };

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        brand: json['brand']?.toString() ?? 'Generic',
        category: json['category']?.toString() ?? 'General',
        catalogSource: json['catalogSource']?.toString() ?? 'User',
        subCategory: json['subCategory']?.toString() ?? 'General',
        asFedMetrics: json['asFedMetrics'] != null
            ? AsFedMetrics.fromJson(json['asFedMetrics'])
            : AsFedMetrics(),
      );
}