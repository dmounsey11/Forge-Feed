// One-off Phase 6 helper: scans assets/data/ingredients.json for
// whole-food-looking USDA records not already in database_service.dart's
// curated allow-list, so they can be hand-reviewed before adding. Not part
// of the app - run with `dart run tool/find_ingredient_candidates.dart`.
import 'dart:convert';
import 'dart:io';

const _excludeKeywords = [
  'cooked',
  'canned',
  'fried',
  'candy',
  'cookie',
  'cake',
  'pie,',
  'sauce',
  'syrup',
  'juice',
  'chips',
  'cereal',
  'biscuit',
  'cracker',
  'pizza',
  'burger',
  'sandwich',
  'soup',
  'dressing',
  'sausage',
  'hot dog',
  'bacon',
  'spread',
  'beverage',
  'restaurant',
  'fast food',
  'frozen meal',
  'dinner',
  'baby food',
  'infant formula',
  'imitation',
  'dessert',
  'pudding',
  'ice cream',
  'chocolate',
  'beer',
  'wine',
  'liquor',
  'coffee',
  'tea,',
  'soft drink',
  'snack',
  'formulated bar',
  'nutritional supplement, ready-to-drink',
];

void main() async {
  final raw = await File('assets/data/ingredients.json').readAsString();
  final List<dynamic> records = jsonDecode(raw) as List<dynamic>;

  final alreadyCurated = await _existingCuratedIds();

  final candidates = <Map<String, dynamic>>[];
  for (final r in records) {
    final rec = r as Map<String, dynamic>;
    final id = rec['id'] as String;
    if (alreadyCurated.contains(id)) continue;
    final name = (rec['name'] as String).toLowerCase();
    // USDA SR-Legacy's naming convention marks genuine unprocessed
    // ingredients with ", raw" (or "raw," mid-string) - this is a far
    // stronger, cleaner signal than trying to blacklist the essentially
    // unbounded space of branded/prepared/dessert names, which slip
    // through a keyword blacklist constantly (candy, pastry, bread,
    // frankfurter, sherbet, ...).
    if (!name.contains(', raw') && !name.contains('raw,') && !name.endsWith(', raw')) continue;
    if (_excludeKeywords.any((kw) => name.contains(kw))) continue;
    // Multi-ingredient/branded dish names still slip past ", raw" (e.g. a
    // "raw" garnish inside a composed product name) - cap comma count as a
    // secondary filter against those.
    final commaCount = ','.allMatches(name).length;
    if (commaCount > 3) continue;
    final proteinPerc = (rec['crudeProteinPerc'] as num?)?.toDouble() ?? 0;
    final category = rec['category'] as String? ?? '';
    candidates.add({'id': id, 'name': rec['name'], 'category': category, 'protein': proteinPerc});
  }

  candidates.sort((a, b) => (a['category'] as String).compareTo(b['category'] as String));

  final byCategory = <String, List<Map<String, dynamic>>>{};
  for (final c in candidates) {
    byCategory.putIfAbsent(c['category'] as String, () => []).add(c);
  }

  for (final entry in byCategory.entries) {
    stdout.writeln('=== ${entry.key} (${entry.value.length}) ===');
    for (final c in entry.value) {
      stdout.writeln('  ${c['id']}: ${c['name']}');
    }
  }
  stdout.writeln('\nTotal candidates after filtering: ${candidates.length}');
}

Future<Set<String>> _existingCuratedIds() async {
  final src = await File('lib/services/database_service.dart').readAsString();
  final pattern = RegExp(r"'(ing_\d+)':");
  return pattern.allMatches(src).map((m) => m.group(1)!).toSet();
}
