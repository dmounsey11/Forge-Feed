import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'tier_service.dart';

/// Product IDs must be created as monthly subscriptions in Google Play
/// Console (and later App Store Connect) with these exact IDs before real
/// purchases will resolve - until then [PurchaseService.products] comes
/// back empty and [PurchaseService.buy] surfaces a "not available" error.
class PurchaseProductIds {
  static const hobbyMonthly = 'forgefeed_hobby_monthly';
  static const proMonthly = 'forgefeed_pro_monthly';
  static const all = {hobbyMonthly, proMonthly};

  static UserTier? tierFor(String productId) {
    switch (productId) {
      case hobbyMonthly:
        return UserTier.tier1;
      case proMonthly:
        return UserTier.pro;
      default:
        return null;
    }
  }
}

/// True only on the platforms the in_app_purchase plugin actually ships an
/// implementation for. Touching [InAppPurchase.instance] anywhere else
/// (web, Windows, Linux) throws a LateInitializationError, since no
/// platform implementation ever registers itself there - so every access
/// to the plugin in this service must be gated behind this check.
bool get _storeSupported =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// Wraps the platform store (Google Play / App Store) purchase flow and
/// pushes the resulting entitlement into [TierService], which remains the
/// single source of truth the rest of the app reads from.
class PurchaseService extends ChangeNotifier {
  PurchaseService(this._tierService);

  final TierService _tierService;
  InAppPurchase? _iap;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  bool _purchasePending = false;
  bool get purchasePending => _purchasePending;

  String? _lastError;
  String? get lastError => _lastError;

  Map<String, ProductDetails> _products = {};
  List<ProductDetails> get products => List.unmodifiable(_products.values);

  Future<void> initialize() async {
    if (!_storeSupported) {
      _isAvailable = false;
      notifyListeners();
      return;
    }

    final iap = InAppPurchase.instance;
    _iap = iap;

    try {
      _isAvailable = await iap.isAvailable();
    } catch (error) {
      _isAvailable = false;
      _lastError = error.toString();
      notifyListeners();
      return;
    }
    if (!_isAvailable) {
      notifyListeners();
      return;
    }

    _subscription = iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object error) {
        _lastError = error.toString();
        notifyListeners();
      },
    );

    final response = await iap.queryProductDetails(PurchaseProductIds.all);
    _products = {for (final p in response.productDetails) p.id: p};
    notifyListeners();

    // Re-sync any already-active subscription (e.g. after reinstall).
    unawaited(iap.restorePurchases());
  }

  Future<void> buy(String productId) async {
    final iap = _iap;
    final product = _products[productId];
    if (iap == null || product == null) {
      _lastError = 'That plan isn\'t set up in the store yet.';
      notifyListeners();
      return;
    }
    _purchasePending = true;
    _lastError = null;
    notifyListeners();
    await iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
  }

  Future<void> restorePurchases() async {
    final iap = _iap;
    if (iap == null) return;
    await iap.restorePurchases();
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _purchasePending = true;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final tier = PurchaseProductIds.tierFor(purchase.productID);
          if (tier != null) {
            _tierService.setTierFromPurchase(tier);
          }
          _purchasePending = false;
          if (purchase.pendingCompletePurchase) {
            unawaited(_iap?.completePurchase(purchase) ?? Future.value());
          }
          break;
        case PurchaseStatus.error:
          _purchasePending = false;
          _lastError = purchase.error?.message ?? 'Purchase failed.';
          break;
        case PurchaseStatus.canceled:
          _purchasePending = false;
          break;
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
