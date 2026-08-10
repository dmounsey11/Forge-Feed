import 'package:flutter/material.dart';
import '../services/database_service.dart';

class SavedRationsScreen extends StatefulWidget {
  const SavedRationsScreen({super.key});

  @override
  State<SavedRationsScreen> createState() => _SavedRationsScreenState();
}

class _SavedRationsScreenState extends State<SavedRationsScreen> {
  @override
  Widget build(BuildContext context) {
    final pantryIds = DatabaseService.instance.pantryIds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Rations'),
      ),
      body: pantryIds.isEmpty
          ? const Center(child: Text('No saved rations yet.'))
          : ListView.builder(
              itemCount: pantryIds.length,
              itemBuilder: (context, index) {
                final id = pantryIds.elementAt(index);
                return ListTile(
                  title: Text('Saved Item ID: $id'),
                );
              },
            ),
    );
  }
}