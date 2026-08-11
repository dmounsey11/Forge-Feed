import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// True only on the platforms the Google Mobile Ads plugin actually ships an
/// implementation for - same guard pattern as PurchaseService, since
/// touching the plugin on web/Windows/Linux isn't supported here.
bool get adsSupported =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// Google's official test ad unit IDs - safe to ship as-is and will always
/// serve a test ad. Swap these for real ad unit IDs from an AdMob account
/// before release; serving real ads against test IDs (or vice versa) risks
/// the AdMob account being flagged for invalid traffic.
class AdUnitIds {
  static const _androidBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const _iosBanner = 'ca-app-pub-3940256099942544/2934735716';

  static String get banner => defaultTargetPlatform == TargetPlatform.iOS ? _iosBanner : _androidBanner;
}

Future<void> initializeAds() async {
  if (!adsSupported) return;
  await MobileAds.instance.initialize();
}
