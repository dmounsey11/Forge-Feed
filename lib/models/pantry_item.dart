import 'ingredient.dart';

class PantryItem {
  final String id;
  final Ingredient ingredient;
  final double quantityLbs;

  PantryItem({
    String? id,
    required this.ingredient,
    double? quantityLbs,
    double? amount,
    double? weight,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        quantityLbs = quantityLbs ?? amount ?? weight ?? 0.0;

  // Legacy & convenience getters
  double get weight => quantityLbs;
  double get amount => quantityLbs;
  String get ingredientName => ingredient.name;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ingredient': ingredient.toJson(),
        'quantityLbs': quantityLbs,
      };

  factory PantryItem.fromJson(Map<String, dynamic> json) => PantryItem(
        id: json['id']?.toString(),
        ingredient: json['ingredient'] != null
            ? Ingredient.fromJson(json['ingredient'])
            : Ingredient(
                id: '',
                name: json['ingredientName'] ?? 'Unknown Ingredient',
                category: 'General',
                proteinPct: 0,
                calciumPctValue: 0,
                phosphorusPctValue: 0,
                fatPctValue: 0,
                fiberPctValue: 0,
                energyMeKcalLb: 0,
              ),
        quantityLbs: (json['quantityLbs'] ?? json['amount'] ?? json['weight'] as num?)?.toDouble() ?? 0.0,
      );
}