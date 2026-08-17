import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// True only on the platforms the Google Mobile Ads plugin actually ships an
/// implementation for - same guard pattern as PurchaseService, since
/// touching the plugin on web/Windows/Linux isn't supported here.
bool get adsSupported =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// The Android banner is the real "main_banner" ad unit from the Keystone
/// Apps AdMob account. The iOS banner is still Google's official test unit
/// ID since there's no iOS platform folder / AdMob iOS app yet - swap it for
/// a real ID once iOS work starts, or serving real ads against a test ID
/// (or vice versa) risks the AdMob account being flagged for invalid traffic.
class AdUnitIds {
  static const _androidBanner = 'ca-app-pub-3930015548486501/3671856500';
  static const _iosBanner = 'ca-app-pub-3940256099942544/2934735716';

  static String get banner => defaultTargetPlatform == TargetPlatform.iOS ? _iosBanner : _androidBanner;
}

/// Device IDs to always serve test ads to, even though the app is using real
/// ad unit IDs above. Run the app, check the console for a line like
/// "Use RequestConfiguration.Builder().setTestDeviceIds(Arrays.asList(...))"
/// with your device's ID, and add it here. Prevents your own dev/test
/// clicks on real ads from getting the AdMob account flagged for invalid
/// traffic.
const _testDeviceIds = <String>[];

Future<void> initializeAds() async {
  if (!adsSupported) return;
  await MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(testDeviceIds: _testDeviceIds),
  );
  await MobileAds.instance.initialize();
}
