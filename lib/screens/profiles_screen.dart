import 'package:flutter/material.dart';
import '../models/animal_profile.dart';
import '../widgets/add_profile_dialog.dart';

class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  final List<AnimalProfile> _profiles = [
    AnimalProfile(
      id: '1',
      name: 'Main Backyard Flock',
      species: 'Livestock: Poultry (Chicken)',
      headCount: 12,
      productionStage: 'Active Layer',
      environment: 'Outdoor',
    ),
    AnimalProfile(
      id: '2',
      name: 'Coturnix Quail Pens',
      species: 'Livestock: Poultry (Quail)',
      headCount: 24,
      productionStage: 'Breeder / Production',
      environment: 'Outdoor',
    ),
  ];

  void _openAddProfileDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AddProfileDialog(
        onProfileSaved: (newProfile) {
          setState(() {
            _profiles.add(newProfile);
          });
        },
      ),
    );
  }

  void _openEditProfileDialog(AnimalProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) => AddProfileDialog(
        profileToEdit: profile,
        onProfileSaved: (updatedProfile) {
          setState(() {
            final index = _profiles.indexWhere((p) => p.id == updatedProfile.id);
            if (index != -1) {
              _profiles[index] = updatedProfile;
            }
          });
        },
      ),
    );
  }

  void _deleteProfile(String id) {
    setState(() {
      _profiles.removeWhere((p) => p.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Animal & Flock Profiles',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: _openAddProfileDialog,
                  icon: const Icon(Icons.add_circle, color: Color(0xFF84CC16), size: 36),
                  tooltip: 'Add Animal Profile',
                ),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
              child: _profiles.isEmpty
                  ? const Center(
                      child: Text(
                        'No profiles created yet.',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _profiles.length,
                      itemBuilder: (context, index) {
                        final profile = _profiles[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161F1A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF223127)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    profile.name,
                                    style: const TextStyle(
                                      color: Color(0xFF84CC16),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF223127),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${profile.headCount} Head',
                                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.white70, size: 20),
                                        onPressed: () => _openEditProfileDialog(profile),
                                        tooltip: 'Edit Profile',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                        onPressed: () => _deleteProfile(profile.id),
                                        tooltip: 'Delete Profile',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${profile.species} • ${profile.productionStage} • ${profile.environment}',
                                style: const TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 12,
                                children: [
                                  _NutrientBadge(label: 'Target Protein', value: '${profile.targetProteinPct.toStringAsFixed(1)}%'),
                                  _NutrientBadge(label: 'Target Calcium', value: '${profile.targetCalciumPct.toStringAsFixed(1)}%'),
                                  _NutrientBadge(label: 'Energy', value: '${profile.targetEnergyMeKcalLb.toInt()} kcal/lb'),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutrientBadge extends StatelessWidget {
  final String label;
  final String value;

  const _NutrientBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}