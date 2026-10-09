/// Central Pricing and Duration Configuration for Paid Post Sharing in ADVT App
/// Compatible with Google Play Billing (Android) and Apple StoreKit (iOS).
class PostDurationOption {
  final int days;
  final String productId;
  final String label;
  final double testPriceInr;
  final double prodPriceInr;

  const PostDurationOption({
    required this.days,
    required this.productId,
    required this.label,
    required this.testPriceInr,
    required this.prodPriceInr,
  });

  /// Get display price based on environment mode
  double getPrice({bool isProduction = false}) {
    return isProduction ? prodPriceInr : testPriceInr;
  }

  /// Formatted price string (fallback when store product details aren't yet loaded)
  String getFormattedPrice({bool isProduction = false}) {
    final price = getPrice(isProduction: isProduction);
    return price % 1 == 0 ? '₹${price.toInt()}' : '₹${price.toStringAsFixed(2)}';
  }
}

class PostPricingConfig {
  /// Toggle between testing pricing (₹1/day) and production pricing (₹100/day).
  /// Note: Real customer charge is always governed by the platform store product.
  static const bool isProductionPricing = false;

  /// Default currency
  static const String defaultCurrency = 'INR';

  /// Supported Post Sharing Duration Tiers
  static const List<PostDurationOption> supportedOptions = [
    PostDurationOption(
      days: 1,
      productId: 'advt_post_1_day',
      label: '1 Day',
      testPriceInr: 1.0,
      prodPriceInr: 99.0,
    ),
    PostDurationOption(
      days: 2,
      productId: 'advt_post_2_days',
      label: '2 Days',
      testPriceInr: 2.0,
      prodPriceInr: 199.0,
    ),
    PostDurationOption(
      days: 3,
      productId: 'advt_post_3_days',
      label: '3 Days',
      testPriceInr: 3.0,
      prodPriceInr: 299.0,
    ),
    PostDurationOption(
      days: 7,
      productId: 'advt_post_7_days',
      label: '7 Days',
      testPriceInr: 7.0,
      prodPriceInr: 699.0,
    ),
    PostDurationOption(
      days: 15,
      productId: 'advt_post_15_days',
      label: '15 Days',
      testPriceInr: 15.0,
      prodPriceInr: 1499.0,
    ),
    PostDurationOption(
      days: 30,
      productId: 'advt_post_30_days',
      label: '30 Days',
      testPriceInr: 30.0,
      prodPriceInr: 2999.0,
    ),
  ];

  /// Default selected duration (1 Day)
  static PostDurationOption get defaultOption => supportedOptions.first;

  /// Set of all store product IDs for Google Play / App Store querying
  static Set<String> get allProductIds => supportedOptions.map((e) => e.productId).toSet();

  /// Lookup duration option by number of days
  static PostDurationOption findByDays(int days) {
    return supportedOptions.firstWhere(
      (opt) => opt.days == days,
      orElse: () => defaultOption,
    );
  }

  /// Lookup duration option by platform product ID
  static PostDurationOption? findByProductId(String productId) {
    try {
      return supportedOptions.firstWhere((opt) => opt.productId == productId);
    } catch (_) {
      return null;
    }
  }

  /// Calculates expiration date from a given starting time (e.g. verified server payment time)
  static DateTime calculateExpiry(DateTime startTime, int days) {
    return startTime.add(Duration(days: days));
  }
}
