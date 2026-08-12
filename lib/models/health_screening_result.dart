class HealthScreeningResult {
  final bool pregnant;
  final bool breeding;
  final bool injured;
  final String injuryNotes;
  final bool hibernatingOrBrumating;

  const HealthScreeningResult({
    this.pregnant = false,
    this.breeding = false,
    this.injured = false,
    this.injuryNotes = '',
    this.hibernatingOrBrumating = false,
  });

  bool get hasAnyFlag => pregnant || breeding || injured || hibernatingOrBrumating;
}
