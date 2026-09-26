import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../utils/text_utils.dart';
import 'post_service.dart';

class BusinessProfile {
  final String businessProfileId; // Unique ID (e.g. BP001, BP101)
  final int? numericBusinessId;
  final String ownerUserId; // User ID (e.g. U001)
  final int? numericUserId;
  String name;
  String category;
  String phone;
  String countryCode;
  final String location;
  final String registeredAddress;
  final String locality;
  final String city;
  final String state;
  final String country;
  final double latitude;
  final double longitude;
  String image;
  List<String> images; // Profile images
  String about;
  bool isFollowed;
  List<PostItem> posts;

  BusinessProfile({
    required this.businessProfileId,
    this.numericBusinessId,
    required this.ownerUserId,
    this.numericUserId,
    required this.name,
    required this.category,
    this.phone = '+91 98402 12345',
    this.countryCode = '+91',
    required this.location,
    this.registeredAddress = '',
    this.locality = '',
    this.city = '',
    this.state = '',
    this.country = 'India',
    this.latitude = 0.0,
    this.longitude = 0.0,
    required this.image,
    List<String>? images,
    required this.about,
    this.isFollowed = false,
    List<PostItem>? posts,
  })  : images = (images != null && images.isNotEmpty) ? images : [image],
        posts = posts ?? [];

  String get displayName => TextUtils.capitalizeWords(name);
  String get displayCategory => TextUtils.capitalizeWords(category);
  String get displayLocation => TextUtils.capitalizeWords(location);
  String get displayCity => TextUtils.capitalizeWords(city.isNotEmpty ? city : location);
  String get displayLocality => TextUtils.capitalizeWords(locality);
  String get displayState => TextUtils.capitalizeWords(state);
  String get displayCountry => TextUtils.capitalizeWords(country);

  factory BusinessProfile.fromJson(Map<String, dynamic> json) {
    final rawBizId = json['business_id'] ?? json['businessProfileId'] ?? 0;
    final int? numBizId = rawBizId is int ? rawBizId : int.tryParse(rawBizId.toString().replaceAll(RegExp(r'[^0-9]'), ''));
    final formattedBizId = json['business_profile_id'] as String? ?? (numBizId != null ? 'BP${numBizId.toString().padLeft(3, '0')}' : rawBizId.toString());

    final rawUserId = json['user_id'] ?? json['ownerUserId'] ?? 0;
    final int? numUserId = rawUserId is int ? rawUserId : int.tryParse(rawUserId.toString().replaceAll(RegExp(r'[^0-9]'), ''));
    final formattedUserId = json['owner_user_id'] as String? ?? (numUserId != null ? 'U${numUserId.toString().padLeft(3, '0')}' : rawUserId.toString());

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

    final primaryImg = json['profile_image'] as String? ?? json['image'] as String? ?? (imgList.isNotEmpty ? imgList.first : '');
    final fullAddr = json['full_address'] as String? ?? json['registeredAddress'] as String? ?? '';
    final locCity = json['city'] as String? ?? '';
    final locLocality = json['locality'] as String? ?? '';
    final locationDisplay = locCity.isNotEmpty ? locCity : (locLocality.isNotEmpty ? locLocality : (json['location'] as String? ?? 'Tirunelveli'));

    return BusinessProfile(
      businessProfileId: formattedBizId,
      numericBusinessId: numBizId,
      ownerUserId: formattedUserId,
      numericUserId: numUserId,
      name: json['business_name'] as String? ?? json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'General Store',
      phone: json['business_phone'] as String? ?? json['phone'] as String? ?? '',
      countryCode: json['country_code'] as String? ?? '+91',
      location: locationDisplay,
      registeredAddress: fullAddr,
      locality: locLocality,
      city: locCity,
      state: json['state'] as String? ?? 'Tamil Nadu',
      country: json['country'] as String? ?? 'India',
      latitude: (json['latitude'] != null) ? double.tryParse(json['latitude'].toString()) ?? 0.0 : 0.0,
      longitude: (json['longitude'] != null) ? double.tryParse(json['longitude'].toString()) ?? 0.0 : 0.0,
      image: primaryImg.isNotEmpty ? primaryImg : 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?auto=format&fit=crop&w=600&q=80',
      images: imgList,
      about: json['about'] as String? ?? '',
      isFollowed: json['isFollowed'] as bool? ?? false,
    );
  }
}

class BusinessService extends ChangeNotifier {
  final List<BusinessProfile> _businesses = [];
  final List<BusinessProfile> _followedBusinesses = [];
  String? _activeBusinessProfileId;
  bool _isLoading = false;

  String get _baseUrl => ApiClient().baseUrl;
  String get baseUrl => ApiClient().baseUrl;
  set baseUrl(String url) {
    ApiClient().setBaseUrl(url);
    notifyListeners();
  }

  bool get isLoading => _isLoading;
  List<BusinessProfile> get businesses => List.unmodifiable(_businesses);
  List<BusinessProfile> get followedBusinesses => List.unmodifiable(_followedBusinesses);

  BusinessProfile? get activeBusiness {
    if (_activeBusinessProfileId == null) return _businesses.isNotEmpty ? _businesses.first : null;
    try {
      return _businesses.firstWhere((b) => b.businessProfileId == _activeBusinessProfileId);
    } catch (_) {
      return _businesses.isNotEmpty ? _businesses.first : null;
    }
  }

  int? _parseUserId(String id) {
    final clean = id.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(clean);
  }

  List<BusinessProfile> getUserBusinesses(String userId) {
    if (userId.trim().isEmpty) return [];
    final targetNumericId = _parseUserId(userId);

    return _businesses.where((b) {
      if (b.ownerUserId == userId) return true;
      if (targetNumericId != null && b.numericUserId != null && targetNumericId == b.numericUserId) {
        return true;
      }
      final bOwnerNum = _parseUserId(b.ownerUserId);
      if (targetNumericId != null && bOwnerNum != null && targetNumericId == bOwnerNum) {
        return true;
      }
      return false;
    }).toList();
  }

  void setActiveBusiness(String businessProfileId) {
    _activeBusinessProfileId = businessProfileId;
    notifyListeners();
  }

  /// Toggle Follow / Unfollow a business profile (Persistent)
  Future<void> toggleFollow(String businessProfileId, {String? authToken, String? userId, String? userEmail}) async {
    final index = _businesses.indexWhere((b) => b.businessProfileId == businessProfileId);
    bool newFollowed = true;
    BusinessProfile? targetBiz;

    if (index != -1) {
      _businesses[index].isFollowed = !_businesses[index].isFollowed;
      newFollowed = _businesses[index].isFollowed;
      targetBiz = _businesses[index];
    } else {
      final fIdx = _followedBusinesses.indexWhere((b) => b.businessProfileId == businessProfileId);
      if (fIdx != -1) {
        targetBiz = _followedBusinesses[fIdx];
        newFollowed = false;
      }
    }

    if (newFollowed && targetBiz != null) {
      if (!_followedBusinesses.any((b) => b.businessProfileId == businessProfileId)) {
        _followedBusinesses.insert(0, targetBiz);
      }
    } else {
      _followedBusinesses.removeWhere((b) => b.businessProfileId == businessProfileId);
    }
    notifyListeners();

    // Sync with backend
    final cleanBizId = businessProfileId.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanBizId.isNotEmpty) {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (authToken != null && authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
        if (userId != null && userId.isNotEmpty) 'x-user-id': userId.replaceAll(RegExp(r'[^0-9]'), ''),
        if (userEmail != null && userEmail.isNotEmpty) 'x-user-email': userEmail.trim(),
      };

      try {
        await http.post(
          Uri.parse('$_baseUrl/api/business-profiles/$cleanBizId/follow'),
          headers: headers,
        ).timeout(const Duration(seconds: 8));
      } catch (e) {
        if (kDebugMode) {
          print('[BusinessService] Error syncing follow: $e');
        }
      }
    }
  }

  /// Fetch followed businesses from backend
  Future<List<BusinessProfile>> fetchFollowedBusinesses({String? authToken, String? userId, String? userEmail}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (authToken != null && authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      if (userId != null && userId.isNotEmpty) 'x-user-id': userId.replaceAll(RegExp(r'[^0-9]'), ''),
      if (userEmail != null && userEmail.isNotEmpty) 'x-user-email': userEmail.trim(),
    };

    try {
      final uri = Uri.parse('$_baseUrl/api/business-profiles/followed');
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['businesses'] is List) {
          final List list = data['businesses'] as List;
          final fetched = list.map((item) => BusinessProfile.fromJson(item as Map<String, dynamic>)).toList();
          _followedBusinesses.clear();
          _followedBusinesses.addAll(fetched);

          final followedIds = _followedBusinesses.map((b) => b.businessProfileId).toSet();
          for (final b in _businesses) {
            b.isFollowed = followedIds.contains(b.businessProfileId);
          }
          notifyListeners();
          return _followedBusinesses;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[BusinessService] Error fetching followed businesses: $e');
      }
    }
    return _followedBusinesses;
  }

  /// Fetch logged-in user's business profiles from backend
  Future<List<BusinessProfile>> fetchUserBusinesses({
    required String userId,
    String? authToken,
    String? userEmail,
  }) async {
    _isLoading = true;
    notifyListeners();

    final cleanUserId = userId.trim();
    final url = Uri.parse('$_baseUrl/api/business-profiles/my?user_id=${Uri.encodeComponent(cleanUserId)}');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (authToken != null && authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      if (cleanUserId.isNotEmpty) 'x-user-id': cleanUserId,
      if (userEmail != null && userEmail.isNotEmpty) 'x-user-email': userEmail.trim(),
    };

    try {
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['profiles'] is List) {
          final List list = data['profiles'] as List;
          final fetched = list.map((item) => BusinessProfile.fromJson(item as Map<String, dynamic>)).toList();

          _businesses.removeWhere((b) {
            final targetNum = _parseUserId(cleanUserId);
            final bNum = _parseUserId(b.ownerUserId);
            return b.ownerUserId == cleanUserId || (targetNum != null && bNum != null && targetNum == bNum);
          });

          _businesses.addAll(fetched);

          if (fetched.isNotEmpty && (_activeBusinessProfileId == null || !_businesses.any((b) => b.businessProfileId == _activeBusinessProfileId))) {
            _activeBusinessProfileId = fetched.first.businessProfileId;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[BusinessService] Error fetching user businesses: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return getUserBusinesses(cleanUserId);
  }

  /// Fetch a single business profile by ID
  Future<BusinessProfile?> fetchBusinessById(String businessProfileId) async {
    if (businessProfileId.trim().isEmpty) return null;
    final cleanId = businessProfileId.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse('$_baseUrl/api/business-profiles/${cleanId.isNotEmpty ? cleanId : businessProfileId}');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['profile'] != null) {
          final fetched = BusinessProfile.fromJson(data['profile'] as Map<String, dynamic>);
          final existingIdx = _businesses.indexWhere((b) =>
              b.businessProfileId == fetched.businessProfileId ||
              (cleanId.isNotEmpty && b.businessProfileId.replaceAll(RegExp(r'[^0-9]'), '') == cleanId));
          if (existingIdx != -1) {
            _businesses[existingIdx] = fetched;
          } else {
            _businesses.add(fetched);
          }
          notifyListeners();
          return fetched;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[BusinessService] Error fetching business by ID: $e');
      }
    }
    return getBusinessById(businessProfileId);
  }

  /// Create a new Business Profile in MySQL database
  Future<BusinessProfile> createBusinessProfile({
    required String ownerUserId,
    required String name,
    required String category,
    required String phone,
    String countryCode = '+91',
    required String location,
    required String registeredAddress,
    String locality = '',
    String city = '',
    String state = '',
    String country = 'India',
    required double latitude,
    required double longitude,
    required List<String> images,
    required String about,
    String? authToken,
    String? userEmail,
  }) async {
    final cleanOwnerId = ownerUserId.trim();
    final primaryImage = images.isNotEmpty
        ? images.first
        : "https://images.unsplash.com/photo-1441986300917-64674bd600d8?auto=format&fit=crop&w=600&q=80";

    final url = Uri.parse('$_baseUrl/api/business-profiles');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (authToken != null && authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      if (cleanOwnerId.isNotEmpty) 'x-user-id': cleanOwnerId,
      if (userEmail != null && userEmail.isNotEmpty) 'x-user-email': userEmail.trim(),
    };

    final payload = {
      'business_name': name.trim(),
      'category': category.trim(),
      'business_phone': phone.trim(),
      'country_code': countryCode.trim(),
      'full_address': registeredAddress.trim(),
      'locality': locality.trim(),
      'city': city.isNotEmpty ? city.trim() : location.trim(),
      'state': state.trim(),
      'country': country.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'profile_image': primaryImage,
      'images': images,
      'about': about.trim(),
    };

    BusinessProfile? createdProfile;

    try {
      final response = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['profile'] != null) {
          createdProfile = BusinessProfile.fromJson(data['profile'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[BusinessService] Backend create request error: $e');
      }
    }

    if (createdProfile == null) {
      final newId = "BP${(DateTime.now().millisecondsSinceEpoch % 100000).toString().padLeft(4, '0')}";
      createdProfile = BusinessProfile(
        businessProfileId: newId,
        ownerUserId: cleanOwnerId,
        name: name.trim(),
        category: category.trim(),
        phone: phone.trim(),
        countryCode: countryCode.trim(),
        location: city.isNotEmpty ? city.trim() : location.trim(),
        registeredAddress: registeredAddress.isNotEmpty ? registeredAddress.trim() : location.trim(),
        locality: locality.trim(),
        city: city.trim(),
        state: state.trim(),
        country: country.trim(),
        latitude: latitude,
        longitude: longitude,
        image: primaryImage,
        images: images.isNotEmpty ? images : [primaryImage],
        about: about.isNotEmpty ? about.trim() : "Newly opened business profile.",
      );
    }

    _businesses.insert(0, createdProfile);
    _activeBusinessProfileId = createdProfile.businessProfileId;
    notifyListeners();
    return createdProfile;
  }

  BusinessProfile? getBusinessById(String id) {
    if (id.trim().isEmpty) return null;
    final cleanId = id.replaceAll(RegExp(r'[^0-9]'), '');
    try {
      return _businesses.firstWhere((b) {
        if (b.businessProfileId == id) return true;
        if (cleanId.isNotEmpty) {
          final bClean = b.businessProfileId.replaceAll(RegExp(r'[^0-9]'), '');
          if (bClean == cleanId) return true;
          if (b.numericBusinessId?.toString() == cleanId) return true;
        }
        return false;
      });
    } catch (_) {
      return null;
    }
  }

  /// Update business profile (Owner only)
  Future<bool> updateBusinessProfile({
    required String businessProfileId,
    required String name,
    required String category,
    required String phone,
    String countryCode = '+91',
    required List<String> images,
    required String about,
    String? callerUserId,
    String? authToken,
    String? userEmail,
  }) async {
    final biz = getBusinessById(businessProfileId);
    if (biz == null) return false;

    if (callerUserId != null && callerUserId.isNotEmpty) {
      final callerNum = _parseUserId(callerUserId);
      final ownerNum = _parseUserId(biz.ownerUserId);
      if (biz.ownerUserId != callerUserId && (callerNum == null || ownerNum == null || callerNum != ownerNum)) {
        return false;
      }
    }

    biz.name = name.trim();
    biz.category = category.trim();
    biz.phone = phone.trim();
    biz.countryCode = countryCode.trim();
    if (images.isNotEmpty) {
      biz.images = List.from(images);
      biz.image = images.first;
    }
    biz.about = about.trim();
    notifyListeners();

    final rawId = businessProfileId.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse('$_baseUrl/api/business-profiles/${rawId.isNotEmpty ? rawId : businessProfileId}');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (authToken != null && authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      if (callerUserId != null && callerUserId.isNotEmpty) 'x-user-id': callerUserId.trim(),
      if (userEmail != null && userEmail.isNotEmpty) 'x-user-email': userEmail.trim(),
    };

    try {
      await http.put(
        url,
        headers: headers,
        body: jsonEncode({
          'business_name': name.trim(),
          'category': category.trim(),
          'business_phone': phone.trim(),
          'country_code': countryCode.trim(),
          'profile_image': images.isNotEmpty ? images.first : '',
          'images': images,
          'about': about.trim(),
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      if (kDebugMode) {
        print('[BusinessService] Backend update note: $e');
      }
    }

    return true;
  }

  /// Delete business profile (Owner only)
  Future<bool> deleteBusinessProfile(
    String businessProfileId, {
    String? callerUserId,
    String? authToken,
    String? userEmail,
  }) async {
    final biz = getBusinessById(businessProfileId);
    if (biz == null) return false;

    if (callerUserId != null && callerUserId.isNotEmpty) {
      final callerNum = _parseUserId(callerUserId);
      final ownerNum = _parseUserId(biz.ownerUserId);
      if (biz.ownerUserId != callerUserId && (callerNum == null || ownerNum == null || callerNum != ownerNum)) {
        return false;
      }
    }

    _businesses.removeWhere((b) => b.businessProfileId == businessProfileId);
    _followedBusinesses.removeWhere((b) => b.businessProfileId == businessProfileId);
    if (_activeBusinessProfileId == businessProfileId) {
      _activeBusinessProfileId = _businesses.isNotEmpty ? _businesses.first.businessProfileId : null;
    }
    notifyListeners();

    final rawId = businessProfileId.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse('$_baseUrl/api/business-profiles/${rawId.isNotEmpty ? rawId : businessProfileId}');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (authToken != null && authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      if (callerUserId != null && callerUserId.isNotEmpty) 'x-user-id': callerUserId.trim(),
      if (userEmail != null && userEmail.isNotEmpty) 'x-user-email': userEmail.trim(),
    };

    try {
      await http.delete(url, headers: headers).timeout(const Duration(seconds: 10));
    } catch (e) {
      if (kDebugMode) {
        print('[BusinessService] Backend delete note: $e');
      }
    }

    return true;
  }

  void addPostToBusiness(String businessProfileId, PostItem post) {
    final biz = getBusinessById(businessProfileId);
    if (biz != null) {
      biz.posts.insert(0, post);
      notifyListeners();
    }
  }
}
