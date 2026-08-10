import 'dart:convert';
import 'dart:io';

void main() async {
  print('Building master ForgeFeed database file...');

  List<Map<String, dynamic>> masterIngredients = [];
  List<Map<String, dynamic>> masterSpecies = [];

  // 1. Load Scraped Livestock & Pets
  final livestockFile = File('assets/scraped_species_seed.json');
  if (await livestockFile.exists()) {
    final List<dynamic> data = jsonDecode(await livestockFile.readAsString());
    for (var item in data) {
      masterSpecies.add({
        'id': item['id'],
        'speciesName': item['name'],
        'category': item['category'] ?? 'Livestock',
        'description': item['description'] ?? '',
        'crudeProteinPct': item['requirements']?['crudeProtein'] ?? 16.0,
        'crudeFatPct': item['requirements']?['crudeFat'] ?? 4.0,
        'crudeFiberPct': item['requirements']?['crudeFiber'] ?? 10.0,
        'calciumPct': item['requirements']?['calcium'] ?? 1.0,
        'phosphorusPct': item['requirements']?['phosphorus'] ?? 0.5,
      });
    }
    print('Merged ${masterSpecies.length} livestock/pet species.');
  }

  // 2. Load Scraped Exotic Reptiles, Amphibians, Mammals & Rodents
  final exoticsFile = File('assets/scraped_exotics_seed.json');
  if (await exoticsFile.exists()) {
    final List<dynamic> exoticsData = jsonDecode(await exoticsFile.readAsString());
    int count = 0;
    for (var item in exoticsData) {
      masterSpecies.add({
        'id': item['id'],
        'speciesName': item['name'],
        'category': item['category'] ?? 'Exotics',
        'description': item['description'] ?? '',
        'crudeProteinPct': item['requirements']?['crudeProtein'] ?? 18.0,
        'crudeFatPct': item['requirements']?['crudeFat'] ?? 5.0,
        'crudeFiberPct': item['requirements']?['crudeFiber'] ?? 8.0,
        'calciumPct': item['requirements']?['calcium'] ?? 1.0,
        'phosphorusPct': item['requirements']?['phosphorus'] ?? 0.5,
      });
      count++;
    }
    print('Merged $count exotic species.');
  }

  // 3. Compile Master Output
  final masterData = {
    'version': '1.1.0',
    'lastUpdated': DateTime.now().toIso8601String(),
    'ingredients': masterIngredients,
    'speciesRequirements': masterSpecies,
  };

  final outputFile = File('assets/data/forge_feed_data.json');
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsString(const JsonEncoder.withIndent('  ').convert(masterData));

  print('\nMASTER DATABASE COMPILED SUCCESSFULLY!');
  print('Total Master Species: ${masterSpecies.length}');
  print('Saved to: ${outputFile.path}');
}