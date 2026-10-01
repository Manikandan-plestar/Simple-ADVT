import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../models/target_location_model.dart';
import '../utils/text_utils.dart';

class PostItem {
  final String postId;
  final int? numericPostId;
  final String businessProfileId;
  final int? numericBusinessId;
  final String bizName;
  final String type; // Always 'post' in Simple ADVT
  final String title;
  final String subtitle;
  final String description;
  final List<String> images; // Ordered list of actual selected post images
  final String? brandLogo;
  final String timeAgo;
  final DateTime createdAt;
  final String? targetLocation;
  final List<TargetLocationModel>? targetLocationItems;
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
    this.isSaved = false,
    this.moreInfoClickCount = 0,
    this.savedCount = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
        images = (images != null && images.isNotEmpty)
            ? images
            : (image != null && image.isNotEmpty ? [image] : []);

  String? get image => images.isNotEmpty ? images.first : null;

  String get displayTitle => TextUtils.capitalizeWords(title);
  String get displayBizName => TextUtils.capitalizeWords(bizName);
  String get displaySubtitle => TextUtils.capitalizeWords(subtitle);
  String get displayLocation => TextUtils.capitalizeWords(targetLocation ?? '');

  String get formattedPostTime {
    final hour = createdAt.hour % 12 == 0 ? 12 : createdAt.hour % 12;
    final minute = createdAt.minute.toString().padLeft(2, '0');
    final ampm = createdAt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

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

    DateTime parsedCreatedAt = DateTime.now();
    if (json['created_at'] != null || json['createdAt'] != null) {
      try {
        parsedCreatedAt = DateTime.parse((json['created_at'] ?? json['createdAt']).toString());
      } catch (_) {}
    }

    final parsedClicks = json['moreInfoClickCount'] ?? json['more_info_click_count'] ?? json['more_info_clicks'] ?? 0;
    final parsedSaves = json['savedCount'] ?? json['saved_count'] ?? 0;

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
      timeAgo: json['timeAgo'] ?? 'Just now',
      createdAt: parsedCreatedAt,
      targetLocation: json['targetLocation'] ?? json['target_location'],
      targetLocationItems: targetLocItems,
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
      'isSaved': isSaved,
      'moreInfoClickCount': moreInfoClickCount,
      'savedCount': savedCount,
    };
  }
}

class PostService extends ChangeNotifier {
  final List<PostItem> _feedPosts = [];
  final List<PostItem> _savedPosts = [];
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

  /// Track "More Info" button click engagement (Non-blocking / fire-and-forget)
  Future<void> trackMoreInfoClick(String postId, {String? authToken, String? userId, String? userEmail}) async {
    // 1. Optimistically increment in-memory click count
    final feedIndex = _feedPosts.indexWhere((p) => p.postId == postId);
    if (feedIndex != -1) {
      _feedPosts[feedIndex].moreInfoClickCount += 1;
    }
    final savedIndex = _savedPosts.indexWhere((p) => p.postId == postId);
    if (savedIndex != -1) {
      _savedPosts[savedIndex].moreInfoClickCount += 1;
    }

    // 2. Non-blocking network sync
    final cleanPostId = postId.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPostId.isEmpty) return;

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

  /// Create and publish a new Generic Business Post
  Future<PostItem> createPost({
    required String businessProfileId,
    required String bizName,
    required String title,
    required String subtitle,
    required String description,
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
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['post'] != null) {
          final serverPost = PostItem.fromJson(data['post'] as Map<String, dynamic>);
          _feedPosts.insert(0, serverPost);
          notifyListeners();
          return serverPost;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[PostService] Error publishing post to backend: $e');
      }
    }

    // Fallback local post
    final fallbackPost = PostItem(
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
      isSaved: false,
    );

    _feedPosts.insert(0, fallbackPost);
    notifyListeners();
    return fallbackPost;
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
    notifyListeners();
    return serverSuccess;
  }
}
