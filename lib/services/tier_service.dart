import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which subscription tier the current user is on. There's no real payment
/// processing wired up yet, so this is a local stand-in - tapping the header
/// badge cycles through these for testing. Swap the source of truth here
/// (not in the screens that read it) once real purchases exist.
enum UserTier { free, tier1, pro }

extension UserTierLabel on UserTier {
  String get label {
    switch (this) {
      case UserTier.free:
        return 'Free Tier';
      case UserTier.tier1:
        return 'Hobby Tier';
      case UserTier.pro:
        return 'Pro';
    }
  }

  bool get isPaid => this != UserTier.free;
}

class TierService extends ChangeNotifier {
  static const _prefsKeyTier = 'ff_user_tier';

  UserTier _tier = UserTier.free;
  UserTier get tier => _tier;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKeyTier);
    if (stored != null) {
      _tier = UserTier.values.firstWhere(
        (t) => t.name == stored,
        orElse: () => UserTier.free,
      );
      notifyListeners();
    }
  }

  /// Cycles Free -> Tier 1 -> Pro -> Free. Local testing stand-in for a
  /// real upgrade/downgrade flow.
  void cycleTier() {
    final next = UserTier.values[(_tier.index + 1) % UserTier.values.length];
    _tier = next;
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyTier, _tier.name);
  }
}
