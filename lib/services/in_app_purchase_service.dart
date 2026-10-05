import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../config/post_pricing_config.dart';
import 'api_client.dart';

/// Result object for in-app purchase attempts
class InAppPurchaseResult {
  final bool success;
  final String? message;
  final String? transactionId;
  final String? purchaseToken;
  final String? productId;
  final String? platform;
  final Map<String, dynamic>? serverResponse;
  final bool isCancelled;

  const InAppPurchaseResult({
    required this.success,
    this.message,
    this.transactionId,
    this.purchaseToken,
    this.productId,
    this.platform,
    this.serverResponse,
    this.isCancelled = false,
  });

  factory InAppPurchaseResult.cancelled() {
    return const InAppPurchaseResult(
      success: false,
      message: 'Payment was cancelled.',
      isCancelled: true,
    );
  }

  factory InAppPurchaseResult.failed(String message) {
    return InAppPurchaseResult(
      success: false,
      message: message,
    );
  }

  factory InAppPurchaseResult.success({
    required String transactionId,
    required String purchaseToken,
    required String productId,
    required String platform,
    Map<String, dynamic>? serverResponse,
    String? message,
  }) {
    return InAppPurchaseResult(
      success: true,
      transactionId: transactionId,
      purchaseToken: purchaseToken,
      productId: productId,
      platform: platform,
      serverResponse: serverResponse,
      message: message ?? 'Payment successfully completed and verified.',
    );
  }
}

/// Service managing Google Play Billing and Apple StoreKit In-App Purchases
class InAppPurchaseService {
  static final InAppPurchaseService _instance = InAppPurchaseService._internal();
  factory InAppPurchaseService() => _instance;
  InAppPurchaseService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isAvailable = false;
  bool _isInitialized = false;
  final Map<String, ProductDetails> _products = {};
  Completer<InAppPurchaseResult>? _currentPurchaseCompleter;
  String? _currentPendingPostId;
  String? _currentBusinessId;
  int? _currentDurationDays;

  bool get isStoreAvailable => _isAvailable;
  Map<String, ProductDetails> get products => Map.unmodifiable(_products);

  /// Initialize store connection and load product catalog
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _isAvailable = await _iap.isAvailable();
      if (kDebugMode) {
        print('[IAP] Store available: $_isAvailable');
      }

      _subscription = _iap.purchaseStream.listen(
        _onPurchaseUpdates,
        onDone: () => _subscription?.cancel(),
        onError: (error) {
          if (kDebugMode) {
            print('[IAP] Purchase stream error: $error');
          }
          if (_currentPurchaseCompleter != null && !_currentPurchaseCompleter!.isCompleted) {
            _currentPurchaseCompleter!.complete(InAppPurchaseResult.failed('Store stream error: $error'));
          }
        },
      );

      if (_isAvailable) {
        await queryProducts();
      }

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('[IAP] Initialization failed: $e');
      }
    }
  }

  /// Query product details for all supported post duration tiers
  Future<void> queryProducts() async {
    try {
      final productIds = PostPricingConfig.allProductIds;
      final ProductDetailsResponse response = await _iap.queryProductDetails(productIds);

      if (response.error != null) {
        if (kDebugMode) {
          print('[IAP] Error querying products: ${response.error!.message}');
        }
        return;
      }

      _products.clear();
      for (final p in response.productDetails) {
        _products[p.id] = p;
      }

      if (kDebugMode) {
        print('[IAP] Loaded ${_products.length} products from store.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[IAP] Exception querying products: $e');
      }
    }
  }

  /// Get formatted display price for a given duration option
  String getPriceForOption(PostDurationOption option) {
    if (_products.containsKey(option.productId)) {
      return _products[option.productId]!.price;
    }
    return option.getFormattedPrice(isProduction: PostPricingConfig.isProductionPricing);
  }

  /// Start consumable purchase flow for paid post sharing
  Future<InAppPurchaseResult> buyPostSharing({
    required PostDurationOption option,
    required String businessId,
    required String pendingPostId,
    required String authToken,
    String? userId,
    String? userEmail,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    _currentPendingPostId = pendingPostId;
    _currentBusinessId = businessId;
    _currentDurationDays = option.days;
    _currentPurchaseCompleter = Completer<InAppPurchaseResult>();

    // 1. If Store is available and product is registered in Google Play / App Store
    if (_isAvailable && _products.containsKey(option.productId)) {
      final productDetails = _products[option.productId]!;
      final purchaseParam = PurchaseParam(
        productDetails: productDetails,
        applicationUserName: userId ?? userEmail,
      );

      try {
        final initiated = await _iap.buyConsumable(
          purchaseParam: purchaseParam,
          autoConsume: true,
        );

        if (!initiated) {
          return InAppPurchaseResult.failed('Failed to start purchase with the store.');
        }

        // Wait for store transaction stream update
        return await _currentPurchaseCompleter!.future.timeout(
          const Duration(minutes: 5),
          onTimeout: () => InAppPurchaseResult.failed('Payment timed out. Please check your store receipts.'),
        );
      } catch (e) {
        return InAppPurchaseResult.failed('Store purchase error: $e');
      }
    }

    // 2. Development / Sandbox fallback when testing without live Google Play / Apple Developer IAP console link
    if (kDebugMode || !PostPricingConfig.isProductionPricing) {
      if (kDebugMode) {
        print('[IAP] Running in local sandbox test mode for product ${option.productId}');
      }
      return await _processSandboxTestVerification(
        option: option,
        businessId: businessId,
        pendingPostId: pendingPostId,
        authToken: authToken,
        userId: userId,
        userEmail: userEmail,
      );
    }

    return InAppPurchaseResult.failed('In-App Purchase store is currently unavailable on this device.');
  }

  /// Handle incoming purchase stream updates from StoreKit / Google Play Billing
  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        if (kDebugMode) {
          print('[IAP] Purchase pending...');
        }
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        if (kDebugMode) {
          print('[IAP] Purchase error: ${purchaseDetails.error?.message}');
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
        if (_currentPurchaseCompleter != null && !_currentPurchaseCompleter!.isCompleted) {
          _currentPurchaseCompleter!.complete(
            InAppPurchaseResult.failed(purchaseDetails.error?.message ?? 'Payment failed on store.'),
          );
        }
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
        if (_currentPurchaseCompleter != null && !_currentPurchaseCompleter!.isCompleted) {
          _currentPurchaseCompleter!.complete(InAppPurchaseResult.cancelled());
        }
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // Successful store payment -> Forward to backend for verification and activation
        final verificationResult = await _verifyWithBackend(purchaseDetails);

        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }

        if (_currentPurchaseCompleter != null && !_currentPurchaseCompleter!.isCompleted) {
          _currentPurchaseCompleter!.complete(verificationResult);
        }
      }
    }
  }

  /// Send purchase token and transaction info to backend for authoritative verification
  Future<InAppPurchaseResult> _verifyWithBackend(PurchaseDetails purchaseDetails) async {
    final platform = Platform.isAndroid ? 'google_play' : (Platform.isIOS ? 'app_store' : 'unknown');
    final purchaseToken = purchaseDetails.verificationData.serverVerificationData;
    final transactionId = purchaseDetails.purchaseID ?? 'tx_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final payload = {
        'post_id': _currentPendingPostId,
        'business_id': _currentBusinessId,
        'product_id': purchaseDetails.productID,
        'duration_days': _currentDurationDays,
        'platform': platform,
        'transaction_id': transactionId,
        'purchase_token': purchaseToken,
        'raw_payload': {
          'transactionDate': purchaseDetails.transactionDate,
          'status': purchaseDetails.status.toString(),
          'localVerificationData': purchaseDetails.verificationData.localVerificationData,
        }
      };

      final response = await ApiClient().post('/api/payments/verify-and-activate-post', payload);

      if (response != null && response is Map<String, dynamic> && response['success'] == true) {
        return InAppPurchaseResult.success(
          transactionId: transactionId,
          purchaseToken: purchaseToken,
          productId: purchaseDetails.productID,
          platform: platform,
          serverResponse: response,
          message: response['message']?.toString(),
        );
      } else {
        final errorMsg = response is Map ? response['message']?.toString() : 'Backend payment verification failed.';
        return InAppPurchaseResult.failed(errorMsg ?? 'Backend verification failed.');
      }
    } catch (e) {
      return InAppPurchaseResult.failed('Network error while verifying payment with backend: $e');
    }
  }

  /// Sandbox test verification for local emulator / development testing
  Future<InAppPurchaseResult> _processSandboxTestVerification({
    required PostDurationOption option,
    required String businessId,
    required String pendingPostId,
    required String authToken,
    String? userId,
    String? userEmail,
  }) async {
    final platform = Platform.isAndroid ? 'google_play_sandbox' : (Platform.isIOS ? 'app_store_sandbox' : 'test_sandbox');
    final transactionId = 'test_tx_${DateTime.now().millisecondsSinceEpoch}_${option.days}d';
    final purchaseToken = 'test_token_${DateTime.now().microsecondsSinceEpoch}';

    try {
      final payload = {
        'post_id': pendingPostId,
        'business_id': businessId,
        'product_id': option.productId,
        'duration_days': option.days,
        'platform': platform,
        'transaction_id': transactionId,
        'purchase_token': purchaseToken,
        'is_sandbox_test': true,
        'amount': option.getPrice(isProduction: false),
        'currency': 'INR',
      };

      final response = await ApiClient().post('/api/payments/verify-and-activate-post', payload);

      if (response != null && response is Map<String, dynamic> && response['success'] == true) {
        return InAppPurchaseResult.success(
          transactionId: transactionId,
          purchaseToken: purchaseToken,
          productId: option.productId,
          platform: platform,
          serverResponse: response,
          message: response['message']?.toString(),
        );
      } else {
        final msg = response is Map ? response['message']?.toString() : 'Failed to activate post on server.';
        return InAppPurchaseResult.failed(msg ?? 'Activation failed.');
      }
    } catch (e) {
      return InAppPurchaseResult.failed('Error communicating with server: $e');
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
