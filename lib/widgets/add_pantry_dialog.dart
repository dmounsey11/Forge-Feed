import 'package:flutter/material.dart';
import '../models/ingredient.dart';
import '../services/database_service.dart';

class AddPantryDialog extends StatefulWidget {
  final Function(Ingredient, double) onAdd;

  const AddPantryDialog({super.key, required this.onAdd});

  @override
  State<AddPantryDialog> createState() => _AddPantryDialogState();
}

class _AddPantryDialogState extends State<AddPantryDialog> {
  Ingredient? _selectedIngredient;
  final TextEditingController _amountController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final ingredients = DatabaseService.instance.ingredients;

    return AlertDialog(
      title: const Text('Add to Pantry'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Ingredient>(
              initialValue: _selectedIngredient,
              decoration: const InputDecoration(labelText: 'Select Ingredient'),
              items: ingredients.map((ing) {
                return DropdownMenuItem(
                  value: ing,
                  child: Text(ing.name, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedIngredient = val),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount (lbs)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_selectedIngredient != null && _amountController.text.isNotEmpty) {
              final amount = double.tryParse(_amountController.text) ?? 0.0;
              widget.onAdd(_selectedIngredient!, amount);
              Navigator.pop(context);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}