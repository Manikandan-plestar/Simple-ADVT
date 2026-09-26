import 'package:flutter/foundation.dart';
import 'post_service.dart';

class OfferService extends ChangeNotifier {
  /// Purpose: Fetch active offers filtered by location or target area.
  /// Current behavior: Filters PostService offer posts.
  /// Future behavior: GET /offers API call with latitude, longitude & radius.
  List<PostItem> getOffers(List<PostItem> allPosts, {String? locationQuery}) {
    final offers = allPosts.where((p) => p.type == 'offer').toList();
    if (locationQuery != null && locationQuery.isNotEmpty) {
      return offers.where((o) =>
          (o.targetLocation ?? '').toLowerCase().contains(locationQuery.toLowerCase()) ||
          o.subtitle.toLowerCase().contains(locationQuery.toLowerCase())).toList();
    }
    return offers;
  }
}
