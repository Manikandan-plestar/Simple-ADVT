import 'package:flutter/foundation.dart';
import 'business_service.dart';
import 'post_service.dart';

class SearchResult {
  final List<BusinessProfile> businesses;
  final List<PostItem> posts;

  SearchResult({required this.businesses, required this.posts});
}

class SearchService extends ChangeNotifier {
  String _query = '';
  String get query => _query;

  /// Purpose: Search businesses, jobs, offers, categories, and professions.
  /// Current behavior: Performs local fuzzy search over business & post arrays.
  /// Future behavior: Send GET /search?q=query API request to Node.js backend.
  SearchResult search({
    required String query,
    required List<BusinessProfile> businesses,
    required List<PostItem> posts,
  }) {
    _query = query.trim().toLowerCase();

    if (_query.isEmpty) {
      return SearchResult(businesses: businesses, posts: posts);
    }

    final matchedBiz = businesses.where((b) {
      return b.name.toLowerCase().contains(_query) ||
          b.category.toLowerCase().contains(_query) ||
          b.location.toLowerCase().contains(_query) ||
          b.registeredAddress.toLowerCase().contains(_query) ||
          b.about.toLowerCase().contains(_query);
    }).toList();

    final matchedPosts = posts.where((p) {
      return p.title.toLowerCase().contains(_query) ||
          p.subtitle.toLowerCase().contains(_query) ||
          p.description.toLowerCase().contains(_query) ||
          p.bizName.toLowerCase().contains(_query) ||
          p.type.toLowerCase().contains(_query) ||
          (p.targetLocation != null && p.targetLocation!.toLowerCase().contains(_query)) ||
          (p.targetLocationItems != null && p.targetLocationItems!.any((loc) => loc.name.toLowerCase().contains(_query)));
    }).toList();

    return SearchResult(businesses: matchedBiz, posts: matchedPosts);
  }

  /// Search business profiles only (by name, category, location, address, about)
  List<BusinessProfile> searchBusinesses({
    required String query,
    required List<BusinessProfile> businesses,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return businesses;

    return businesses.where((b) {
      return b.name.toLowerCase().contains(q) ||
          b.category.toLowerCase().contains(q) ||
          b.location.toLowerCase().contains(q) ||
          b.registeredAddress.toLowerCase().contains(q) ||
          b.about.toLowerCase().contains(q);
    }).toList();
  }

  /// Search posts only (by title, subtitle, description, bizName, type, location)
  List<PostItem> searchPosts({
    required String query,
    required List<PostItem> posts,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return posts;

    return posts.where((p) {
      return p.title.toLowerCase().contains(q) ||
          p.subtitle.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          p.bizName.toLowerCase().contains(q) ||
          p.type.toLowerCase().contains(q) ||
          (p.targetLocation != null && p.targetLocation!.toLowerCase().contains(q)) ||
          (p.targetLocationItems != null && p.targetLocationItems!.any((loc) => loc.name.toLowerCase().contains(q)));
    }).toList();
  }
}
