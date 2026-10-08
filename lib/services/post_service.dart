import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../models/target_location_model.dart';
import '../utils/text_utils.dart';
import '../utils/date_time_utils.dart';

class PostPaymentDetails {
  final String transactionId;
  final String productId;
  final String platform;
  final int selectedDays;
  final double amount;
  final String currency;
  final String paymentStatus;
  final String verificationStatus;
  final DateTime? paymentTime;
  final DateTime? publishedAt;
  final DateTime? expiresAt;

  PostPaymentDetails({
    required this.transactionId,
    this.productId = '',
    this.platform = '',
    this.selectedDays = 1,
    this.amount = 0.0,
    this.currency = 'INR',
    this.paymentStatus = 'completed',
    this.verificationStatus = 'verified',
    this.paymentTime,
    this.publishedAt,
    this.expiresAt,
  });

  factory PostPaymentDetails.fromJson(Map<String, dynamic> json) {
    return PostPaymentDetails(
      transactionId: json['transaction_id']?.toString() ?? json['transactionId']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? json['productId']?.toString() ?? '',
      platform: json['platform']?.toString() ?? '',
      selectedDays: json['selected_days'] ?? json['selectedDays'] ?? json['duration_days'] ?? 1,
      amount: double.tryParse((json['amount'] ?? '0').toString()) ?? 0.0,
      currency: json['currency']?.toString() ?? 'INR',
      paymentStatus: json['payment_status']?.toString() ?? json['paymentStatus']?.toString() ?? 'completed',
      verificationStatus: json['verification_status']?.toString() ?? json['verificationStatus']?.toString() ?? 'verified',
      paymentTime: DateTimeUtils.parseUtc(json['payment_time'] ?? json['paymentTime']),
      publishedAt: DateTimeUtils.parseUtc(json['published_at'] ?? json['publishedAt']),
      expiresAt: DateTimeUtils.parseUtc(json['expires_at'] ?? json['expiresAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactionId': transactionId,
      'productId': productId,
      'platform': platform,
      'selectedDays': selectedDays,
      'amount': amount,
      'currency': currency,
      'paymentStatus': paymentStatus,
      'verificationStatus': verificationStatus,
      'paymentTime': paymentTime?.toIso8601String(),
      'publishedAt': publishedAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }
}

class PostItem {
  final String postId;
  final int? numericPostId;
  final String businessProfileId;
  final int? numericBusinessId;
  final String bizName;
  final String type; // Always 'post' in ADVT App
  final String title;
  final String subtitle;
  final String description;
  final List<String> images; // Ordered list of actual selected post images
  final String? brandLogo;
  final String timeAgo;
  final DateTime createdAt;
  final String? targetLocation;
  final List<TargetLocationModel>? targetLocationItems;
  final int durationDays;
  final String status; // 'active', 'pending_payment', 'expired', 'cancelled'
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final String? paymentId;
  final DateTime? paymentTime;
  final PostPaymentDetails? payment;
  final bool isOwner;
  bool isSaved;
  int moreInfoClickCount;
  int savedCount;

  PostItem({
    required this.postId,
    this.numericPostId,
    required this.businessProfileId,
    this.numericBusinessId,
    required this.bizName,
    this.type = 'post',
    required this.title,
    required this.subtitle,
    required this.description,
    String? image,
    List<String>? images,
    this.brandLogo,
    required this.timeAgo,
    DateTime? createdAt,
    this.targetLocation,
    this.targetLocationItems,
    this.durationDays = 1,
    this.status = 'active',
    this.publishedAt,
    this.expiresAt,
    this.paymentId,
    this.paymentTime,
    this.payment,
    this.isOwner = false,
    this.isSaved = false,
    this.moreInfoClickCount = 0,
    this.savedCount = 0,
  })  : createdAt = createdAt ?? DateTime.now().toUtc(),
        images = (images != null && images.isNotEmpty)
            ? images
            : (image != null && image.isNotEmpty ? [image] : []);

  String? get image => images.isNotEmpty ? images.first : null;

  String get displayTitle => TextUtils.capitalizeWords(title);
  String get displayBizName => TextUtils.capitalizeWords(bizName);
  String get displaySubtitle => TextUtils.capitalizeWords(subtitle);
  String get displayLocation => TextUtils.capitalizeWords(targetLocation ?? '');

  bool get isPostActive => status == 'active' && (expiresAt == null || expiresAt!.isAfter(DateTime.now()));
  bool get isPostExpired => status == 'expired' || (expiresAt != null && expiresAt!.isBefore(DateTime.now()));

  /// Formatted Time for post feed and header cards using user's device local timezone
  String get formattedPostTime => DateTimeUtils.formatTime(publishedAt ?? createdAt);
  String get formattedPublishedAt => DateTimeUtils.formatDateTime(publishedAt ?? createdAt);
  String get formattedExpiresAt => DateTimeUtils.formatDateTime(expiresAt, placeholder: 'N/A');
  String get formattedPaymentTime => DateTimeUtils.formatDateTime(payment?.paymentTime ?? paymentTime ?? publishedAt ?? createdAt);
  String get calculatedTimeAgo => DateTimeUtils.calculateTimeAgo(publishedAt ?? createdAt);

  factory PostItem.fromJson(Map<String, dynamic> json) {
    final rawPostId = json['post_id'] ?? json['postId'] ?? 0;
    final int? numPostId = rawPostId is int
        ? rawPostId
        : int.tryParse(rawPostId.toString().replaceAll(RegExp(r'[^0-9]'), ''));
    final formattedPostId = json['postId'] as String? ??
        (numPostId != null ? 'P${numPostId.toString().padLeft(3, '0')}' : rawPostId.toString());

    final rawBizId = json['business_id'] ?? json['businessProfileId'] ?? 0;
    final int? numBizId = rawBizId is int
        ? rawBizId
        : int.tryParse(rawBizId.toString().replaceAll(RegExp(r'[^0-9]'), ''));
    final formattedBizId = json['businessProfileId'] as String? ??
        (numBizId != null ? 'BP${numBizId.toString().padLeft(3, '0')}' : rawBizId.toString());

    List<String> imgList = [];
    if (json['images'] != null) {
      if (json['images'] is List) {
        imgList = (json['images'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      } else if (json['images'] is String) {
        try {
          final decoded = jsonDecode(json['images'] as String);
          if (decoded is List) {
            imgList = decoded.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
          }
        } catch (_) {
          if ((json['images'] as String).isNotEmpty) {
            imgList = [json['images'] as String];
          }
        }
      }
    }

    List<TargetLocationModel>? targetLocItems;
    final rawLocs = json['target_locations_json'] ?? json['targetLocationItems'] ?? json['target_locations'];
    if (rawLocs != null) {
      if (rawLocs is List) {
        targetLocItems = rawLocs
            .map((item) => TargetLocationModel.fromMap(item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map)))
            .toList();
      } else if (rawLocs is String && rawLocs.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawLocs);
          if (decoded is List) {
            targetLocItems = decoded
                .map((item) => TargetLocationModel.fromMap(item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map)))
                .toList();
          }
        } catch (_) {}
      }
    }

    DateTime parsedCreatedAt = DateTimeUtils.parseUtc(json['created_at'] ?? json['createdAt']) ?? DateTime.now().toUtc();
    DateTime? parsedPublishedAt = DateTimeUtils.parseUtc(json['published_at'] ?? json['publishedAt']);
    DateTime? parsedExpiresAt = DateTimeUtils.parseUtc(json['expires_at'] ?? json['expiresAt']);
    DateTime? parsedPaymentTime = DateTimeUtils.parseUtc(json['payment_time'] ?? json['paymentTime']);

    PostPaymentDetails? paymentDetails;
    if (json['payment'] != null && json['payment'] is Map) {
      paymentDetails = PostPaymentDetails.fromJson(Map<String, dynamic>.from(json['payment'] as Map));
    }

    final parsedClicks = json['moreInfoClickCount'] ?? json['more_info_click_count'] ?? json['more_info_clicks'] ?? 0;
    final parsedSaves = json['savedCount'] ?? json['saved_count'] ?? 0;
    final parsedDays = json['duration_days'] ?? json['durationDays'] ?? 1;

    final rawStatus = json['status']?.toString() ?? (json['is_active'] == 1 || json['is_active'] == true ? 'active' : 'pending_payment');
    final isOwnerFlag = json['is_owner'] == true || json['isOwner'] == true;

    return PostItem(
      postId: formattedPostId,
      numericPostId: numPostId,
      businessProfileId: formattedBizId,
      numericBusinessId: numBizId,
      bizName: json['bizName'] ?? json['business_name'] ?? '',
      type: 'post',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      description: json['description'] ?? '',
      images: imgList,
      brandLogo: json['brandLogo'] ?? json['brand_logo'] ?? json['business_profile_image'],
      timeAgo: json['timeAgo'] ?? DateTimeUtils.calculateTimeAgo(parsedPublishedAt ?? parsedCreatedAt),
      createdAt: parsedCreatedAt,
      targetLocation: json['targetLocation'] ?? json['target_location'],
      targetLocationItems: targetLocItems,
      durationDays: parsedDays is int ? parsedDays : (int.tryParse(parsedDays.toString()) ?? 1),
      status: rawStatus,
      publishedAt: parsedPublishedAt,
      expiresAt: parsedExpiresAt,
      paymentId: json['payment_id']?.toString() ?? json['paymentId']?.toString() ?? paymentDetails?.transactionId,
      paymentTime: parsedPaymentTime ?? paymentDetails?.paymentTime,
      payment: paymentDetails,
      isOwner: isOwnerFlag,
      isSaved: (json['isSaved'] == true || json['is_saved'] == 1),
      moreInfoClickCount: parsedClicks is int ? parsedClicks : int.tryParse(parsedClicks.toString()) ?? 0,
      savedCount: parsedSaves is int ? parsedSaves : int.tryParse(parsedSaves.toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'numericPostId': numericPostId,
      'businessProfileId': businessProfileId,
      'numericBusinessId': numericBusinessId,
      'bizName': bizName,
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'images': images,
      'brandLogo': brandLogo,
      'timeAgo': timeAgo,
      'createdAt': createdAt.toIso8601String(),
      'targetLocation': targetLocation,
      'targetLocationItems': targetLocationItems?.map((e) => e.toMap()).toList(),
      'durationDays': durationDays,
      'status': status,
      'publishedAt': publishedAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'paymentId': paymentId,
      'paymentTime': paymentTime?.toIso8601String(),
      'payment': payment?.toJson(),
      'isOwner': isOwner,
      'isSaved': isSaved,
      'moreInfoClickCount': moreInfoClickCount,
      'savedCount': savedCount,
    };
  }
}

class PostService extends ChangeNotifier {
  final List<PostItem> _feedPosts = [];
  final List<PostItem> _savedPosts = [];
  int _totalCount = 0;
  bool _isLoading = false;

  String get _baseUrl => ApiClient().baseUrl;
  String get baseUrl => ApiClient().baseUrl;
  set baseUrl(String url) {
    ApiClient().setBaseUrl(url);
    notifyListeners();
  }

  bool get isLoading => _isLoading;
  List<PostItem> get allPosts => List.unmodifiable(_feedPosts);
  List<PostItem> get savedPosts => List.unmodifiable(_savedPosts);
  int get totalCount => _totalCount > 0 ? _totalCount : _feedPosts.length;

  /// Reset feed cache and count (e.g. when user changes location significantly)
  void resetFeed() {
    _feedPosts.clear();
    _totalCount = 0;
    notifyListeners();
  }

  /// Fetch location-targeted posts for Explore feed
  Future<List<PostItem>> fetchPosts({
    String? authToken,
    String? userId,
    String? userEmail,
    String? location,
    String? locality,
    String? city,
    String? state,
    String? country,
    double? latitude,
    double? longitude,
    String? businessId,
    String? search,
    String? postType,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final queryParams = <String, String>{};
      if (location != null && location.isNotEmpty && location.toLowerCase() != 'all') {
        queryParams['location'] = location.trim();
      }
      if (locality != null && locality.isNotEmpty) {
        queryParams['locality'] = locality.trim();
      }
      if (city != null && city.isNotEmpty) {
        queryParams['city'] = city.trim();
      }
      if (state != null && state.isNotEmpty) {
        queryParams['state'] = state.trim();
      }
      if (country != null && country.isNotEmpty) {
        queryParams['country'] = country.trim();
      }
      if (latitude != null && latitude != 0.0) {
        queryParams['latitude'] = latitude.toString();
      }
      if (longitude != null && longitude != 0.0) {
        queryParams['longitude'] = longitude.toString();
      }
      if (businessId != null && businessId.isNotEmpty) {
        queryParams['business_id'] = businessId.trim();
      }
      if (userId != null && userId.isNotEmpty) {
        queryParams['user_id'] = userId.trim();
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (authToken != null && authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
        if (userId != null && userId.isNotEmpty) 'x-user-id': userId.replaceAll(RegExp(r'[^0-9]'), ''),
        if (userEmail != null && userEmail.isNotEmpty) 'x-user-email': userEmail.trim(),
      };

      final uri = Uri.parse('$_baseUrl/api/posts').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['posts'] is List) {
          final List list = data['posts'] as List;
          final fetchedPosts = list.map((item) => PostItem.fromJson(item as Map<String, dynamic>)).toList();

          final rawTotal = data['total_count'] ?? data['totalCount'] ?? data['count'] ?? fetchedPosts.length;
          final parsedTotal = rawTotal is int ? rawTotal : (int.tryParse(rawTotal.toString()) ?? fetchedPosts.length);

          if (businessId != null && businessId.isNotEmpty) {
            _feedPosts.removeWhere((p) => p.businessProfileId == businessId);
            _feedPosts.addAll(fetchedPosts);
          } else {
            // Reapply saved bookmarks
            final savedIds = _savedPosts.map((p) => p.postId).toSet();
            for (final p in fetchedPosts) {
              if (savedIds.contains(p.postId)) {
                p.isSaved = true;
              } else if (p.isSaved && !_savedPosts.any((s) => s.postId == p.postId)) {
                _savedPosts.add(p);
              }
            }
            _feedPosts.clear();
            _feedPosts.addAll(fetchedPosts);
            _totalCount = parsedTotal;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[PostService] Error fetching posts: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return _feedPosts;
  }

  /// Fetch a single post by ID directly from backend (supports owner authentication to retrieve transaction details)
  Future<PostItem?> fetchPostById(
    String postId, {
    String? authToken,
    String? userId,
    String? userEmail,
  }) async {
    final cleanPostId = postId.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPostId.isEmpty) return null;

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (authToken != null && authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      if (userId != null && userId.isNotEmpty) 'x-user-id': userId.replaceAll(RegExp(r'[^0-9]'), ''),
      if (userEmail != null && userEmail.isNotEmpty) 'x-user-email': userEmail.trim(),
    };

    try {
      final uri = Uri.parse('$_baseUrl/api/posts/$cleanPostId');
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['post'] != null) {
          final post = PostItem.fromJson(data['post'] as Map<String, dynamic>);
          // Update in-memory collections if present
          final feedIdx = _feedPosts.indexWhere((p) => p.postId == post.postId);
          if (feedIdx != -1) {
            _feedPosts[feedIdx] = post;
          }
          return post;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[PostService] Error fetching post by id ($postId): $e');
      }
    }
    return null;
  }

  /// Helper to get all posts belonging to a specific business
  List<PostItem> getPostsForBusiness(String businessId) {
    final cleanBizId = businessId.replaceAll(RegExp(r'[^0-9]'), '');
    return _feedPosts.where((p) {
      if (p.businessProfileId == businessId) return true;
      if (cleanBizId.isNotEmpty && p.businessProfileId.replaceAll(RegExp(r'[^0-9]'), '') == cleanBizId) return true;
      return false;
    }).toList();
  }

  /// Fetch saved posts from backend for authenticated user
  Future<List<PostItem>> fetchSavedPosts({String? authToken, String? userId, String? userEmail}) async {
    _isLoading = true;
    notifyListeners();

    final apiClient = ApiClient();
    if (authToken != null && authToken.isNotEmpty) apiClient.setAuthToken(authToken);
    if (userId != null || userEmail != null) {
      apiClient.setCurrentUser(userId: userId, email: userEmail);
    }

    try {
      final response = await apiClient.get('/api/posts/saved');
      if (kDebugMode) {
        print('[PostService] fetchSavedPosts response: $response');
      }

      if (response != null && response is Map<String, dynamic> && response['success'] == true) {
        final List list = response['posts'] as List? ?? [];
        final fetched = list.map((item) {
          final p = PostItem.fromJson(item as Map<String, dynamic>);
          p.isSaved = true;
          return p;
        }).toList();

        _savedPosts.clear();
        _savedPosts.addAll(fetched);

        // Update feed state as well
        final savedIds = _savedPosts.map((p) => p.postId).toSet();
        for (final p in _feedPosts) {
          p.isSaved = savedIds.contains(p.postId);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[PostService] Error fetching saved posts: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return _savedPosts;
  }

  /// Toggle Save / Bookmark a post (Persistent with backend database sync)
  Future<bool> toggleSavePost(String postId, {String? authToken, String? userId, String? userEmail}) async {
    final cleanPostId = postId.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPostId.isEmpty) return false;

    final apiClient = ApiClient();
    if (authToken != null && authToken.isNotEmpty) apiClient.setAuthToken(authToken);
    if (userId != null || userEmail != null) {
      apiClient.setCurrentUser(userId: userId, email: userEmail);
    }

    try {
      final response = await apiClient.post('/api/posts/$cleanPostId/save', {});

      if (response != null && response is Map<String, dynamic> && response['success'] == true) {
        final bool isSavedNow = response['isSaved'] == true || response['is_saved'] == true || response['isSaved'] == 1;
        final int serverSavedCount = response['savedCount'] != null
            ? int.tryParse(response['savedCount'].toString()) ?? 0
            : 0;

        final feedIndex = _feedPosts.indexWhere((p) => p.postId == postId);
        PostItem? targetPost;

        if (feedIndex != -1) {
          _feedPosts[feedIndex].isSaved = isSavedNow;
          if (response['savedCount'] != null) {
            _feedPosts[feedIndex].savedCount = serverSavedCount;
          }
          targetPost = _feedPosts[feedIndex];
        }

        if (isSavedNow) {
          if (targetPost != null) {
            targetPost.isSaved = true;
            if (!_savedPosts.any((p) => p.postId == postId)) {
              _savedPosts.insert(0, targetPost);
            }
          } else {
            // Re-fetch saved posts from backend to get full post data
            await fetchSavedPosts(
              authToken: authToken,
              userId: userId,
              userEmail: userEmail,
            );
          }
        } else {
          _savedPosts.removeWhere((p) => p.postId == postId);
        }

        notifyListeners();
        return true;
      } else {
        debugPrint('[PostService] Save API returned failure: $response');
        return false;
      }
    } catch (e) {
      debugPrint('[PostService] Error syncing saved post with backend: $e');
      return false;
    }
  }

  // Cooldown cache to debounce multiple clicks on the same post within 5 seconds
  final Map<String, DateTime> _lastMoreInfoClickTimes = {};

  /// Track "More Info" button click engagement (Non-blocking / fire-and-forget)
  Future<void> trackMoreInfoClick(String postId, {String? authToken, String? userId, String? userEmail}) async {
    final cleanPostId = postId.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPostId.isEmpty) return;

    // Prevent double counting if tapped / long-pressed simultaneously or within 5s window
    final now = DateTime.now();
    final lastTime = _lastMoreInfoClickTimes[cleanPostId];
    if (lastTime != null && now.difference(lastTime).inMilliseconds < 5000) {
      debugPrint('[PostService] Debouncing More Info click for post $cleanPostId (already tracked recently).');
      return;
    }
    _lastMoreInfoClickTimes[cleanPostId] = now;

    // 1. Optimistically increment in-memory click count
    final feedIndex = _feedPosts.indexWhere((p) => p.postId == postId || p.postId == 'P${cleanPostId.padLeft(3, '0')}');
    if (feedIndex != -1) {
      _feedPosts[feedIndex].moreInfoClickCount += 1;
    }
    final savedIndex = _savedPosts.indexWhere((p) => p.postId == postId || p.postId == 'P${cleanPostId.padLeft(3, '0')}');
    if (savedIndex != -1) {
      _savedPosts[savedIndex].moreInfoClickCount += 1;
    }
    notifyListeners();

    // 2. Non-blocking network sync
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (authToken != null && authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      if (userId != null && userId.isNotEmpty) 'x-user-id': userId.replaceAll(RegExp(r'[^0-9]'), ''),
      if (userEmail != null && userEmail.isNotEmpty) 'x-user-email': userEmail.trim(),
    };

    try {
      final uri = Uri.parse('$_baseUrl/api/posts/$cleanPostId/more-info-click');
      http.post(uri, headers: headers).then((response) {
        if (response.statusCode == 200) {
          try {
            final data = jsonDecode(response.body);
            if (data['moreInfoClickCount'] != null) {
              final newCount = int.tryParse(data['moreInfoClickCount'].toString()) ?? 0;
              if (feedIndex != -1 && feedIndex < _feedPosts.length) {
                _feedPosts[feedIndex].moreInfoClickCount = newCount;
              }
              if (savedIndex != -1 && savedIndex < _savedPosts.length) {
                _savedPosts[savedIndex].moreInfoClickCount = newCount;
              }
              notifyListeners();
            }
          } catch (_) {}
        }
      }).catchError((e) {
        if (kDebugMode) {
          print('[PostService] Error recording More Info click: $e');
        }
      });
    } catch (_) {}
  }

  /// Create a Pending Draft Post on Backend before initiating In-App Purchase
  Future<PostItem> createPendingPost({
    required String businessProfileId,
    required String bizName,
    required String title,
    required String subtitle,
    required String description,
    required int durationDays,
    List<String>? images,
    String? brandLogo,
    String? targetLocation,
    List<TargetLocationModel>? targetLocationItems,
    String? authToken,
    String? userId,
    String? userEmail,
  }) async {
    final selectedImages = images ?? <String>[];
    final cleanBizId = businessProfileId.replaceAll(RegExp(r'[^0-9]'), '');

    final payload = {
      'business_id': cleanBizId.isNotEmpty ? int.parse(cleanBizId) : businessProfileId,
      'title': title.trim(),
      'subtitle': subtitle.trim(),
      'description': description.trim(),
      'target_location': targetLocation ?? 'Tamil Nadu',
      'target_locations': targetLocationItems?.map((e) => e.toMap()).toList(),
      'images': selectedImages,
      'brand_logo': brandLogo,
      'duration_days': durationDays,
      'is_pending': true,
      'status': 'pending_payment',
    };

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (authToken != null && authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      if (userId != null && userId.isNotEmpty) 'x-user-id': userId.replaceAll(RegExp(r'[^0-9]'), ''),
      if (userEmail != null && userEmail.isNotEmpty) 'x-user-email': userEmail.trim(),
    };

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/posts'),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['post'] != null) {
          return PostItem.fromJson(data['post'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[PostService] Error creating pending post on backend: $e');
      }
    }

    // Fallback local pending post
    return PostItem(
      postId: "P${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}",
      businessProfileId: businessProfileId,
      bizName: bizName,
      type: 'post',
      title: title,
      subtitle: subtitle,
      description: description,
      timeAgo: "Just now",
      images: selectedImages,
      brandLogo: brandLogo,
      targetLocation: targetLocation,
      targetLocationItems: targetLocationItems,
      durationDays: durationDays,
      status: 'pending_payment',
      isSaved: false,
    );
  }

  /// Verify In-App Purchase with Backend and Publish Post
  Future<PostItem?> verifyAndPublishPaidPost({
    required String postId,
    required String businessProfileId,
    required int durationDays,
    required String productId,
    required String platform,
    required String transactionId,
    required String purchaseToken,
    Map<String, dynamic>? rawPayload,
    String? authToken,
    String? userId,
    String? userEmail,
  }) async {
    final cleanPostId = postId.replaceAll(RegExp(r'[^0-9]'), '');
    final cleanBizId = businessProfileId.replaceAll(RegExp(r'[^0-9]'), '');

    final payload = {
      'post_id': cleanPostId.isNotEmpty ? int.parse(cleanPostId) : postId,
      'business_id': cleanBizId.isNotEmpty ? int.parse(cleanBizId) : businessProfileId,
      'duration_days': durationDays,
      'product_id': productId,
      'platform': platform,
      'transaction_id': transactionId,
      'purchase_token': purchaseToken,
      if (rawPayload != null) 'raw_payload': rawPayload,
    };

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (authToken != null && authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      if (userId != null && userId.isNotEmpty) 'x-user-id': userId.replaceAll(RegExp(r'[^0-9]'), ''),
      if (userEmail != null && userEmail.isNotEmpty) 'x-user-email': userEmail.trim(),
    };

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/payments/verify-and-activate-post'),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['post'] != null) {
          final activePost = PostItem.fromJson(data['post'] as Map<String, dynamic>);
          _feedPosts.removeWhere((p) => p.postId == activePost.postId);
          _feedPosts.insert(0, activePost);
          _totalCount += 1;
          notifyListeners();
          return activePost;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[PostService] Error verifying post payment with backend: $e');
      }
    }
    return null;
  }

  /// Create and publish a generic Business Post (with default duration)
  Future<PostItem> createPost({
    required String businessProfileId,
    required String bizName,
    required String title,
    required String subtitle,
    required String description,
    int durationDays = 1,
    List<String>? images,
    String? brandLogo,
    String? targetLocation,
    List<TargetLocationModel>? targetLocationItems,
    String? authToken,
    String? userId,
    String? userEmail,
  }) async {
    return await createPendingPost(
      businessProfileId: businessProfileId,
      bizName: bizName,
      title: title,
      subtitle: subtitle,
      description: description,
      durationDays: durationDays,
      images: images,
      brandLogo: brandLogo,
      targetLocation: targetLocation,
      targetLocationItems: targetLocationItems,
      authToken: authToken,
      userId: userId,
      userEmail: userEmail,
    );
  }

  /// Update an existing Business Post
  Future<PostItem?> updatePost(
    String postId, {
    required String title,
    required String subtitle,
    required String description,
    String? targetLocation,
    List<TargetLocationModel>? targetLocationItems,
    List<String>? images,
    String? authToken,
    String? userId,
    String? userEmail,
  }) async {
    final cleanPostId = postId.replaceAll(RegExp(r'[^0-9]'), '');
    final payload = {
      'title': title.trim(),
      'subtitle': subtitle.trim(),
      'description': description.trim(),
      'target_location': targetLocation,
      'target_locations': targetLocationItems?.map((e) => e.toMap()).toList(),
      if (images != null) 'images': images,
    };

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (authToken != null && authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      if (userId != null && userId.isNotEmpty) 'x-user-id': userId.replaceAll(RegExp(r'[^0-9]'), ''),
      if (userEmail != null && userEmail.isNotEmpty) 'x-user-email': userEmail.trim(),
    };

    PostItem? updatedPost;
    if (cleanPostId.isNotEmpty) {
      try {
        final response = await http.put(
          Uri.parse('$_baseUrl/api/posts/$cleanPostId'),
          headers: headers,
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['success'] == true && data['post'] != null) {
            updatedPost = PostItem.fromJson(data['post'] as Map<String, dynamic>);
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('[PostService] Error updating post on backend: $e');
        }
      }
    }

    // Update in-memory collections
    final feedIndex = _feedPosts.indexWhere((p) => p.postId == postId);
    if (feedIndex != -1) {
      if (updatedPost != null) {
        _feedPosts[feedIndex] = updatedPost;
      } else {
        final current = _feedPosts[feedIndex];
        _feedPosts[feedIndex] = PostItem(
          postId: current.postId,
          numericPostId: current.numericPostId,
          businessProfileId: current.businessProfileId,
          numericBusinessId: current.numericBusinessId,
          bizName: current.bizName,
          title: title,
          subtitle: subtitle,
          description: description,
          images: images ?? current.images,
          brandLogo: current.brandLogo,
          timeAgo: current.timeAgo,
          createdAt: current.createdAt,
          targetLocation: targetLocation ?? current.targetLocation,
          targetLocationItems: targetLocationItems ?? current.targetLocationItems,
          isSaved: current.isSaved,
          moreInfoClickCount: current.moreInfoClickCount,
          savedCount: current.savedCount,
        );
      }
    }

    final savedIndex = _savedPosts.indexWhere((p) => p.postId == postId);
    if (savedIndex != -1 && updatedPost != null) {
      _savedPosts[savedIndex] = updatedPost;
    }

    notifyListeners();
    return updatedPost;
  }

  /// Delete a post by postId
  Future<bool> deletePost(
    String postId, {
    String? callerBusinessProfileId,
    String? authToken,
    String? userId,
    String? userEmail,
  }) async {
    final cleanPostId = postId.replaceAll(RegExp(r'[^0-9]'), '');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (authToken != null && authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      if (userId != null && userId.isNotEmpty) 'x-user-id': userId.replaceAll(RegExp(r'[^0-9]'), ''),
      if (userEmail != null && userEmail.isNotEmpty) 'x-user-email': userEmail.trim(),
    };

    bool serverSuccess = false;
    if (cleanPostId.isNotEmpty) {
      try {
        final response = await http.delete(
          Uri.parse('$_baseUrl/api/posts/$cleanPostId'),
          headers: headers,
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          serverSuccess = true;
        }
      } catch (_) {}
    }

    _feedPosts.removeWhere((p) => p.postId == postId);
    _savedPosts.removeWhere((p) => p.postId == postId);
    if (_totalCount > 0) _totalCount -= 1;
    notifyListeners();
    return serverSuccess;
  }
}
