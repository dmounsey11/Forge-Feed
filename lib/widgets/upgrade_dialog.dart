import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import '../services/purchase_service.dart';

/// Lets the user pick Hobby or Pro and kicks off the store subscription
/// purchase flow via [PurchaseService].
class UpgradeDialog extends StatelessWidget {
  const UpgradeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF242426),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFF97316), width: 1.5),
      ),
      child: Consumer<PurchaseService>(
        builder: (context, purchaseService, _) {
          return Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFFF97316), size: 28),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Upgrade ForgeFeed',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!purchaseService.isAvailable)
                  const Text(
                    "The store isn't available on this device right now.",
                    style: TextStyle(color: Colors.redAccent, fontSize: 13),
                  )
                else ...[
                  const _PlanTile(
                    productId: PurchaseProductIds.hobbyMonthly,
                    title: 'Hobby Tier',
                    fallbackPrice: '\$4.99/mo',
                    description: 'Multiple animals, flock & herd tracking, health screening.',
                  ),
                  const SizedBox(height: 12),
                  const _PlanTile(
                    productId: PurchaseProductIds.proMonthly,
                    title: 'Pro',
                    fallbackPrice: '\$9.99/mo',
                    description: 'Everything in Hobby, plus email & download recipes.',
                  ),
                ],
                if (purchaseService.lastError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    purchaseService.lastError!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: purchaseService.purchasePending ? null : purchaseService.restorePurchases,
                    child: const Text('Restore Purchases', style: TextStyle(color: Colors.white54)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final String productId;
  final String title;
  final String fallbackPrice;
  final String description;

  const _PlanTile({
    required this.productId,
    required this.title,
    required this.fallbackPrice,
    required this.description,
  });

  ProductDetails? _findProduct(List<ProductDetails> products) {
    for (final p in products) {
      if (p.id == productId) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final purchaseService = context.watch<PurchaseService>();
    final product = _findProduct(purchaseService.products);
    final price = product?.price ?? fallbackPrice;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 6),
                Text(price, style: const TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF97316), foregroundColor: Colors.white),
            onPressed: purchaseService.purchasePending ? null : () => purchaseService.buy(productId),
            child: purchaseService.purchasePending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Subscribe'),
          ),
        ],
      ),
    );
  }
}
