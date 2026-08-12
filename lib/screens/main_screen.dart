import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tier_service.dart';
import '../widgets/ad_banner_widget.dart';
import '../widgets/feedback_dialog.dart';
import '../widgets/upgrade_dialog.dart';
import 'home_screen.dart';
import 'pantry_screen.dart';
import 'profiles_screen.dart';
import 'info_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isMetric = false;

  final List<Widget> _screens = const [
    HomeScreen(),
    ProfilesScreen(),
    PantryScreen(),
    InfoScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: const Color(0xFF2A2A2D).withValues(alpha: 0.78)),
          ),
          SafeArea(
            child: Column(
              children: [
                HeaderBar(
                  isMetric: _isMetric,
                  onUnitToggle: (value) {
                    setState(() {
                      _isMetric = value;
                    });
                  },
                ),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _screens,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Shown to Free and Hobby tiers; Pro is ad-free.
          Consumer<TierService>(
            builder: (context, tierService, _) {
              if (tierService.tier == UserTier.pro) return const SizedBox.shrink();
              return const AdBannerWidget();
            },
          ),
          BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: const Color(0xFF1A1A1C),
            selectedItemColor: const Color(0xFFF97316),
            unselectedItemColor: Colors.white54,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.calculate_outlined),
                activeIcon: Icon(Icons.calculate),
                label: 'Create Feed',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.pets_outlined),
                activeIcon: Icon(Icons.pets),
                label: 'Profiles',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                activeIcon: Icon(Icons.inventory_2),
                label: 'Pantry',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.info_outline),
                activeIcon: Icon(Icons.info),
                label: 'Info',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HeaderBar extends StatelessWidget {
  final bool isMetric;
  final ValueChanged<bool> onUnitToggle;

  const HeaderBar({
    super.key,
    required this.isMetric,
    required this.onUnitToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: const Color(0xFF1A1A1C),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 640;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Branding Block
              Expanded(
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 56,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF242426),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'V2.4',
                              style: TextStyle(
                                color: Color(0xFFF97316),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!isNarrow)
                            const Text(
                              'Precision Species Dietary Engine & Custom Ration Formulator',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Actions Group: Feedback Button, Unit Toggle, and Tier Badge
              Row(
                children: [
              // Feedback / Request Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF97316),
                  side: const BorderSide(color: Color(0xFFF97316), width: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.lightbulb_outline, size: 18),
                label: const Text(
                  'Feedback',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const FeedbackDialog(),
                  );
                },
              ),
              const SizedBox(width: 12),

              // Unit Switcher
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF242426),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => onUnitToggle(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMetric ? const Color(0xFFF97316) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'kg / g',
                          style: TextStyle(
                            color: isMetric ? const Color(0xFF1A1A1C) : Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => onUnitToggle(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: !isMetric ? const Color(0xFFF97316) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'lbs / oz',
                          style: TextStyle(
                            color: !isMetric ? const Color(0xFF1A1A1C) : Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Tier Badge - in debug builds, tap cycles Free / Tier 1 / Pro
              // as a stand-in for testing tier-gated UI without a real
              // store purchase. In release builds, tap opens the real
              // upgrade flow.
              Consumer<TierService>(
                builder: (context, tierService, _) {
                  final tier = tierService.tier;
                  return GestureDetector(
                    onTap: kDebugMode
                        ? tierService.cycleTier
                        : () => showDialog(
                              context: context,
                              builder: (context) => const UpgradeDialog(),
                            ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF242426),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Color(0xFFF97316), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            tier.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF97316),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tier.isPaid ? 'Tap to Cycle' : 'Upgrade',
                              style: const TextStyle(
                                color: Color(0xFF1A1A1C),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
            ],
          );
        },
      ),
    );
  }
}