import 'package:flutter/foundation.dart';
import 'post_service.dart';

class JobService extends ChangeNotifier {
  /// Purpose: Fetch jobs filtered by location or target area.
  /// Current behavior: Filters PostService job posts.
  /// Future behavior: GET /jobs API call with latitude, longitude & radius.
  List<PostItem> getJobs(List<PostItem> allPosts, {String? locationQuery}) {
    final jobs = allPosts.where((p) => p.type == 'job').toList();
    if (locationQuery != null && locationQuery.isNotEmpty) {
      return jobs.where((j) =>
          (j.targetLocation ?? '').toLowerCase().contains(locationQuery.toLowerCase()) ||
          j.subtitle.toLowerCase().contains(locationQuery.toLowerCase())).toList();
    }
    return jobs;
  }
}
