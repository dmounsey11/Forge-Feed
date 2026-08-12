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
            indicatorColor: Color(0xFFF97316),
            labelColor: Color(0xFFF97316),
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.battery_charging_full), text: 'Body Battery'),
              Tab(icon: Icon(Icons.science), text: 'Vitamins & Minerals'),
              Tab(icon: Icon(Icons.menu_book), text: 'Ingredients'),
              Tab(icon: Icon(Icons.kitchen), text: 'Kitchen Tools'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildBodyBatteryTab(),
                _buildNutrientsTab(),
                _buildIngredientsTab(),
                _buildKitchenToolsTab(),
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
        Card(
          color: Colors.black45,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFF97316), width: 1),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Think in Clock Speeds, Not Just "Nutrients"',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF97316)),
                ),
                SizedBox(height: 8),
                Text(
                  'Every animal runs on a biological battery grid. Some nutrients drain in hours under stress; '
                  'others take months to run dry - and just as long to refill. ForgeFeed\'s safety checks are '
                  'built around these three speeds: know which tier a symptom points to, and you know how fast '
                  'you actually need to move.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildBatteryCard(
          'High Clock Speed · Hours',
          'Electrolytes & Hydration',
          'The fastest-draining tank in the body. Heat stress, diarrhea, or a sudden spike in activity can empty '
          'it before you notice anything\'s wrong - cellular damage starts within hours, not days. It\'s why '
          "ForgeFeed's safety engine caps added salt at 0.5% of a batch: too little drains fast, too much is "
          'just as dangerous.',
          Colors.redAccent,
          Icons.flash_on,
        ),
        _buildBatteryCard(
          'Medium Clock Speed · Days to Weeks',
          'Water-Soluble Vitamins & Amino Acids',
          "B-vitamins and amino acids like Lysine and Methionine aren't warehoused in tissue - the body uses what "
          "it needs and flushes the rest. Skip a few days of proper intake and it shows: sluggish growth, patchy "
          "feathering, dropped production. Waterfowl burn through Niacin especially fast - almost double a "
          "chicken's requirement.",
          Colors.orangeAccent,
          Icons.timer,
        ),
        _buildBatteryCard(
          'Slow Clock Speed · Months',
          'Fat-Soluble Vitamins & Structural Minerals',
          'Calcium, Phosphorus, Vitamins A/D/E/K, and trace minerals like Copper are banked in bone and fatty '
          "tissue. That's good news and bad news: a short gap won't tank the animal, but rebuilding a real "
          "deficit takes months, not one good meal. It also means overdoing a fat-soluble nutrient - like "
          "Copper in sheep - can quietly build toward toxicity long before symptoms ever show.",
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
        const Card(
          color: Colors.black45,
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What ForgeFeed Actually Checks',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF97316)),
                ),
                SizedBox(height: 8),
                Text(
                  "Every entry below is a nutrient ForgeFeed tracks on every ingredient and checks against every "
                  "recipe you build - grouped by the same Body Battery clock speed, with the real Pantry items "
                  "that supply it.",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildSpeedHeader('High Clock Speed · Hours', Colors.redAccent),
        _buildNutrientTile(
          'Sodium (Salt)',
          'Electrolyte & fluid balance',
          "Powers nerve signaling and hydration. Heat stress or scours can drain it in hours - but overshoot it "
          "just as fast: ForgeFeed's safety engine flags any batch where added salt exceeds 0.5% of the total.",
          'Salt (NaCl)',
          Colors.redAccent,
        ),
        _buildSpeedHeader('Medium Clock Speed · Days to Weeks', Colors.orangeAccent),
        _buildNutrientTile(
          'Lysine & Methionine',
          'Essential amino acids for growth & feathering',
          "Not stockpiled - a shortfall shows up within days to weeks as slow growth or ragged feathering. Low "
          "Methionine specifically is a known driver of feather-pecking and cannibalism.",
          'L-Lysine HCl, DL-Methionine, Amino Acid Isolate',
          Colors.orangeAccent,
        ),
        _buildNutrientTile(
          'Niacin (Vitamin B3)',
          'Nerve & leg development',
          "Water-soluble and flushed out fast. Waterfowl need roughly double a chicken's Niacin (~55-70 mg/kg) - "
          "standard chicken starter runs them short, and it shows up as bowed legs and hock swelling within weeks.",
          "Niacin / Vitamin B3 Powder, Brewer's Yeast, Nutritional Yeast",
          Colors.orangeAccent,
        ),
        _buildNutrientTile(
          'Riboflavin (Vitamin B2)',
          'Nerve function in young/growing animals',
          "A gap during the brooder stage causes curled-toe paralysis within days - one of the fastest-onset "
          "deficiencies ForgeFeed's symptom data tracks.",
          'Commercial Multivitamin Premix',
          Colors.orangeAccent,
        ),
        _buildNutrientTile(
          'Taurine',
          'Heart & vision support for obligate carnivores',
          "Species like ferrets and small exotic carnivores can't synthesize it themselves - a plant-heavy or "
          "taurine-free meat blend drains reserves over just a few weeks.",
          'Taurine Powder',
          Colors.orangeAccent,
        ),
        _buildSpeedHeader('Slow Clock Speed · Months', Colors.blueAccent),
        _buildNutrientTile(
          'Calcium & Phosphorus',
          'Bone & eggshell structure',
          "Banked in bone and drawn down slowly - but the ratio matters more than the raw amount. ForgeFeed "
          "checks it automatically: roughly 1.5:1-2.2:1 for growing animals, up to 7:1-11:1 for actively laying "
          "hens. High-oxalate forage can also strip calcium away before it's absorbed, which is why horses and "
          "grazers get their own Calcium:Oxalate check.",
          'Limestone, Oyster Shell, Dicalcium Phosphate, Ground Eggshell, Bone Meal',
          Colors.blueAccent,
        ),
        _buildNutrientTile(
          'Vitamin D3 & Vitamin E',
          'Calcium uptake & antioxidant/nerve protection',
          "Fat-soluble and stored in tissue for months. Low D3 undercuts calcium no matter how much you feed; low "
          "E is linked to Encephalomalacia (\"Crazy Chick Disease\").",
          'Liquid Vitamin D3, Vitamin E Oil, Cod Liver Oil',
          Colors.blueAccent,
        ),
        _buildNutrientTile(
          'Copper & Molybdenum',
          'Enzyme cofactors - the narrowest safety margin ForgeFeed tracks',
          "Copper accumulates in the liver over months. Sheep need the Cu:Mo ratio held between 3:1 and 10:1 - "
          "ForgeFeed flags this automatically, since copper toxicity from a generic trace mineral mix is one of "
          "the most common fatal mistakes in mixed-species setups.",
          'Trace Mineral Premix (verify copper-safe before feeding sheep)',
          Colors.blueAccent,
        ),
        _buildNutrientTile(
          'Manganese',
          'Tendon & bone structure in fast-growing birds',
          "A structural mineral, slow to deplete - but a deficiency causes perosis (slipped tendon), and the "
          "hock damage it leaves behind is permanent.",
          'Trace Mineral Premix',
          Colors.blueAccent,
        ),
      ],
    );
  }

  Widget _buildSpeedHeader(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4, left: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientTile(String name, String role, String notes, String pantrySources, Color speedColor) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: Icon(Icons.circle, color: speedColor, size: 14),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF97316))),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Role: $role', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 4),
              Text(notes, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 6),
              Text(
                'In your Pantry: $pantrySources',
                style: const TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 3. INGREDIENT ENCYCLOPEDIA TAB
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

  // 4. KITCHEN TOOLS TAB
  Widget _buildKitchenToolsTab() {
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
                  'Getting the Right Texture',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF97316)),
                ),
                SizedBox(height: 8),
                Text(
                  'When a batch includes fresh or frozen meat and produce, ForgeFeed tells you which of '
                  "these simple tools to use - and how fine to go - right in that recipe's How to Prep steps.",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildToolCard(
          'Knife',
          'Cutting & Chopping',
          'The default for adult and larger animals that can handle bite-sized chunks: raw meat cut into pieces, fresh produce chopped small.',
          Icons.content_cut,
        ),
        _buildToolCard(
          'Meat Grinder',
          'Fine Grinding',
          'Grinds fresh or frozen meat down to a fine, uniform texture. Recommended for small-bodied animals (rodents, birds, amphibians, marsupials) and babies of any species.',
          Icons.blender,
        ),
        _buildToolCard(
          'Blender',
          'Pureeing',
          'Purees fresh produce into a smooth texture that mixes evenly into small or young animals\' food - pairs with the meat grinder for the smallest or youngest eaters.',
          Icons.local_drink,
        ),
      ],
    );
  }

  Widget _buildToolCard(String name, String purpose, String notes, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFF97316), size: 32),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Used for: $purpose', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 2),
            Text(notes, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
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
              backgroundColor: const Color(0xFFC2410C),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category: $type', style: const TextStyle(color: Color(0xFFF97316), fontSize: 12)),
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}