/// A real inclusion-limit / ratio-limit rule from assets/data/safety_rules.json,
/// e.g. "salt over 0.5% of the batch is dangerous."
class SafetyRule {
  final String ruleId;
  final String targetType; // 'ingredient_category' | 'ingredient_keyword' | 'ratio'
  final String targetName;
  final double? maxInclusionPerc;
  final double? minRatio;
  final double? maxRatio;
  /// Absolute min/max for a single dry-matter-basis concentration check
  /// (targetType 'dm_concentration') - unlike minRatio/maxRatio, this isn't
  /// comparing two nutrients against each other, just one value against a
  /// fixed safe limit (e.g. "Copper must stay under 10 ppm DM for sheep").
  final double? minValue;
  final double? maxValue;
  final String severity;
  final String warningMessage;
  /// Species keywords (matched the same way [NutritionTargetResolver] matches
  /// a profile's species text) this rule is restricted to. Empty means it
  /// applies to every species - e.g. the salt/gossypol caps below.
  final List<String> appliesToSpecies;

  SafetyRule({
    required this.ruleId,
    required this.targetType,
    required this.targetName,
    this.maxInclusionPerc,
    this.minRatio,
    this.maxRatio,
    this.minValue,
    this.maxValue,
    required this.severity,
    required this.warningMessage,
    this.appliesToSpecies = const [],
  });

  factory SafetyRule.fromJson(Map<String, dynamic> json) {
    return SafetyRule(
      ruleId: json['ruleId'] as String? ?? '',
      targetType: json['targetType'] as String? ?? '',
      targetName: json['targetName'] as String? ?? '',
      maxInclusionPerc: (json['maxInclusionPerc'] as num?)?.toDouble(),
      minRatio: (json['minRatio'] as num?)?.toDouble(),
      maxRatio: (json['maxRatio'] as num?)?.toDouble(),
      minValue: (json['minValue'] as num?)?.toDouble(),
      maxValue: (json['maxValue'] as num?)?.toDouble(),
      severity: json['severity'] as String? ?? 'LOW',
      warningMessage: json['warningMessage'] as String? ?? '',
      appliesToSpecies: (json['appliesToSpecies'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    );
  }
}
