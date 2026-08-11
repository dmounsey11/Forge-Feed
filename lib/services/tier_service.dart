import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which subscription tier the current user is on. Driven by PurchaseService
/// once a real store purchase completes or restores; [cycleTier] remains as
/// a debug-only stand-in for testing tier-gated UI without a store purchase.
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
  static const _prefsKeyFirstLaunch = 'ff_first_launch_date';

  /// Anyone who opens ForgeFeed for the very first time on or before this
  /// date gets a full year of free Hobby tier, as an early-adopter/referral
  /// incentive. Change this one line to move the promo window - update it,
  /// tell Darwin what it's set to, and confirm it matches what he wants to
  /// promote.
  static final DateTime founderPromoCutoff = DateTime(2026, 11, 9);
  static const founderPromoDuration = Duration(days: 365);

  UserTier _purchasedTier = UserTier.free;
  DateTime? _firstLaunchDate;

  /// True once [cycleTier] has been used, so debug testing isn't masked by
  /// the founder promo auto-granting Hobby tier on a fresh install.
  bool _debugOverride = false;

  /// The tier the rest of the app should treat the user as being on: a real
  /// purchase always wins, otherwise an active founder-promo grant, otherwise
  /// free.
  UserTier get tier {
    if (_debugOverride) return _purchasedTier;
    if (_purchasedTier.isPaid) return _purchasedTier;
    if (_founderPromoActive) return UserTier.tier1;
    return _purchasedTier;
  }

  bool get _founderPromoActive {
    final firstLaunch = _firstLaunchDate;
    if (firstLaunch == null) return false;
    if (firstLaunch.isAfter(founderPromoCutoff)) return false;
    return DateTime.now().isBefore(firstLaunch.add(founderPromoDuration));
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKeyTier);
    if (stored != null) {
      _purchasedTier = UserTier.values.firstWhere(
        (t) => t.name == stored,
        orElse: () => UserTier.free,
      );
    }

    final storedFirstLaunch = prefs.getString(_prefsKeyFirstLaunch);
    if (storedFirstLaunch != null) {
      _firstLaunchDate = DateTime.tryParse(storedFirstLaunch);
    } else {
      _firstLaunchDate = DateTime.now();
      await prefs.setString(_prefsKeyFirstLaunch, _firstLaunchDate!.toIso8601String());
    }

    notifyListeners();
  }

  /// Cycles Free -> Tier 1 -> Pro -> Free. Debug-only testing stand-in for a
  /// real upgrade/downgrade flow.
  void cycleTier() {
    _debugOverride = true;
    final next = UserTier.values[(_purchasedTier.index + 1) % UserTier.values.length];
    _purchasedTier = next;
    notifyListeners();
    unawaited(_persist());
  }

  /// Sets the tier from a completed or restored store purchase.
  void setTierFromPurchase(UserTier tier) {
    if (_purchasedTier == tier) return;
    _purchasedTier = tier;
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyTier, _purchasedTier.name);
  }
}
