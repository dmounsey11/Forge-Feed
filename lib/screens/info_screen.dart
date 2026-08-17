import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'privacy_policy_screen.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  static const List<(String, String)> _referenceSources = [
    ('USDA FoodData Central', 'https://fdc.nal.usda.gov'),
    ('National Academies (NRC Nutrient Requirements)', 'https://www.nap.edu'),
    ('AAFCO', 'https://www.aafco.org'),
    ('Feedipedia', 'https://www.feedipedia.org'),
    ('Merck Veterinary Manual', 'https://www.merckvetmanual.com'),
  ];

  Future<void> _openReference(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't open $url")),
      );
    }
  }

  Widget _buildReferenceFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DATA SOURCES & REFERENCES',
            style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final (name, url) in _referenceSources)
                InkWell(
                  onTap: () => _openReference(context, url),
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Color(0xFFF97316),
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                ),
                child: const Text(
                  'Privacy Policy',
                  style: TextStyle(
                    color: Color(0xFFF97316),
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
              Tab(icon: Icon(Icons.menu_book), text: 'How We Blend'),
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
          _buildReferenceFooter(context),
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
        Card(
          color: Colors.black45,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.redAccent, width: 1),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text(
                      'Never Feed Cooked Bone',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Raw bone is pliable - it bends and gives under bite pressure, and stomach acid in a raw-fed '
                  'carnivore or omnivore is strong enough to soften and digest it. Cooking (boiling, baking, '
                  "roasting, grilling) drives the moisture out and changes the bone's structure, leaving it dry "
                  'and brittle. A brittle bone doesn\'t bend under bite pressure - it shatters into sharp shards. '
                  'Those shards can splinter in the mouth, get lodged in the throat, or work their way through '
                  'the digestive tract and cause a perforation or blockage - both of which are medical '
                  'emergencies.',
                  style: TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 8),
                Text(
                  'This applies to any cooked bone from any source - table scraps, roasted carcasses, cooked '
                  'stock bones. It does not apply to processed, rendered products like bone meal, which is '
                  "broken down before it's added to a batch and is handled by ForgeFeed's own inclusion-rate "
                  'safety checks.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
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
                  'How ForgeFeed Builds Your Blend',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF97316)),
                ),
                SizedBox(height: 8),
                Text(
                  "This isn't a recipe picked from a list - it's the output of a solve. ForgeFeed takes every "
                  "item in your Pantry and Supplements, looks up its published nutrient values, and searches for "
                  "the exact combination of pounds of each one that lands closest to every nutrient target your "
                  "animal needs, all at the same time. Here's what's actually happening under the hood.",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        _buildBlendStepCard(
          Icons.storage,
          'Step 1 - Real Nutrient Data, Not Guesswork',
          "Every ingredient in ForgeFeed's library carries published nutrient values - protein, fat, fiber, "
          "amino acids, calcium, phosphorus, energy, and more - sourced from the USDA nutrient database and "
          "standard feed-composition references, not estimated on the fly. If an ingredient is in your batch, "
          "ForgeFeed already knows what it actually contributes.",
        ),
        _buildBlendStepCard(
          Icons.flag,
          'Step 2 - A Target Built for This Animal',
          "Your animal's species, age, production stage, and any health flags (pregnant, breeding, injured, "
          "overweight) set the target: minimums and safe ranges for protein, fat, fiber, calcium, phosphorus, "
          "energy, key amino acids, and trace minerals - the same figures shown in the Vitamins & Minerals tab. "
          "These come from published species nutrition data, adjusted up or down for growth, reproduction, or "
          "recovery needs.",
        ),
        _buildBlendStepCard(
          Icons.calculate,
          'Step 3 - One Solve, Not a Sequence of Guesses',
          "Rather than picking a protein source, then a calcium source, then eyeballing the rest, ForgeFeed runs "
          "a linear program across your entire Pantry and Supplements list at once. It searches for the blend of "
          "quantities that satisfies every target simultaneously - protein and amino acid floors, calcium and "
          "phosphorus ranges, energy, fiber, and every hard safety ceiling (toxic mineral ratios, inclusion caps) "
          "this data can express - and finds the most balanced feed that's actually achievable from what you have "
          "on hand.",
        ),
        _buildBlendStepCard(
          Icons.eco,
          'Step 4 - Whole Foods First',
          "When more than one combination could work, the solve is built to prefer your real Pantry foods over "
          "Supplements - a vitamin/mineral premix or amino acid isolate is only pulled in to close a gap your "
          "foods genuinely can't cover on their own, not used as a shortcut.",
        ),
        _buildBlendStepCard(
          Icons.rule,
          'Step 5 - Honest About Limits',
          "If your current Pantry can't hit every target at once, ForgeFeed doesn't quietly serve up an "
          "imbalanced batch or refuse to help - it tells you exactly which target it had to loosen, how close it "
          "still got, and what kind of ingredient would close the gap. The one thing it never loosens is a hard "
          "safety limit: a toxic mineral ratio or inclusion cap will always block the batch rather than bend for "
          "the sake of producing a recipe.",
        ),
      ],
    );
  }

  Widget _buildBlendStepCard(IconData icon, String title, String desc) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFF97316), size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(desc, style: const TextStyle(color: Colors.white70)),
        ),
      ),
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
}