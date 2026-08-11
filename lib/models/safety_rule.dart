/// A real inclusion-limit / ratio-limit rule from assets/data/safety_rules.json,
/// e.g. "salt over 0.5% of the batch is dangerous."
class SafetyRule {
  final String ruleId;
  final String targetType; // 'ingredient_category' | 'ingredient_keyword' | 'ratio'
  final String targetName;
  final double? maxInclusionPerc;
  final double? minRatio;
  final double? maxRatio;
  final String severity;
  final String warningMessage;

  SafetyRule({
    required this.ruleId,
    required this.targetType,
    required this.targetName,
    this.maxInclusionPerc,
    this.minRatio,
    this.maxRatio,
    required this.severity,
    required this.warningMessage,
  });

  factory SafetyRule.fromJson(Map<String, dynamic> json) {
    return SafetyRule(
      ruleId: json['ruleId'] as String? ?? '',
      targetType: json['targetType'] as String? ?? '',
      targetName: json['targetName'] as String? ?? '',
      maxInclusionPerc: (json['maxInclusionPerc'] as num?)?.toDouble(),
      minRatio: (json['minRatio'] as num?)?.toDouble(),
      maxRatio: (json['maxRatio'] as num?)?.toDouble(),
      severity: json['severity'] as String? ?? 'LOW',
      warningMessage: json['warningMessage'] as String? ?? '',
    );
  }
}
