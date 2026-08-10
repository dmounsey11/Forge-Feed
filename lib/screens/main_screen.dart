import 'package:flutter/material.dart';
import '../widgets/feedback_dialog.dart';
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
      body: SafeArea(
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF0D1117),
        selectedItemColor: const Color(0xFF84CC16),
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
      color: const Color(0xFF0D1117),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Branding Block
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF161F1A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF84CC16), width: 1.5),
                ),
                child: const Center(
                  child: Text(
                    'FE',
                    style: TextStyle(
                      color: Color(0xFF84CC16),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'FORGE FEED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161F1A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'V2.4',
                          style: TextStyle(
                            color: Color(0xFF84CC16),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Precision Species Dietary Engine & Custom Ration Formulator',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Actions Group: Feedback Button, Unit Toggle, and Tier Badge
          Row(
            children: [
              // Feedback / Request Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF84CC16),
                  side: const BorderSide(color: Color(0xFF84CC16), width: 1),
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
                  color: const Color(0xFF161F1A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => onUnitToggle(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMetric ? const Color(0xFF84CC16) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'kg / g',
                          style: TextStyle(
                            color: isMetric ? const Color(0xFF0D1117) : Colors.white60,
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
                          color: !isMetric ? const Color(0xFF84CC16) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'lbs / oz',
                          style: TextStyle(
                            color: !isMetric ? const Color(0xFF0D1117) : Colors.white60,
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

              // Upgrade Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF161F1A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFF84CC16), size: 16),
                    const SizedBox(width: 6),
                    const Text(
                      'Free Tier',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF84CC16),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Upgrade',
                        style: TextStyle(
                          color: Color(0xFF0D1117),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}