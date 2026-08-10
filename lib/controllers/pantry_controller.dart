import 'package:flutter/foundation.dart';
import '../models/ingredient.dart';
import '../models/pantry_item.dart';
import '../models/animal_profile.dart';
import '../services/database_service.dart';

class PantryController extends ChangeNotifier {
  final List<PantryItem> pantryItems = [];
  final List<AnimalProfile> customTargets = [];

  List<Ingredient> get availableIngredients => DatabaseService.instance.ingredients;

  List<Ingredient> search(String query) {
    return DatabaseService.instance.searchIngredients(query);
  }

  void addPantryItem(Ingredient ingredient, double amount) {
    pantryItems.add(PantryItem(ingredient: ingredient, amount: amount));
    notifyListeners();
  }

  void removePantryItem(PantryItem item) {
    pantryItems.remove(item);
    notifyListeners();
  }

  void addCustomTarget(AnimalProfile target) {
    customTargets.add(target);
    notifyListeners();
  }
}