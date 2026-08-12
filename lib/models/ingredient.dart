class AsFedMetrics {
  final double crudeProteinPct;
  final double calciumPct;
  final double phosphorusPct;
  final double fatPct;
  final double fiberPct;
  final double energyKcalLb;
  final double sodiumPct;
  final double lysinePct;
  final double methioninePct;
  final double taurinePct;
  final double niacinMgKg;
  final double copperPpm;
  final double molybdenumPpm;
  final double oxalatePct;
  /// % dry matter (100 - moisture %). Null means unknown - callers treat
  /// that as 100% (fully dry) rather than guessing, so an un-populated item
  /// doesn't distort a blend's dry-matter-basis calculations.
  final double? dryMatterPct;

  AsFedMetrics({
    this.crudeProteinPct = 0.0,
    this.calciumPct = 0.0,
    this.phosphorusPct = 0.0,
    this.fatPct = 0.0,
    this.fiberPct = 0.0,
    this.energyKcalLb = 0.0,
    this.sodiumPct = 0.0,
    this.lysinePct = 0.0,
    this.methioninePct = 0.0,
    this.taurinePct = 0.0,
    this.niacinMgKg = 0.0,
    this.copperPpm = 0.0,
    this.molybdenumPpm = 0.0,
    this.oxalatePct = 0.0,
    this.dryMatterPct,
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
        'sodiumPct': sodiumPct,
        'lysinePct': lysinePct,
        'methioninePct': methioninePct,
        'taurinePct': taurinePct,
        'niacinMgKg': niacinMgKg,
        'copperPpm': copperPpm,
        'molybdenumPpm': molybdenumPpm,
        'oxalatePct': oxalatePct,
        if (dryMatterPct != null) 'dryMatterPct': dryMatterPct,
      };

  factory AsFedMetrics.fromJson(Map<String, dynamic> json) => AsFedMetrics(
        crudeProteinPct: (json['crudeProteinPct'] as num?)?.toDouble() ?? 0.0,
        calciumPct: (json['calciumPct'] as num?)?.toDouble() ?? 0.0,
        phosphorusPct: (json['phosphorusPct'] as num?)?.toDouble() ?? 0.0,
        fatPct: (json['fatPct'] as num?)?.toDouble() ?? (json['crudeFatPct'] as num?)?.toDouble() ?? 0.0,
        fiberPct: (json['fiberPct'] as num?)?.toDouble() ?? (json['crudeFiberPct'] as num?)?.toDouble() ?? 0.0,
        energyKcalLb: (json['energyKcalLb'] as num?)?.toDouble() ?? (json['metabolicEnergyKcal'] as num?)?.toDouble() ?? 0.0,
        sodiumPct: (json['sodiumPct'] as num?)?.toDouble() ?? 0.0,
        lysinePct: (json['lysinePct'] as num?)?.toDouble() ?? 0.0,
        methioninePct: (json['methioninePct'] as num?)?.toDouble() ?? 0.0,
        taurinePct: (json['taurinePct'] as num?)?.toDouble() ?? 0.0,
        niacinMgKg: (json['niacinMgKg'] as num?)?.toDouble() ?? 0.0,
        copperPpm: (json['copperPpm'] as num?)?.toDouble() ?? 0.0,
        molybdenumPpm: (json['molybdenumPpm'] as num?)?.toDouble() ?? 0.0,
        oxalatePct: (json['oxalatePct'] as num?)?.toDouble() ?? 0.0,
        // Some source files (livestock_feeds.json, pet_kibble.json,
        // usda_ingredients.json) publish moisture % instead of dry matter %
        // directly - derive DM from it when dryMatterPct itself isn't given.
        dryMatterPct: (json['dryMatterPct'] as num?)?.toDouble() ??
            ((json['moisturePct'] as num?) != null ? 100.0 - (json['moisturePct'] as num).toDouble() : null),
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
    double? dryMatterPct,
  }) : asFedMetrics = asFedMetrics ??
            AsFedMetrics(
              crudeProteinPct: proteinPct ?? 0.0,
              calciumPct: calciumPctValue ?? 0.0,
              phosphorusPct: phosphorusPctValue ?? 0.0,
              fatPct: crudeFatPct ?? fatPctValue ?? 0.0,
              fiberPct: crudeFiberPct ?? fiberPctValue ?? 0.0,
              energyKcalLb: energyMeKcalLb ?? 0.0,
              dryMatterPct: dryMatterPct,
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

  /// Maps a raw record from the USDA SR-Legacy derived `ingredients.json`
  /// (flat schema: crudeProteinPerc, calciumPerc, totalPhosphorusPerc, etc.,
  /// with metabolizableEnergyKcal expressed per kg) onto this app's model.
  factory Ingredient.fromUsdaJson(Map<String, dynamic> json, {String? categoryOverride}) {
    double n(String key) => (json[key] as num?)?.toDouble() ?? 0.0;
    const kgToLb = 2.20462;
    final dryMatterPerc = (json['dryMatterPerc'] as num?)?.toDouble();
    return Ingredient(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: categoryOverride ?? json['category']?.toString() ?? 'General',
      catalogSource: 'USDA',
      subCategory: json['storageForm']?.toString() ?? 'General',
      asFedMetrics: AsFedMetrics(
        crudeProteinPct: n('crudeProteinPerc'),
        calciumPct: n('calciumPerc'),
        phosphorusPct: n('totalPhosphorusPerc'),
        fatPct: n('crudeFatPerc'),
        fiberPct: n('crudeFiberPerc'),
        energyKcalLb: n('metabolizableEnergyKcal') / kgToLb,
        sodiumPct: n('sodiumPerc'),
        lysinePct: n('lysinePerc'),
        methioninePct: n('methioninePerc'),
        taurinePct: n('taurinePerc'),
        niacinMgKg: n('niacinMgKg'),
        dryMatterPct: dryMatterPerc,
      ),
    );
  }
}