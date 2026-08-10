import 'package:flutter/material.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            indicatorColor: Colors.greenAccent,
            labelColor: Colors.greenAccent,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.battery_charging_full), text: 'Body Battery'),
              Tab(icon: Icon(Icons.science), text: 'Vitamins & Minerals'),
              Tab(icon: Icon(Icons.health_and_safety), text: 'Symptom Matrix'),
              Tab(icon: Icon(Icons.menu_book), text: 'Ingredients'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildBodyBatteryTab(),
                _buildNutrientsTab(),
                _buildSymptomsTab(),
                _buildIngredientsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 1. BODY BATTERY TAB
  Widget _buildBodyBatteryTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Card(
          color: Colors.black45,
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The "Body Battery" & "Clock Speed" Concept',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                ),
                SizedBox(height: 8),
                Text(
                  'Livestock metabolisms function like a battery grid driven by biological "clock speeds". '
                  'Different nutrients deplete at vastly different rates during stress, production, or environmental shift.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildBatteryCard(
          'High Clock Speed (Hours)',
          'Electrolytes & Hydration',
          'Depletes rapidly in heat stress or sudden output. Must be replenished immediately before cellular damage occurs.',
          Colors.redAccent,
          Icons.flash_on,
        ),
        _buildBatteryCard(
          'Medium Clock Speed (Days / Weeks)',
          'Water-Soluble Vitamins & Protein',
          'Vitamins B & C are not heavily stored in tissues. Deficiencies show quickly in feathering, energy, and egg production.',
          Colors.orangeAccent,
          Icons.timer,
        ),
        _buildBatteryCard(
          'Slow Clock Speed (Months)',
          'Fat-Soluble Vitamins & Bone Minerals',
          'Calcium, Phosphorus, Vitamins A, D, E, K. Stored in bone structure and fatty tissue; takes longer to drain, but recovery takes months.',
          Colors.blueAccent,
          Icons.battery_saver,
        ),
      ],
    );
  }

  Widget _buildBatteryCard(String clockSpeed, String title, String desc, Color color, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Depletion Rate: $clockSpeed', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  // 2. VITAMINS & MINERALS TAB
  Widget _buildNutrientsTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildNutrientTile('Vitamin A', 'Mucous Membranes & Vision', 'Deficiency leads to eye discharge, respiratory vulnerability, and dropped production.'),
        _buildNutrientTile('Vitamin D3', 'Calcium Absorption', 'Critical for eggshell strength and skeletal integrity. Synthetic or direct sunlight exposure required.'),
        _buildNutrientTile('Vitamin E & Selenium', 'Muscle & Nerve Function', 'Prevents Wry Neck and Encephalomalacia. Crucial antioxidant pair.'),
        _buildNutrientTile('Calcium (Ca)', 'Eggshell & Bone Health', 'High demand during active laying. Must be paired with D3 and proper Phosphorus ratio (~2:1 to 4:1).'),
        _buildNutrientTile('Manganese (Mn)', 'Tendon & Bone Structure', 'Deficiency causes slipped tendon (perosis) in rapidly growing birds.'),
      ],
    );
  }

  Widget _buildNutrientTile(String name, String role, String notes) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Role: $role', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 2),
            Text(notes, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // 3. SYMPTOM MATRIX TAB
  Widget _buildSymptomsTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildSymptomCard('Soft / Thin Eggshells', 'Calcium / Vitamin D3 Deficiency', 'Provide free-choice coarse limestone or oyster shell. Ensure adequate D3 supplementation.'),
        _buildSymptomCard('Wry Neck (Star Gazing)', 'Vitamin E / Selenium Deficiency', 'Supplement Vitamin E and Selenium immediately in water or direct liquid dose.'),
        _buildSymptomCard('Slipped Tendon (Perosis)', 'Manganese or B-Vitamin Deficiency', 'Ensure chick starter has balanced trace mineral pack; difficult to reverse once joint deforms.'),
        _buildSymptomCard('Feather Pecking / Cannibalism', 'Protein or Methionine Shortage', 'Increase overall crude protein % or check dietary amino acid profile (lysine/methionine).'),
      ],
    );
  }

  Widget _buildSymptomCard(String symptom, String cause, String fix) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        leading: const Icon(Icons.warning_amber_rounded, color: Colors.amber),
        title: Text(symptom, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Possible Cause: $cause', style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.build_circle_outlined, color: Colors.greenAccent),
                const SizedBox(width: 10),
                Expanded(child: Text('Corrective Action: $fix', style: const TextStyle(color: Colors.white70))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4. INGREDIENT ENCYCLOPEDIA TAB
  Widget _buildIngredientsTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildIngredientInfo('Yellow Corn', 'Energy Feed', '8.5% Protein', 'High energy carbohydrate source. Low in Lysine and Methionine.'),
        _buildIngredientInfo('Soybean Meal (48%)', 'Protein Feed', '48.0% Protein', 'Standard plant protein. High Lysine, ideal base balance.'),
        _buildIngredientInfo('Black Soldier Fly Larvae', 'Protein & Fat Feed', '40.0% Protein', 'Rich in natural fats, protein, and high bioavailable calcium.'),
        _buildIngredientInfo('Limestone / Oyster Shell', 'Mineral Supplement', '0% Protein (38% Ca)', 'Primary source of coarse-particle calcium for persistent eggshell synthesis.'),
        _buildIngredientInfo('Alfalfa Meal', 'Forage / Fiber', '17.0% Protein', 'Provides natural carotenoids for yolk color and digestive fiber.'),
      ],
    );
  }

  Widget _buildIngredientInfo(String name, String type, String protein, String desc) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Chip(
              label: Text(protein, style: const TextStyle(fontSize: 10, color: Colors.white)),
              backgroundColor: Colors.green.shade800,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category: $type', style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}